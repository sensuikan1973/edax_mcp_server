import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:libedax4dart/libedax4dart.dart';
import 'package:path/path.dart' as p;

base class EdaxMcpServer extends MCPServer
    with ToolsSupport, ResourcesSupport, PromptsSupport {
  final LibEdax libEdax;
  final String baseDir;

  EdaxMcpServer(
    super.channel, {
    required super.implementation,
    required this.libEdax,
    required this.baseDir,
  }) : super.fromStreamChannel() {
    _registerTools();
    _registerResources();
    _registerPrompts();
  }

  void _registerResources() {
    addResource(
      Resource(
        uri: 'othello://rules',
        name: '日本オセロ連盟競技ルール',
        description: 'オセロの公式競技ルールです。',
        mimeType: 'text/plain',
      ),
      (request) async {
        final rulesPath = p.join(baseDir, 'resources', 'docs', 'rules.txt');
        final content = await File(rulesPath).readAsString();
        return ReadResourceResult(
          contents: <ResourceContents>[
            TextResourceContents(text: content, uri: 'othello://rules'),
          ],
        );
      },
    );

    addResource(
      Resource(
        uri: 'othello://mobility',
        name: '打てる箇所の数（開放度）の価値',
        description: 'オセロにおける打てる箇所の数（モビリティ）の価値に関する統計的な調査結果です。',
        mimeType: 'text/plain',
      ),
      (request) async {
        final mobilityPath = p.join(
          baseDir,
          'resources',
          'docs',
          'mobility.txt',
        );
        final content = await File(mobilityPath).readAsString();
        return ReadResourceResult(
          contents: <ResourceContents>[
            TextResourceContents(text: content, uri: 'othello://mobility'),
          ],
        );
      },
    );
  }

  void _registerPrompts() {
    addPrompt(
      Prompt(
        name: 'othello_knowledge',
        description: 'オセロに関する知識（ルール、戦略、統計、打てる箇所の価値など）を提供します。',
        arguments: <PromptArgument>[
          PromptArgument(
            name: 'topic',
            description: '知りたいトピック（例：ルール、勝ち方、打てる箇所の価値）',
            required: false,
          ),
        ],
      ),
      (request) async {
        final topic = request.arguments?['topic'] ?? '全体';
        return GetPromptResult(
          description: 'オセロの知識に関するプロンプト',
          messages: <PromptMessage>[
            PromptMessage(
              role: Role.user,
              content: TextContent(
                text:
                    'オセロの$topicについて教えてください。'
                    '必要に応じて、以下のリソースを参照してください：\n'
                    '- othello://rules : 公式競技ルール\n'
                    '- othello://mobility : 打てる箇所の数（モビリティ）の価値に関する統計',
              ),
            ),
          ],
        );
      },
    );
  }

  void _registerTools() {
    registerTool(
      Tool(
        name: 'get_moves',
        description:
            'Get the current game moves in coordinate format (e.g., f5d6c5).',
        inputSchema: ObjectSchema(properties: <String, Schema>{}),
      ),
      (request) async {
        final moves = libEdax.edaxGetMoves();
        return CallToolResult(content: <Content>[TextContent(text: moves)]);
      },
    );

    registerTool(
      Tool(
        name: 'edax_hint',
        description: 'Get suggested moves from Edax engine.',
        inputSchema: ObjectSchema(
          properties: <String, Schema>{
            'n': Schema.int(
              description: 'The number of hints to retrieve.',
              minimum: 1,
            ),
          },
        ),
      ),
      (request) async {
        final n = (request.arguments?['n'] as num?)?.toInt() ?? 1;
        final hints = libEdax.edaxHint(n);

        if (hints.isEmpty) {
          return CallToolResult(
            content: <Content>[TextContent(text: 'No hints available.')],
          );
        }

        final buffer = StringBuffer();
        for (var i = 0; i < hints.length; i++) {
          final h = hints[i];
          buffer.writeln(
            'Hint ${i + 1}: Move ${h.moveString}, Score ${h.scoreString} (Depth: ${h.depth})',
          );
        }

        return CallToolResult(
          content: <Content>[TextContent(text: buffer.toString().trim())],
        );
      },
    );

    registerTool(
      Tool(
        name: 'play_move',
        description: 'Play a move in the current game.',
        inputSchema: ObjectSchema(
          properties: <String, Schema>{
            'move': Schema.string(
              description: 'The move to play in coordinate format (e.g., f5).',
            ),
          },
          required: <String>['move'],
        ),
      ),
      (request) async {
        final move = request.arguments!['move'] as String;
        libEdax.edaxMove(move);
        return CallToolResult(
          content: <Content>[TextContent(text: 'Played move: $move')],
        );
      },
    );

    registerTool(
      Tool(
        name: 'get_board',
        description: 'Get the current board state.',
        inputSchema: ObjectSchema(properties: <String, Schema>{}),
      ),
      (request) async {
        final board = libEdax.edaxGetBoard();
        final currentPlayer = libEdax.edaxGetCurrentPlayer();
        return CallToolResult(
          content: <Content>[
            TextContent(text: board.prettyString(currentPlayer)),
          ],
          structuredContent: <String, Object?>{
            'player_bitboard': board.playerRadix16String,
            'opponent_bitboard': board.opponentRadix16String,
            'current_player': currentPlayer == TurnColor.black
                ? 'black'
                : 'white',
          },
        );
      },
    );

    registerTool(
      Tool(
        name: 'get_mobility_count',
        description: 'Get the number of legal moves for a given color.',
        inputSchema: ObjectSchema(
          properties: <String, Schema>{
            'color': EnumSchema.untitledSingleSelect(
              description: 'The color (black or white).',
              values: <String>['black', 'white'],
            ),
          },
          required: <String>['color'],
        ),
      ),
      (request) async {
        final colorStr = request.arguments!['color'] as String;
        final color = colorStr.toLowerCase() == 'black'
            ? TurnColor.black
            : TurnColor.white;
        final count = libEdax.edaxGetMobilityCount(color);
        return CallToolResult(
          content: <Content>[
            TextContent(text: 'Mobility count for $colorStr: $count'),
          ],
        );
      },
    );

    registerTool(
      Tool(
        name: 'get_disc_count',
        description: 'Get the number of discs for a given color.',
        inputSchema: ObjectSchema(
          properties: <String, Schema>{
            'color': EnumSchema.untitledSingleSelect(
              description: 'The color (black or white).',
              values: <String>['black', 'white'],
            ),
          },
          required: <String>['color'],
        ),
      ),
      (request) async {
        final colorStr = request.arguments!['color'] as String;
        final color = colorStr.toLowerCase() == 'black'
            ? TurnColor.black
            : TurnColor.white;
        final count = libEdax.edaxGetDisc(color);
        return CallToolResult(
          content: <Content>[
            TextContent(text: 'Disc count for $colorStr: $count'),
          ],
        );
      },
    );

    registerTool(
      Tool(
        name: 'play_print',
        description:
            'Get a summary of the current game state (board, disc counts, mobility).',
        inputSchema: ObjectSchema(properties: <String, Schema>{}),
      ),
      (request) async {
        final board = libEdax.edaxGetBoard();
        final currentPlayer = libEdax.edaxGetCurrentPlayer();
        final blackDiscs = libEdax.edaxGetDisc(TurnColor.black);
        final whiteDiscs = libEdax.edaxGetDisc(TurnColor.white);
        final blackMobility = libEdax.edaxGetMobilityCount(TurnColor.black);
        final whiteMobility = libEdax.edaxGetMobilityCount(TurnColor.white);
        final turnStr = currentPlayer == TurnColor.black ? 'Black' : 'White';

        final buffer = StringBuffer();
        buffer.writeln(board.prettyString(currentPlayer));
        buffer.writeln('Discs: Black $blackDiscs, White $whiteDiscs');
        buffer.writeln('Mobility: Black $blackMobility, White $whiteMobility');
        buffer.writeln('Turn: $turnStr');

        return CallToolResult(
          content: <Content>[TextContent(text: buffer.toString().trim())],
        );
      },
    );

    registerTool(
      Tool(
        name: 'edax_get_current_player',
        description: 'Get the current player (black or white).',
        inputSchema: ObjectSchema(properties: <String, Schema>{}),
      ),
      (request) async {
        final player = libEdax.edaxGetCurrentPlayer();
        final colorStr = player == TurnColor.black ? 'black' : 'white';
        return CallToolResult(
          content: <Content>[TextContent(text: colorStr)],
        );
      },
    );

    registerTool(
      Tool(
        name: 'edax_get_opponent_player',
        description: 'Get the opponent player (black or white).',
        inputSchema: ObjectSchema(properties: <String, Schema>{}),
      ),
      (request) async {
        final player = libEdax.edaxGetOpponentPlayer();
        final colorStr = player == TurnColor.black ? 'black' : 'white';
        return CallToolResult(
          content: <Content>[TextContent(text: colorStr)],
        );
      },
    );

    registerTool(
      Tool(
        name: 'edax_get_last_move',
        description: 'Get the last move in coordinate format (e.g., f5).',
        inputSchema: ObjectSchema(properties: <String, Schema>{}),
      ),
      (request) async {
        final move = libEdax.edaxGetLastMove();
        final moveStr = move.isNoMove ? 'none' : move.moveString;
        return CallToolResult(
          content: <Content>[TextContent(text: moveStr)],
        );
      },
    );

    registerTool(
      Tool(
        name: 'edax_is_game_over',
        description: 'Check if the current game is over.',
        inputSchema: ObjectSchema(properties: <String, Schema>{}),
      ),
      (request) async {
        final isGameOver = libEdax.edaxIsGameOver();
        return CallToolResult(
          content: <Content>[TextContent(text: isGameOver.toString())],
        );
      },
    );

    registerTool(
      Tool(
        name: 'edax_init',
        description: 'Initialize the board.',
        inputSchema: ObjectSchema(properties: <String, Schema>{}),
      ),
      (request) async {
        libEdax.edaxInit();
        return CallToolResult(
          content: <Content>[TextContent(text: 'Board initialized.')],
        );
      },
    );

    registerTool(
      Tool(
        name: 'edax_new',
        description: 'Initialize the board based on the setboard command.',
        inputSchema: ObjectSchema(properties: <String, Schema>{}),
      ),
      (request) async {
        libEdax.edaxNew();
        return CallToolResult(
          content: <Content>[TextContent(text: 'New board initialized.')],
        );
      },
    );

    registerTool(
      Tool(
        name: 'edax_move',
        description: 'Play a move in the current game.',
        inputSchema: ObjectSchema(
          properties: <String, Schema>{
            'move': Schema.string(
              description: 'The move to play in coordinate format (e.g., f5).',
            ),
          },
          required: <String>['move'],
        ),
      ),
      (request) async {
        final move = request.arguments!['move'] as String;
        libEdax.edaxMove(move);
        return CallToolResult(
          content: <Content>[TextContent(text: 'Played move: $move')],
        );
      },
    );

    registerTool(
      Tool(
        name: 'edax_undo',
        description: 'Undo the last move.',
        inputSchema: ObjectSchema(properties: <String, Schema>{}),
      ),
      (request) async {
        libEdax.edaxUndo();
        return CallToolResult(
          content: <Content>[TextContent(text: 'Undo successful.')],
        );
      },
    );

    registerTool(
      Tool(
        name: 'edax_redo',
        description: 'Redo the last undone move.',
        inputSchema: ObjectSchema(properties: <String, Schema>{}),
      ),
      (request) async {
        libEdax.edaxRedo();
        return CallToolResult(
          content: <Content>[TextContent(text: 'Redo successful.')],
        );
      },
    );

    registerTool(
      Tool(
        name: 'edax_options_dump',
        description:
            'Dump Edax engine options. Note: The output might be directed to the server\'s standard error or log stream.',
        inputSchema: ObjectSchema(properties: <String, Schema>{}),
      ),
      (request) async {
        libEdax.edaxOptionsDump();
        return CallToolResult(
          content: <Content>[
            TextContent(text: 'Options dumped to standard output/error.')
          ],
        );
      },
    );
  }
}

Future<void> main() async {
  try {
    // スクリプトの場所からプロジェクトのルートディレクトリ（pubspec.yamlがある場所）を探します
    Directory dir = File(Platform.script.toFilePath()).parent;
    bool found = false;
    while (dir.path != dir.parent.path) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        found = true;
        break;
      }
      dir = dir.parent;
    }

    // pubspec.yaml が見つからない場合は、スクリプトの2階層上をベースディレクトリとします
    final baseDir = found
        ? dir.path
        : p.dirname(p.dirname(Platform.script.toFilePath()));
    stderr.writeln('ベースディレクトリ: $baseDir');

    String libName;
    if (Platform.isLinux) {
      libName = 'libedax.so';
    } else if (Platform.isMacOS) {
      libName = 'libedax.universal.dylib';
    } else if (Platform.isWindows) {
      libName = 'libedax-x64.dll';
    } else {
      throw UnsupportedError(
        'Unsupported platform: ${Platform.operatingSystem}',
      );
    }

    final dllPath = p.join(baseDir, 'resources', 'dll', libName);
    final evalPath = p.join(baseDir, 'resources', 'data', 'eval.dat');

    if (!File(dllPath).existsSync()) {
      stderr.writeln('Error: Dynamic library not found at $dllPath');
      exit(1);
    }

    if (!File(evalPath).existsSync()) {
      stderr.writeln('Error: Evaluation data not found at $evalPath');
      exit(1);
    }

    final libEdax = LibEdax(dllPath);

    final server = EdaxMcpServer(
      stdioChannel(input: stdin, output: stdout),
      implementation: Implementation(name: 'edax_mcp_server', version: '0.0.1'),
      libEdax: libEdax,
      baseDir: baseDir,
    );

    await server.initialized;
    stderr.writeln('MCP の初期化ハンドシェイクが完了しました。Edax エンジンを初期化します...');

    libEdax.libedaxInitialize(<String>['', '-eval-file', evalPath]);

    stderr.writeln('Edax エンジンの初期化が完了しました。サーバーの準備が整いました。');
  } catch (e, s) {
    stderr.writeln('サーバー起動中に致命的なエラーが発生しました: $e');
    stderr.writeln(s);
    exit(1);
  }
}

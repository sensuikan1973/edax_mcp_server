import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:libedax4dart/libedax4dart.dart';
import 'package:path/path.dart' as p;

base class EdaxMcpServer extends MCPServer
    with ToolsSupport, ResourcesSupport, PromptsSupport {
  final LibEdax libEdax;

  EdaxMcpServer(
    super.channel, {
    required super.implementation,
    required this.libEdax,
  }) : super.fromStreamChannel() {
    _registerTools();
    _registerResources();
    _registerPrompts();
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
  }

  void _registerResources() {
    registerResource(
      Resource(
        uri: 'https://www.othello.gr.jp/r_info/rule.html',
        name: '日本オセロ連盟競技ルール',
        description: 'オセロの公式ルール、対局時計の使用方法、勝敗の記録方法など。',
        mimeType: 'text/html',
      ),
      (request) async {
        return ReadResourceResult(
          contents: <TextResourceContents>[
            TextResourceContents(
              uri: 'https://www.othello.gr.jp/r_info/rule.html',
              mimeType: 'text/plain',
              text: '''
日本オセロ連盟競技ルール概要:
- 先手(黒)・後手(白)の決定は伏せ石で行う。
- 対局時計を使用し、持ち時間は大会ごとに定める。
- 着手は盤面に触れた時点で成立し、取り消しはできない。
- 石を返す動作は片手で行う。
- 勝敗は石数差で記録し、全滅(パーフェクト)の場合は64石差とする。
- 時間切れは負けとなる。勝者は「2石差勝ち」か「勝手打ち」を選択できる。
''',
            ),
          ],
        );
      },
    );

    registerResource(
      Resource(
        uri: 'http://blog.livedoor.jp/umigame_oth/',
        name: '黒引き分け勝ち (オセロブログ)',
        description: 'umigame氏によるオセロの戦略、序盤研究、ソフト(Edax)の使い方、対局反省などの記事。',
        mimeType: 'text/html',
      ),
      (request) async {
        return ReadResourceResult(
          contents: <TextResourceContents>[
            TextResourceContents(
              uri: 'http://blog.livedoor.jp/umigame_oth/',
              mimeType: 'text/plain',
              text: '''
黒引き分け勝ち (umigame氏のブログ) 概要:
- オセロの技術的な考察や研究が中心。
- Edaxの使い方、序盤研究(シャープコンポス、d8コンポス等)の記事がある。
- 「Sigmoid損」という独自の指標を提案し、勝敗に直結するミスの評価を試みている。
- 「黒引き分け勝ち(32-32で黒勝ち)」という条件が、色による有利不利を相殺するのに適当であるという説を提唱。
''',
            ),
          ],
        );
      },
    );

    registerResource(
      Resource(
        uri: 'https://choi.lavox.net/stats/bw_win',
        name: '統計的に見るオセロ (黒と白の勝率)',
        description: 'WTHORファイルを用いた大量の対局データに基づく、黒番・白番の勝率統計。',
        mimeType: 'text/html',
      ),
      (request) async {
        return ReadResourceResult(
          contents: <TextResourceContents>[
            TextResourceContents(
              uri: 'https://choi.lavox.net/stats/bw_win',
              mimeType: 'text/plain',
              text: '''
統計的に見るオセロ (黒と白の勝率) 調査結果:
- 調査対象: 約8万局の人間同士の対局データ。
- 勝率: 黒 47.47%, 白 49.69%, 引分 2.84%。
- 引き分けありの場合、白が約2%有利。
- 引き分けなし(黒が引き分け勝ちの権利を持つ)の場合、ほぼ互角(黒勝利+引分 = 50.31%)。
- 理論値(残り24マス時点)では黒がやや優勢だが、最終的に白が逆転する傾向がある。
''',
            ),
          ],
        );
      },
    );
  }

  void _registerPrompts() {
    registerPrompt(
      Prompt(
        name: 'othello_knowledge',
        description: 'オセロのルール、統計、戦略に関する知識をAIに提供するためのプロンプト。',
        arguments: <PromptArgument>[],
      ),
      (request) async {
        return GetPromptResult(
          description: 'オセロに関する専門知識の活用',
          messages: <PromptMessage>[
            PromptMessage(
              role: Role.user,
              content: TextContent(
                text: 'オセロのルール、勝率統計、または専門的な戦略について知りたいです。提供されているリソースを活用して説明してください。',
              ),
            ),
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

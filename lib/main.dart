import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:libedax4dart/libedax4dart.dart';
import 'package:path/path.dart' as p;

base class EdaxMcpServer extends MCPServer with ToolsSupport {
  final LibEdax libEdax;

  EdaxMcpServer(
    super.channel, {
    required super.implementation,
    required this.libEdax,
  }) : super.fromStreamChannel() {
    _registerTools();
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
        return CallToolResult(content: [TextContent(text: moves)]);
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
              content: [TextContent(text: 'No hints available.')]);
        }

        final buffer = StringBuffer();
        for (var i = 0; i < hints.length; i++) {
          final h = hints[i];
          buffer.writeln(
              'Hint ${i + 1}: Move ${h.moveString}, Score ${h.scoreString} (Depth: ${h.depth})');
        }

        return CallToolResult(
            content: [TextContent(text: buffer.toString().trim())]);
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
            content: [TextContent(text: 'Played move: $move')]);
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
    final baseDir =
        found ? dir.path : p.dirname(p.dirname(Platform.script.toFilePath()));
    stderr.writeln('ベースディレクトリ: $baseDir');

    String libName;
  if (Platform.isLinux) {
    libName = 'libedax.so';
  } else if (Platform.isMacOS) {
    libName = 'libedax.universal.dylib';
  } else if (Platform.isWindows) {
    libName = 'libedax-x64.dll';
  } else {
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
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
    implementation: Implementation(
      name: 'edax_mcp_server',
      version: '0.0.1',
    ),
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

import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:libedax4dart/libedax4dart.dart';
import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';

base class EdaxMcpServer extends MCPServer with ToolsSupport {
  final LibEdax libEdax;

  EdaxMcpServer(
    StreamChannel<String> channel, {
    required Implementation implementation,
    required this.libEdax,
  }) : super.fromStreamChannel(channel, implementation: implementation) {
    _registerTools();
  }

  void _registerTools() {
    registerTool(
      Tool(
        name: 'get_moves',
        description:
            'Get the current game moves in coordinate format (e.g., f5d6c5).',
        inputSchema: ObjectSchema(properties: {}),
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
          properties: {
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
  }
}

Future<void> main() async {
  final baseDir = Directory.current.path;

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
  libEdax.libedaxInitialize(['', '-eval-file', evalPath]);

  final server = EdaxMcpServer(
    stdioChannel(input: stdin, output: stdout),
    implementation: Implementation(
      name: 'edax_mcp_server',
      version: '0.0.1',
    ),
    libEdax: libEdax,
  );

  await server.initialized;
  stderr.writeln('Edax MCP Server started');
}

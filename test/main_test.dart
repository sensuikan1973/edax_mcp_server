import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:edax_mcp_server/main.dart';
import 'package:dart_mcp/server.dart';
import 'package:libedax4dart/libedax4dart.dart';
import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  group('EdaxMcpServer', () {
    late LibEdax libEdax;
    late EdaxMcpServer server;
    late StreamController<String> clientToServer;
    late StreamController<String> serverToClient;
    late Stream<Map<String, dynamic>> serverResponses;

    setUpAll(() {
      final baseDir = Directory.current.path;
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

      libEdax = LibEdax(dllPath);
      libEdax.libedaxInitialize(['', '-eval-file', evalPath]);
    });

    setUp(() async {
      clientToServer = StreamController<String>();
      serverToClient = StreamController<String>();

      serverResponses = serverToClient.stream.asBroadcastStream().map((s) {
        return jsonDecode(s) as Map<String, dynamic>;
      });

      final serverChannel = StreamChannel<String>(
        clientToServer.stream,
        serverToClient.sink,
      );

      server = EdaxMcpServer(
        serverChannel,
        implementation: Implementation(name: 'test_server', version: '0.0.1'),
        libEdax: libEdax,
        baseDir: Directory.current.path,
      );
    });

    tearDown(() async {
      await server.shutdown();
      await clientToServer.close();
      await serverToClient.close();
    });

    test('get_moves tool returns current moves', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );

      // Wait for initialize response
      await serverResponses.firstWhere((m) => m['id'] == initId);

      // 2. Initialized notification
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );

      await server.initialized;

      // 3. Call get_moves
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'get_moves',
            'arguments': <String, dynamic>{},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );

      expect(response['result']['content'][0]['text'], isA<String>());
    });

    test('edax_hint tool returns hints', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );

      await serverResponses.firstWhere((m) => m['id'] == initId);

      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );

      await server.initialized;

      // 2. Call edax_hint
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'edax_hint',
            'arguments': <String, dynamic>{'n': 2},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );

      final text = response['result']['content'][0]['text'] as String;
      expect(text, contains('Hint 1:'));
      expect(text, contains('Hint 2:'));
    });

    test('play_move tool plays a move', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );

      await serverResponses.firstWhere((m) => m['id'] == initId);

      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );

      await server.initialized;

      // 2. Play move
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'play_move',
            'arguments': <String, dynamic>{'move': 'f5'},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );
      expect(
        response['result']['content'][0]['text'],
        contains('Played move: f5'),
      );

      // 3. Verify move is played
      final callId2 = 3;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId2,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'get_moves',
            'arguments': <String, dynamic>{},
          },
        }),
      );

      final response2 = await serverResponses.firstWhere(
        (m) => m['id'] == callId2,
      );
      expect(
        response2['result']['content'][0]['text'].toLowerCase(),
        contains('f5'),
      );
    });

    test('get_board tool returns board state', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );
      await serverResponses.firstWhere((m) => m['id'] == initId);
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      await server.initialized;

      // 2. Call get_board
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'get_board',
            'arguments': <String, dynamic>{},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );
      expect(
        response['result']['content'][0]['text'],
        contains('A B C D E F G H'),
      );
      expect(
        response['result']['structuredContent']['player_bitboard'],
        isA<String>(),
      );
    });

    test('get_mobility_count returns count', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );
      await serverResponses.firstWhere((m) => m['id'] == initId);
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      await server.initialized;

      // 2. Call get_mobility_count
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'get_mobility_count',
            'arguments': <String, dynamic>{'color': 'black'},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );
      expect(
        response['result']['content'][0]['text'],
        contains('Mobility count for black:'),
      );
    });

    test('play_print returns summary', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );
      await serverResponses.firstWhere((m) => m['id'] == initId);
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      await server.initialized;

      // 2. Call play_print
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'play_print',
            'arguments': <String, dynamic>{},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );
      final text = response['result']['content'][0]['text'] as String;
      expect(text, contains('Discs:'));
      expect(text, contains('Mobility:'));
      expect(text, contains('Turn:'));
    });

    test('edax_get_current_player returns current player', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );
      await serverResponses.firstWhere((m) => m['id'] == initId);
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      await server.initialized;

      // 2. Call edax_get_current_player
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'edax_get_current_player',
            'arguments': <String, dynamic>{},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );
      final text = response['result']['content'][0]['text'] as String;
      expect(text, anyOf('black', 'white'));
    });

    test('edax_get_opponent_player returns opponent player', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );
      await serverResponses.firstWhere((m) => m['id'] == initId);
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      await server.initialized;

      // 2. Call edax_get_opponent_player
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'edax_get_opponent_player',
            'arguments': <String, dynamic>{},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );
      final text = response['result']['content'][0]['text'] as String;
      expect(text, anyOf('black', 'white'));
    });

    test('edax_get_last_move returns last move or none', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );
      await serverResponses.firstWhere((m) => m['id'] == initId);
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      await server.initialized;

      // 2. Call edax_get_last_move
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'edax_get_last_move',
            'arguments': <String, dynamic>{},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );
      final text = response['result']['content'][0]['text'] as String;
      expect(text, isA<String>());
    });

    test('edax_is_game_over returns boolean', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );
      await serverResponses.firstWhere((m) => m['id'] == initId);
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      await server.initialized;

      // 2. Call edax_is_game_over
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'edax_is_game_over',
            'arguments': <String, dynamic>{},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );
      final text = response['result']['content'][0]['text'] as String;
      expect(text, anyOf('true', 'false'));
    });

    test('edax_init initializes board', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );
      await serverResponses.firstWhere((m) => m['id'] == initId);
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      await server.initialized;

      // 2. Call edax_init
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'edax_init',
            'arguments': <String, dynamic>{},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );
      expect(
        response['result']['content'][0]['text'],
        contains('Board initialized'),
      );
    });

    test('edax_move plays a move', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );
      await serverResponses.firstWhere((m) => m['id'] == initId);
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      await server.initialized;

      // 2. Call edax_move
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'edax_move',
            'arguments': <String, dynamic>{'move': 'f5'},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );
      expect(
        response['result']['content'][0]['text'],
        contains('Played move: f5'),
      );
    });

    test('edax_undo/redo undoes and redoes a move', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );
      await serverResponses.firstWhere((m) => m['id'] == initId);
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      await server.initialized;

      // 2. Undo
      final undoId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': undoId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'edax_undo',
            'arguments': <String, dynamic>{},
          },
        }),
      );
      final undoResponse = await serverResponses.firstWhere(
        (m) => m['id'] == undoId,
      );
      expect(
        undoResponse['result']['content'][0]['text'],
        contains('Undo successful'),
      );

      // 3. Redo
      final redoId = 3;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': redoId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'edax_redo',
            'arguments': <String, dynamic>{},
          },
        }),
      );
      final redoResponse = await serverResponses.firstWhere(
        (m) => m['id'] == redoId,
      );
      expect(
        redoResponse['result']['content'][0]['text'],
        contains('Redo successful'),
      );
    });

    test('edax_options_dump dumps options', () async {
      // 1. Initialize
      final initId = 1;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': initId,
          'method': 'initialize',
          'params': <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{},
            'clientInfo': <String, String>{
              'name': 'test-client',
              'version': '1.0.0',
            },
          },
        }),
      );
      await serverResponses.firstWhere((m) => m['id'] == initId);
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      await server.initialized;

      // 2. Call edax_options_dump
      final callId = 2;
      clientToServer.add(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': callId,
          'method': 'tools/call',
          'params': <String, dynamic>{
            'name': 'edax_options_dump',
            'arguments': <String, dynamic>{},
          },
        }),
      );

      final response = await serverResponses.firstWhere(
        (m) => m['id'] == callId,
      );
      expect(
        response['result']['content'][0]['text'],
        contains('Options dumped'),
      );
    });
  });
}

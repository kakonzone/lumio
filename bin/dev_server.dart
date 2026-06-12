library;

/// Local Lumio API mock — run with: `dart run bin/dev_server.dart`
///
/// Not linked from Flutter `main()`; does not ship in the APK.
import 'dart:io';

import 'package:lumio_tv/routes/api_routes.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final host = Platform.environment['HOST'] ?? '0.0.0.0';

  final router = buildRouter();
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: {
        ACCESS_CONTROL_ALLOW_ORIGIN: '*',
        ACCESS_CONTROL_ALLOW_HEADERS: 'Content-Type, Authorization',
        ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, DELETE, OPTIONS',
      }))
      .addHandler(router.call);

  final server = await io.serve(handler, host, port);
  server.autoCompress = true;
  _printBanner(host, port);

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close(force: false);
    // ignore: avoid_print
    print('\n[Lumio] dev server stopped.');
    exit(0);
  });

  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) async {
      await server.close(force: false);
      exit(0);
    });
  }
}

void _printBanner(String host, int port) {
  final androidUrl = 'http://10.0.2.2:$port';
  final localUrl = 'http://localhost:$port';
  // ignore: avoid_print
  print('''
╔══════════════════════════════════════════╗
║      LUMIO TV DEV API (bin/dev_server)   ║
╠══════════════════════════════════════════╣
║  Host   : $host
║  Local  : $localUrl
║  Android emulator: $androidUrl
╚══════════════════════════════════════════╝
''');
}

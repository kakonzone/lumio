import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import '../lib/routes/api_routes.dart'; // ← relative import (fixed)

void main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final host = Platform.environment['HOST'] ??
      '0.0.0.0'; // 0.0.0.0 accepts LAN connections

  // ── Build router ─────────────────────────────────────────
  final router = buildRouter();

  // ── Pipeline ─────────────────────────────────────────────
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: {
        ACCESS_CONTROL_ALLOW_ORIGIN: '*',
        ACCESS_CONTROL_ALLOW_HEADERS: 'Content-Type, Authorization',
        ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, DELETE, OPTIONS',
      }))
      .addHandler(router.call);

  // ── Start server ──────────────────────────────────────────
  final server = await io.serve(handler, host, port);
  server.autoCompress = true;

  _printBanner(host, port);

  // ── Graceful shutdown on Ctrl-C / SIGTERM ─────────────────
  ProcessSignal.sigint.watch().listen((_) async {
    await server.close(force: false);
    print('\n[Lumio TV] Server stopped.');
    exit(0);
  });

  // SIGTERM is not available on Windows — guard with a platform check
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) async {
      await server.close(force: false);
      exit(0);
    });
  }
}

// ── Banner ────────────────────────────────────────────────────
void _printBanner(String host, int port) {
  // Android emulator reaches the host via 10.0.2.2
  final androidUrl = 'http://10.0.2.2:$port';
  final localUrl = 'http://localhost:$port';

  print('');
  print('╔══════════════════════════════════════════╗');
  print('║      🌟  LUMIO TV API SERVER  🌟          ║');
  print('╠══════════════════════════════════════════╣');
  print('║  Host   : $host');
  print('║  Local  : $localUrl');
  print('║  Android: $androidUrl');
  print('╠══════════════════════════════════════════╣');
  print('║  Endpoints:                              ║');
  print('║  GET  /health                            ║');
  print('║  GET  /api/channels                      ║');
  print('║  GET  /api/channels?category=Sports      ║');
  print('║  GET  /api/channels?live=true            ║');
  print('║  GET  /api/channels/:id                  ║');
  print('║  GET  /api/matches                       ║');
  print('║  GET  /api/matches?status=live           ║');
  print('║  GET  /api/matches?status=today          ║');
  print('║  GET  /api/matches?status=upcoming       ║');
  print('║  GET  /api/matches/predictions           ║');
  print('║  GET  /api/news                          ║');
  print('║  GET  /api/live                          ║');
  print('╚══════════════════════════════════════════╝');
  print('');
}

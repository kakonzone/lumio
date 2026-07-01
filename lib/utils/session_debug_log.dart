import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Session-scoped NDJSON debug log (Cursor debug mode).
void sessionDebugLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, dynamic>? data,
  String runId = 'pre-fix',
}) {
  final payload = <String, dynamic>{
    'sessionId': '5590fd',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': location,
    'message': message,
    'hypothesisId': hypothesisId,
    'runId': runId,
    if (data != null) 'data': data,
  };
  debugPrint('[debug-5590fd] $location: $message $data');
  _postIngest(payload);
}

void _postIngest(Map<String, dynamic> payload) {
  final body = utf8.encode(jsonEncode(payload));
  HttpClient()
      .postUrl(
        Uri.parse(
          'http://127.0.0.1:7695/ingest/19d49393-f58f-42db-a4cf-b94ab55a30ae',
        ),
      )
      .then((req) {
        req.headers.set('Content-Type', 'application/json');
        req.headers.set('X-Debug-Session-Id', '5590fd');
        req.add(body);
        return req.close();
      })
      .then((res) => res.drain())
      .catchError((_) {});
}

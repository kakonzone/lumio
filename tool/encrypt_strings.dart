// ignore_for_file: avoid_print
/// বিল্ড-টাইম স্ট্রিং এনক্রিপ্টর — সংবেদনশীল স্ট্রিং XOR/AES পেলোড জেনারেট করে।
///
/// **চালান:**
/// ```bash
/// dart run tool/encrypt_strings.dart --input tool/secrets_input.json
/// ```
///
/// `secrets_input.json` উদাহরণ:
/// ```json
/// { "strings": { "api_host": "api.yourdomain.com" } }
/// ```
library;

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final inputPath = _arg(args, '--input') ?? 'tool/secrets_input.json';
  final xorKey = int.parse(_arg(args, '--xor-key') ?? '0xA7');
  final outCpp =
      _arg(args, '--out-cpp') ?? 'android/app/src/main/cpp/generated_secrets.h';
  final outDart =
      _arg(args, '--out-dart') ?? 'lib/security/generated_secrets.dart';

  final file = File(inputPath);
  if (!file.existsSync()) {
    stderr.writeln('Input not found: $inputPath');
    stderr.writeln(
        'Create tool/secrets_input.json from tool/secrets_input.example.json');
    exit(1);
  }

  final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final strings = map['strings'] as Map<String, dynamic>? ?? {};

  final cppBlocks = <String>[];
  final dartBlocks = <String>[];

  for (final entry in strings.entries) {
    final name = entry.key.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final plain = entry.value.toString();
    final xorBytes = plain.codeUnits.map((c) => c ^ xorKey).toList();
    cppBlocks.add(
      'const std::vector<uint8_t> kEnc_$name = { ${xorBytes.map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(', ')} };',
    );
    dartBlocks.add(
      "  static const List<int> ${name}Xor = <int>[${xorBytes.join(', ')}];",
    );
  }

  File(outCpp).writeAsStringSync('''
// AUTO-GENERATED — dart run tool/encrypt_strings.dart
#pragma once
#include <vector>
#include <cstdint>

namespace lumio_generated {
${cppBlocks.join('\n')}
}
''');

  File(outDart).writeAsStringSync('''
// AUTO-GENERATED — dart run tool/encrypt_strings.dart
import 'encryption_helper.dart';

class GeneratedSecrets {
  GeneratedSecrets._();
${dartBlocks.join('\n')}
  static const int xorKey = $xorKey;

  static String decodeXor(List<int> data) =>
      EncryptionHelper.xorDecode(data, xorKey);
}
''');

  print('Wrote $outCpp and $outDart (${strings.length} strings)');
}

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  return null;
}

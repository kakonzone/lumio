/// Files permitted to contain cleartext URL literals (legacy streams / dev emulator).
class CleartextAllowlist {
  CleartextAllowlist._();

  static const paths = <String>{
    'lib/services/api_service.dart',
    'lib/services/background_service.dart',
    'lib/services/scanned_iptv_service.dart',
    'lib/screens/player_screen.dart',
    'lib/provider/app_provider.dart',
  };
}

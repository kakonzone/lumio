/// Files permitted to contain cleartext URL literals (legacy streams / dev emulator).
class CleartextAllowlist {
  CleartextAllowlist._();

  static const paths = <String>{
    'lib/services/api_service.dart',
    'lib/services/background_service.dart',
    'lib/services/scanned_iptv_service.dart',
    'lib/screens/player_screen.dart',
    'lib/provider/app_provider.dart',
    'lib/screens/onboarding/source_detail_screen.dart',
    'lib/config/app_config.dart',
    'lib/security/stream_security_prober.dart',
    'lib/security/stream_upgrade_service.dart',
    'lib/widgets/sources/source_form.dart',
    'lib/utils/agent_debug_log.dart',
  };
}

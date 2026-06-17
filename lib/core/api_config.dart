/// API keys & endpoints (keep secrets out of UI code).
class ApiConfig {
  ApiConfig._();

  static const String cricbuzzRapidApiKey = String.fromEnvironment(
    'CRICBUZZ_RAPID_API_KEY',
    defaultValue: '',
  );
  static const cricbuzzRapidApiHost = 'cricbuzz-cricket.p.rapidapi.com';

  static bool get hasCricbuzzKey => cricbuzzRapidApiKey.isNotEmpty;
}

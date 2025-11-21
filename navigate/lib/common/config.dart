class AppConfig {
  // AI Client Configuration
  static const String aiApiUrl = 'https://api.openai.com';
  static const String aiModel = 'gpt-4';
  static const double aiTemperature = 0.7;
  static const int aiStreamTimeoutSeconds = 60;
  static const int aiTestTimeoutSeconds = 10;
  static const int aiMaxContextLength = 10000;

  // Kaspa Explorer API Configuration
  static const String kaspaExplorerApiUrl = 'https://api.kaspa.org';
  static const int kaspaExplorerTimeoutSeconds = 10;
  static const int kaspaExplorerDefaultLimit = 20;

  // KNS API Configuration
  static const String knsApiUrl = 'https://api.knsdomains.org/mainnet/api/v1';
  static const int knsApiTimeoutSeconds = 10;
  static const int knsDefaultPageSize = 10;
}


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

  // Kasplex API Configuration
  static const String kasplexApiUrl = 'https://api.kasplex.org/v1';
  static const int kasplexApiTimeoutSeconds = 15;

  // Kaspa.com API Configuration
  static const String kaspaComApiUrl = 'https://api.kaspa.com';
  static const int kaspaComApiTimeoutSeconds = 15;
}


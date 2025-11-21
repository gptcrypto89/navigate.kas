import 'encrypted_storage_service.dart';
import 'wallet_service.dart';
import '../common/constants.dart';

/// Service for managing application settings
class SettingsService {
  static final EncryptedStorage _storage = EncryptedStorage();
  
  /// Get password from WalletService (when wallet is unlocked)
  static String? _getPassword() {
    return WalletService.getCurrentPassword();
  }
  
  /// Helper to ensure password is available
  static String _requirePassword() {
    final password = _getPassword();
    if (password == null) {
      throw Exception(ERR_WALLET_NOT_UNLOCKED);
    }
    return password;
  }

  /// Get browser settings (uses current wallet password)
  static Future<Map<String, dynamic>> getBrowserSettings() async {
    final password = _requirePassword();
    final data = await _storage.loadData(password);
    if (data == null) {
      return _getDefaultBrowserSettings();
    }

    final settings = data['settings'] as Map<String, dynamic>?;
    return settings?['browser'] as Map<String, dynamic>? ?? _getDefaultBrowserSettings();
  }

  /// Get AI settings (uses current wallet password)
  static Future<Map<String, dynamic>> getAISettings() async {
    final password = _requirePassword();
    final data = await _storage.loadData(password);
    if (data == null) {
      return _getDefaultAISettings();
    }

    final settings = data['settings'] as Map<String, dynamic>?;
    return settings?['ai'] as Map<String, dynamic>? ?? _getDefaultAISettings();
  }

  /// Update browser settings (uses current wallet password)
  static Future<void> updateBrowserSettings(Map<String, dynamic> browserSettings) async {
    final password = _requirePassword();
    final data = await _storage.loadData(password);
    if (data == null) throw Exception(ERR_FAILED_LOAD_STORAGE);

    if (data['settings'] == null) {
      data['settings'] = {
        'browser': browserSettings,
        'ai': _getDefaultAISettings(),
      };
    } else {
      (data['settings'] as Map<String, dynamic>)['browser'] = browserSettings;
    }

    data['updatedAt'] = DateTime.now().toIso8601String();
    await _storage.saveData(data, password);
  }

  /// Update AI settings (uses current wallet password)
  static Future<void> updateAISettings(Map<String, dynamic> aiSettings) async {
    final password = _requirePassword();
    final data = await _storage.loadData(password);
    if (data == null) throw Exception(ERR_FAILED_LOAD_STORAGE);

    if (data['settings'] == null) {
      data['settings'] = {
        'browser': _getDefaultBrowserSettings(),
        'ai': aiSettings,
      };
    } else {
      (data['settings'] as Map<String, dynamic>)['ai'] = aiSettings;
    }

    data['updatedAt'] = DateTime.now().toIso8601String();
    await _storage.saveData(data, password);
  }

  /// Update a specific browser setting (uses current wallet password)
  static Future<void> updateBrowserSetting(String key, dynamic value) async {
    final settings = await getBrowserSettings();
    settings[key] = value;
    await updateBrowserSettings(settings);
  }

  /// Update a specific AI setting (uses current wallet password)
  static Future<void> updateAISetting(String key, dynamic value) async {
    final settings = await getAISettings();
    settings[key] = value;
    await updateAISettings(settings);
  }

  /// Get default browser settings
  static Map<String, dynamic> _getDefaultBrowserSettings() {
    return {
      'theme': BROWSER_DEFAULT_THEME,
      'defaultSearchEngine': BROWSER_DEFAULT_SEARCH_ENGINE,
      'enableJavaScript': true,
      'enableCookies': true,
    };
  }

  /// Get default AI settings
  static Map<String, dynamic> _getDefaultAISettings() {
    return {
      'enableAI': true,
      'apiUrl': AI_DEFAULT_API_URL,
      'modelName': AI_DEFAULT_MODEL,
      'apiKey': '',
      'temperature': 0.7,
      'systemPrompt': AI_DEFAULT_SYSTEM_PROMPT,
    };
  }
}


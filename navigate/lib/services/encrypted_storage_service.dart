import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:flutter/foundation.dart';

/// Encrypted storage service for wallet data
/// 
/// Features:
/// - AES-256 encryption
/// - PBKDF2 password-based key derivation
/// - Password verification without keychain
/// - Single encrypted file storage
/// - Cross-platform support
/// - Encrypt-then-MAC (HMAC-SHA256) for integrity
class EncryptedStorage {
  static const String _fileName = 'navigate.bin';
  static const int _saltLength = 32;
  static const int _iterations = 10000; // User requested 10k iterations
  static const int _keyLength = 32;
  static const int _hmacLength = 32;

  /// Check if password/data file exists
  Future<bool> hasPassword() async {
    try {
      final file = await _getStorageFile();
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Set initial password (creates new encrypted file)
  Future<void> setPassword(String password) async {
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }

    // Create initial empty data structure for the browser
    final data = {
      'version': 1,
      'wallets': [], // List of SavedWallet objects
      'activeWalletId': null, // ID of currently active wallet (mnemonic NOT stored)
      'bookmarks': [], // List of Bookmark objects
      'bookmarkFolders': [], // List of BookmarkFolder objects
      'settings': {
        'browser': {
          'theme': 'Dark',
          'defaultSearchEngine': 'Google',
          'enableJavaScript': true,
          'enableCookies': true,
        },
        'ai': {
          'enableAI': true,
          'aiModel': 'GPT-4',
          'temperature': 0.7,
          'systemPrompt': 'You are a helpful assistant.',
        },
      },
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await saveData(data, password);
  }

  /// Verify password by attempting to decrypt
  Future<bool> verifyPassword(String password) async {
    try {
      await loadData(password);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Change password (decrypt with old, re-encrypt with new)
  Future<void> changePassword(String oldPassword, String newPassword) async {
    // Verify old password and load data
    final data = await loadData(oldPassword);
    if (data == null) {
      throw Exception('Current password is incorrect');
    }

    // Re-encrypt with new password
    await saveData(data, newPassword);
  }

  /// Save encrypted data
  Future<void> saveData(Map<String, dynamic> data, String password) async {
    try {
      // Convert data to JSON
      final jsonString = jsonEncode(data);
      
      // Generate random salt
      final salt = _generateRandomBytes(_saltLength);
      
      // Derive keys from password using PBKDF2 (runs in isolate)
      // Returns 64 bytes: 32 for encryption, 32 for HMAC
      final keys = await _deriveKeys(password, salt, _iterations);
      final encKey = encrypt_lib.Key(keys.sublist(0, 32));
      final hmacKey = keys.sublist(32, 64);
      
      final iv = encrypt_lib.IV.fromSecureRandom(16);
      
      // Encrypt data (lightweight operation)
      final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(encKey, mode: encrypt_lib.AESMode.cbc));
      final encrypted = encrypter.encrypt(jsonString, iv: iv);
      
      // Calculate HMAC
      final hmac = HMac(SHA256Digest(), 64);
      hmac.init(KeyParameter(hmacKey));
      final dataToSign = Uint8List.fromList([
        ...salt,
        ...iv.bytes,
        ...encrypted.bytes,
      ]);
      final signature = hmac.process(dataToSign);

      // File format: [salt(32)][iv(16)][hmac(32)][encrypted_data]
      final combined = Uint8List.fromList([
        ...salt,
        ...iv.bytes,
        ...signature,
        ...encrypted.bytes,
      ]);
      
      // Write to file
      final file = await _getStorageFile();
      await file.writeAsBytes(combined);
    } catch (e) {
      throw Exception('Failed to save data: $e');
    }
  }

  /// Load and decrypt data
  Future<Map<String, dynamic>?> loadData(String password) async {
    try {
      final file = await _getStorageFile();
      
      // Check if file exists
      if (!await file.exists()) {
        return null;
      }
      
      // Read encrypted data
      final bytes = await file.readAsBytes();
      
      if (bytes.length < _saltLength + 16 + _hmacLength) {
        throw Exception('Invalid encrypted data length');
      }

      final salt = bytes.sublist(0, _saltLength);
      final iv = encrypt_lib.IV(Uint8List.fromList(bytes.sublist(_saltLength, _saltLength + 16)));
      final storedHmac = bytes.sublist(_saltLength + 16, _saltLength + 16 + _hmacLength);
      final encryptedBytes = bytes.sublist(_saltLength + 16 + _hmacLength);
      
      // Derive keys
      final keys = await _deriveKeys(password, salt, _iterations);
      final encKey = encrypt_lib.Key(keys.sublist(0, 32));
      final hmacKey = keys.sublist(32, 64);
      
      // Verify HMAC
      final hmac = HMac(SHA256Digest(), 64);
      hmac.init(KeyParameter(hmacKey));
      final dataToSign = Uint8List.fromList([
        ...salt,
        ...iv.bytes,
        ...encryptedBytes,
      ]);
      final calculatedHmac = hmac.process(dataToSign);
      
      if (!listEquals(storedHmac, calculatedHmac)) {
        throw Exception('Data integrity check failed (HMAC mismatch)');
      }

      // Decrypt data
      final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(encKey, mode: encrypt_lib.AESMode.cbc));
      final encrypted = encrypt_lib.Encrypted(Uint8List.fromList(encryptedBytes));
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      
      return jsonDecode(decrypted) as Map<String, dynamic>;

    } catch (e) {
      throw Exception('Failed to load data. Wrong password or corrupted file: $e');
    }
  }

  /// Delete all data
  Future<void> deleteAll() async {
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete data: $e');
    }
  }

  /// Get storage file path
  Future<File> _getStorageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  /// Derive keys from password using PBKDF2
  /// Runs in isolate to avoid blocking UI thread
  Future<Uint8List> _deriveKeys(String password, List<int> salt, int iterations) async {
    return await compute(_deriveKeysInIsolate, {
      'password': password,
      'salt': salt,
      'iterations': iterations,
      'keyLength': 64, // 32 encryption + 32 HMAC
    });
  }

  /// Derive keys in isolate (static function for compute)
  static Uint8List _deriveKeysInIsolate(Map<String, dynamic> params) {
    final password = params['password'] as String;
    final salt = params['salt'] as List<int>;
    final iterations = params['iterations'] as int;
    final keyLength = params['keyLength'] as int;
    
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(Uint8List.fromList(salt), iterations, keyLength));
    
    final key = derivator.process(Uint8List.fromList(utf8.encode(password)));
    return key;
  }

  /// Generate random bytes
  Uint8List _generateRandomBytes(int length) {
    final random = FortunaRandom();
    final seed = List<int>.generate(32, (i) => DateTime.now().millisecondsSinceEpoch + i);
    random.seed(KeyParameter(Uint8List.fromList(seed)));
    return random.nextBytes(length);
  }

  /// Export encrypted backup (returns file content as bytes)
  Future<Uint8List?> exportBackup(String password) async {
    try {
      // Verify password first
      if (!await verifyPassword(password)) {
        throw Exception('Invalid password');
      }

      final file = await _getStorageFile();
      if (!await file.exists()) {
        return null;
      }

      return await file.readAsBytes();
    } catch (e) {
      throw Exception('Failed to export backup: $e');
    }
  }

  /// Import encrypted backup
  Future<void> importBackup(Uint8List backupData, String password) async {
    try {
      final file = await _getStorageFile();
      await file.writeAsBytes(backupData);

      // Try to decrypt with provided password to verify
      await loadData(password);
    } catch (e) {
      // If import fails, delete the bad file
      final file = await _getStorageFile();
      if (await file.exists()) {
        await file.delete();
      }
      throw Exception('Failed to import backup: $e');
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:hd_wallet/hd_wallet.dart';
import '../common/enums.dart';
import 'encrypted_storage_service.dart';
import '../models/wallet_models.dart';

/// Service for managing wallet operations with encrypted storage
/// 
/// Security features:
/// - All wallet data stored in AES-256 encrypted file
/// - Active wallet mnemonic kept in memory only (never persisted)
/// - Requires master password for all operations
class WalletService {
  static final EncryptedStorage _storage = EncryptedStorage();
  
  // In-memory storage for active wallet (never persisted)
  static String? _currentPassword;
  static String? _currentMnemonic; // Only in memory when wallet is unlocked
  static String? _currentAddress;
  static String? _currentPublicKey;
  static String? _currentWalletId;

  /// Initialize storage with password (creates encrypted file if needed)
  static Future<void> initializeStorage(String password) async {
    if (!await _storage.hasPassword()) {
      await _storage.setPassword(password);
    }
    _currentPassword = password;
  }

  /// Verify password and unlock storage
  static Future<bool> verifyPassword(String password) async {
    try {
      final isValid = await _storage.verifyPassword(password);
      if (isValid) {
        _currentPassword = password;
      }
      return isValid;
    } catch (e) {
      return false;
    }
  }

  /// Change master password
  static Future<void> changePassword(String oldPassword, String newPassword) async {
    await _storage.changePassword(oldPassword, newPassword);
    _currentPassword = newPassword;
  }

  /// Get all saved wallets (uses master password from memory)
  static Future<List<SavedWallet>> getSavedWallets() async {
    final password = _currentPassword;
    if (password == null) {
      throw Exception('Master password not set. Please unlock first.');
    }
    final data = await _storage.loadData(password);
    if (data == null) return [];

    final walletsJson = data['wallets'] as List<dynamic>? ?? [];
    return walletsJson.map((w) => SavedWallet.fromJson(w as Map<String, dynamic>)).toList();
  }

  /// Save wallet to encrypted storage (uses master password from memory)
  static Future<void> saveWalletToList(SavedWallet wallet) async {
    final password = _currentPassword;
    if (password == null) {
      throw Exception('Master password not set. Please unlock first.');
    }
    final data = await _storage.loadData(password);
    if (data == null) throw Exception('Failed to load storage data');

    final wallets = (data['wallets'] as List<dynamic>? ?? [])
        .map((w) => SavedWallet.fromJson(w as Map<String, dynamic>))
        .toList();
    
    wallets.add(wallet);
    
    data['wallets'] = wallets.map((w) => w.toJson()).toList();
    data['updatedAt'] = DateTime.now().toIso8601String();
    
    await _storage.saveData(data, password);
  }

  /// Update wallet in encrypted storage (uses master password from memory)
  static Future<void> updateWallet(SavedWallet wallet) async {
    final password = _currentPassword;
    if (password == null) {
      throw Exception('Master password not set. Please unlock first.');
    }
    final data = await _storage.loadData(password);
    if (data == null) throw Exception('Failed to load storage data');

    final wallets = (data['wallets'] as List<dynamic>? ?? [])
        .map((w) => SavedWallet.fromJson(w as Map<String, dynamic>))
        .toList();
    
    final index = wallets.indexWhere((w) => w.id == wallet.id);
    if (index != -1) {
      wallets[index] = wallet;
      data['wallets'] = wallets.map((w) => w.toJson()).toList();
      data['updatedAt'] = DateTime.now().toIso8601String();
      await _storage.saveData(data, password);
    }
  }

  /// Delete wallet from encrypted storage (uses master password from memory)
  static Future<void> deleteWallet(String walletId) async {
    final password = _currentPassword;
    if (password == null) {
      throw Exception('Master password not set. Please unlock first.');
    }
    final data = await _storage.loadData(password);
    if (data == null) throw Exception('Failed to load storage data');

    final wallets = (data['wallets'] as List<dynamic>? ?? [])
        .map((w) => SavedWallet.fromJson(w as Map<String, dynamic>))
        .toList();
    
    wallets.removeWhere((w) => w.id == walletId);
    
    data['wallets'] = wallets.map((w) => w.toJson()).toList();
    
    // If active wallet was deleted, clear wallet data (but keep password)
    if (data['activeWalletId'] == walletId) {
      data['activeWalletId'] = null;
      _clearWalletData();
    }
    
    data['updatedAt'] = DateTime.now().toIso8601String();
    await _storage.saveData(data, password);
  }

  /// Store mnemonic (EncryptedStorage uses AES-256 + HMAC-SHA256)
  /// The entire file is encrypted, so mnemonics are stored as part of the
  /// encrypted data structure.
  /// WARNING: This returns the mnemonic in plain text as it is just a pass-through
  /// for the EncryptedStorage to handle the actual file encryption.
  static String encryptMnemonic(String mnemonic) {
    if (_currentPassword == null) {
      throw Exception('Master password not set. Please unlock first.');
    }
    // No additional encryption needed - file-level AES-256 provides security
    return mnemonic;
  }

  /// Retrieve mnemonic (EncryptedStorage uses AES-256 + HMAC-SHA256)
  /// WARNING: This returns the mnemonic in plain text. Ensure memory is cleared
  /// when no longer needed.
  static String decryptMnemonic(String mnemonic) {
    if (_currentPassword == null) {
      throw Exception('Master password not set. Please unlock first.');
    }
    // No additional decryption needed - file-level AES-256 provides security
    return mnemonic;
  }

  /// Set active wallet (unlocks wallet and keeps mnemonic in memory)
  /// Uses master password from memory
  static Future<void> setActiveWallet(SavedWallet wallet) async {
    if (_currentPassword == null) {
      throw Exception('Master password not set. Please unlock first.');
    }
    
    // Decrypt mnemonic and passphrase
    final mnemonic = decryptMnemonic(wallet.encryptedMnemonic);
    final passphrase = wallet.encryptedPassphrase != null 
        ? decryptMnemonic(wallet.encryptedPassphrase!)
        : '';
    
    if (!Mnemonic.validate(mnemonic)) {
      throw Exception('Invalid password or corrupted wallet data');
    }

    // Get signature type based on provider
    final signatureType = wallet.walletProvider == WalletProvider.tangem 
        ? SignatureType.ecdsa 
        : SignatureType.schnorr;

    // Derive account with passphrase and signature type
    final hdWallet = HDWallet.fromMnemonic(mnemonic, passphrase: passphrase);
    final path = 'm/44\'/111111\'/0\'/0/0';
    final account = hdWallet.deriveAccountFromPath(path, CoinType.kaspa, signatureType: signatureType);

    // Store in memory only (never persist mnemonic)
    _currentMnemonic = mnemonic;
    _currentAddress = account.address;
    _currentPublicKey = account.publicKeyHex;
    _currentWalletId = wallet.id;

    // Update encrypted storage with active wallet ID (not mnemonic)
    final password = _currentPassword;
    if (password != null) {
      final data = await _storage.loadData(password);
      if (data != null) {
        data['activeWalletId'] = wallet.id;
        data['updatedAt'] = DateTime.now().toIso8601String();
        await _storage.saveData(data, password);
      }
    }
  }

  /// Check if wallet is initialized (has active wallet in memory)
  static bool isWalletInitialized() {
    return _currentMnemonic != null && _currentAddress != null;
  }

  /// Check if storage file exists
  static Future<bool> hasStorage() async {
    return await _storage.hasPassword();
  }

  /// Create a new wallet with random mnemonic
  /// Returns the mnemonic (must be saved with saveWalletToList)
  static Future<({WalletAccount account, String mnemonic})> createWallet({
    String passphrase = '',
    WalletProvider provider = WalletProvider.kasware,
  }) async {
    // Generate new wallet with 24 words (256 bits entropy)
    final wallet = HDWallet.generate(wordCount: 24, passphrase: passphrase);
    
    // Get signature type based on provider
    final signatureType = provider == WalletProvider.tangem 
        ? SignatureType.ecdsa 
        : SignatureType.schnorr;
    
    // Derive Kaspa account with signature type
    final path = 'm/44\'/111111\'/0\'/0/0';
    final account = wallet.deriveAccountFromPath(path, CoinType.kaspa, signatureType: signatureType);

    return (account: account, mnemonic: wallet.mnemonic);
  }

  /// Import wallet from mnemonic
  /// Returns the account (must be saved with saveWalletToList)
  static Future<WalletAccount> importWallet(
    String mnemonic, {
    String passphrase = '',
    WalletProvider provider = WalletProvider.kasware,
  }) async {
    // Validate mnemonic
    if (!Mnemonic.validate(mnemonic)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }

    // Create wallet from mnemonic with passphrase
    final wallet = HDWallet.fromMnemonic(mnemonic, passphrase: passphrase);
    
    // Get signature type based on provider
    final signatureType = provider == WalletProvider.tangem 
        ? SignatureType.ecdsa 
        : SignatureType.schnorr;
    
    // Derive Kaspa account with signature type
    final path = 'm/44\'/111111\'/0\'/0/0';
    final account = wallet.deriveAccountFromPath(path, CoinType.kaspa, signatureType: signatureType);

    return account;
  }

  /// Generate address preview from mnemonic, passphrase, and provider
  static Future<String?> generateAddressPreview(
    String mnemonic, {
    String passphrase = '',
    WalletProvider provider = WalletProvider.kasware,
  }) async {
    try {
      if (!Mnemonic.validate(mnemonic)) {
        return null;
      }
      
      final wallet = HDWallet.fromMnemonic(mnemonic, passphrase: passphrase);
      final signatureType = provider == WalletProvider.tangem 
          ? SignatureType.ecdsa 
          : SignatureType.schnorr;
      final path = 'm/44\'/111111\'/0\'/0/0';
      final account = wallet.deriveAccountFromPath(path, CoinType.kaspa, signatureType: signatureType);
      
      return account.address;
    } catch (e) {
      return null;
    }
  }

  /// Get stored wallet address (from memory)
  static String? getWalletAddress() {
    return _currentAddress;
  }

  /// Get stored wallet public key (from memory)
  static String? getWalletPublicKey() {
    return _currentPublicKey;
  }

  /// Get stored mnemonic (from memory only - never from storage)
  /// WARNING: This returns the mnemonic in plain text from memory
  /// Use with extreme caution
  static String? getMnemonic() {
    return _currentMnemonic;
  }

  /// Get active wallet ID
  static String? getActiveWalletId() {
    return _currentWalletId;
  }

  /// Set master password (used when password is verified but wallet not yet unlocked)
  /// This allows operations like deleting wallets without having an active wallet
  static void setMasterPassword(String password) {
    _currentPassword = password;
  }

  /// Get current password (only available when wallet is unlocked or password is set)
  /// Returns null if wallet is not unlocked and password is not set
  static String? getCurrentPassword() {
    return _currentPassword;
  }

  /// Clear active wallet (removes from memory, including password)
  static void clearWallet() {
    _clearActiveWallet();
  }

  /// Internal method to clear active wallet from memory (keeps password)
  static void _clearWalletData() {
    _currentMnemonic = null;
    _currentAddress = null;
    _currentPublicKey = null;
    _currentWalletId = null;
  }

  /// Internal method to clear active wallet from memory (including password)
  /// Used for logout
  static void _clearActiveWallet() {
    _currentMnemonic = null;
    _currentAddress = null;
    _currentPublicKey = null;
    _currentWalletId = null;
    _currentPassword = null; // Clear password on logout
  }

  /// Get current wallet account (recreates from mnemonic in memory)
  static WalletAccount? getCurrentWalletAccount() {
    if (_currentMnemonic == null) return null;
    
    try {
      final wallet = HDWallet.fromMnemonic(_currentMnemonic!);
      return wallet.deriveAccount(
        CoinType.kaspa,
        account: 0,
        change: 0,
        addressIndex: 0,
      );
    } catch (e) {
      return null;
    }
  }

  /// Restore active wallet from storage (uses master password from memory)
  static Future<bool> restoreActiveWallet() async {
    final password = _currentPassword;
    if (password == null) {
      return false;
    }
    try {
      final data = await _storage.loadData(password);
      if (data == null) return false;

      final activeWalletId = data['activeWalletId'] as String?;
      if (activeWalletId == null) return false;

      final wallets = (data['wallets'] as List<dynamic>? ?? [])
          .map((w) => SavedWallet.fromJson(w as Map<String, dynamic>))
          .toList();

      final wallet = wallets.firstWhere(
        (w) => w.id == activeWalletId,
        orElse: () => throw Exception('Active wallet not found'),
      );

      await setActiveWallet(wallet);
      return true;
    } catch (e) {
      return false;
    }
  }
}


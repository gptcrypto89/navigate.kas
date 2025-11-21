import 'dart:typed_data';
import 'bip39/mnemonic.dart';
import 'bip32/hd_key.dart';
import 'bip32/derivation_path.dart';
import 'crypto/coin_type.dart';
import 'crypto/address_generator.dart';

/// Main HD Wallet class
/// 
/// Provides a complete hierarchical deterministic wallet implementation
/// supporting BIP39 (mnemonic), BIP32 (HD keys), and BIP44 (multi-account hierarchy)
class HDWallet {
  final String mnemonic;
  final HDKey masterKey;

  HDWallet._({required this.mnemonic, required this.masterKey});

  /// Create new wallet from mnemonic phrase
  /// 
  /// [mnemonic] the BIP39 mnemonic phrase
  /// [passphrase] optional BIP39 passphrase for additional security
  factory HDWallet.fromMnemonic(String mnemonic, {String passphrase = ''}) {
    if (!Mnemonic.validate(mnemonic)) {
      throw ArgumentError('Invalid mnemonic');
    }

    final seed = Mnemonic.toSeed(mnemonic, passphrase: passphrase);
    final masterKey = HDKey.fromSeed(seed);

    return HDWallet._(mnemonic: mnemonic, masterKey: masterKey);
  }

  /// Generate new wallet with random mnemonic
  /// 
  /// [wordCount] number of words in mnemonic (12, 15, 18, 21, or 24)
  /// - 12 words = 128 bits
  /// - 24 words = 256 bits (recommended)
  /// [passphrase] optional BIP39 passphrase
  factory HDWallet.generate({int wordCount = 24, String passphrase = ''}) {
    final mnemonic = Mnemonic.generate(wordCount: wordCount);
    return HDWallet.fromMnemonic(mnemonic, passphrase: passphrase);
  }

  /// Derive account for a specific coin
  /// 
  /// [coinType] the cryptocurrency type
  /// [account] account index (default 0)
  /// [change] change address indicator (0 = external/receiving, 1 = internal/change)
  /// [addressIndex] address index within the account
  WalletAccount deriveAccount(
    CoinType coinType, {
    int account = 0,
    int change = 0,
    int addressIndex = 0,
  }) {
    // Use BIP44 path by default
    final path = DerivationPath.bip44(
      coinType.value,
      account: account,
      change: change,
      addressIndex: addressIndex,
    );

    return deriveAccountFromPath(path, coinType);
  }

  /// Derive account from custom path
  /// 
  /// [path] derivation path (e.g., "m/44'/0'/0'/0/0")
  /// [coinType] the cryptocurrency type
  /// [signatureType] optional signature type for address generation
  WalletAccount deriveAccountFromPath(String path, CoinType coinType, {SignatureType? signatureType}) {
    final key = masterKey.derivePath(path);
    final address = AddressGenerator.generateAddress(key.publicKey, coinType, signatureType: signatureType);

    return WalletAccount(
      coinType: coinType,
      derivationPath: path,
      privateKey: key.privateKey,
      publicKey: key.publicKey,
      address: address,
      chainCode: key.chainCode,
    );
  }

  /// Get master extended private key (xprv)
  String get masterExtendedKey => masterKey.toBase58();

  /// Get word count
  int get wordCount => mnemonic.trim().split(RegExp(r'\s+')).length;
}

/// Represents a derived wallet account for a specific coin
class WalletAccount {
  final CoinType coinType;
  final String derivationPath;
  final Uint8List privateKey;
  final Uint8List publicKey;
  final String address;
  final Uint8List chainCode;

  WalletAccount({
    required this.coinType,
    required this.derivationPath,
    required this.privateKey,
    required this.publicKey,
    required this.address,
    required this.chainCode,
  });

  /// Get private key as hex string
  String get privateKeyHex => privateKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

  /// Get public key as hex string
  String get publicKeyHex => publicKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

  @override
  String toString() {
    return 'WalletAccount(\n'
        '  Coin: ${coinType.name} (${coinType.symbol})\n'
        '  Path: $derivationPath\n'
        '  Address: $address\n'
        ')';
  }
}


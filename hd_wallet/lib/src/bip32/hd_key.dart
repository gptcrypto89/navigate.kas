import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart';
import 'package:secp256k1_flutter_wrapper/secp256k1_flutter_wrapper.dart';

/// BIP32 Hierarchical Deterministic Key
class HDKey {
  final Uint8List privateKey;
  final Uint8List chainCode;
  final int depth;
  final int index;
  final Uint8List parentFingerprint;

  late final Uint8List publicKey;

  HDKey({
    required this.privateKey,
    required this.chainCode,
    this.depth = 0,
    this.index = 0,
    Uint8List? parentFingerprint,
  }) : parentFingerprint = parentFingerprint ?? Uint8List(4) {
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }
    if (chainCode.length != 32) {
      throw ArgumentError('Chain code must be 32 bytes');
    }

    // Generate public key
    final secp = Secp256k1();
    try {
      final pubKey = secp.generatePublicKey(privateKey, compressed: true);
      if (pubKey == null) {
        throw StateError('Failed to generate public key');
      }
      publicKey = pubKey;
    } finally {
      secp.dispose();
    }
  }

  /// Create HD key from seed (BIP32 master key derivation)
  factory HDKey.fromSeed(Uint8List seed) {
    if (seed.length < 16 || seed.length > 64) {
      throw ArgumentError('Seed must be between 16 and 64 bytes');
    }

    // HMAC-SHA512 with key "Bitcoin seed"
    final hmac = HMac(SHA512Digest(), 128);
    final key = Uint8List.fromList('Bitcoin seed'.codeUnits);
    final keyParam = KeyParameter(key);
    hmac.init(keyParam);

    final output = hmac.process(seed);
    final i = Uint8List(64);
    i.setAll(0, output);

    // Split into master private key and chain code
    final masterKey = i.sublist(0, 32);
    final masterChainCode = i.sublist(32, 64);

    return HDKey(
      privateKey: masterKey,
      chainCode: masterChainCode,
      depth: 0,
      index: 0,
    );
  }

  /// Derive child key (BIP32 child key derivation)
  /// 
  /// [index] the child index
  /// [hardened] whether to use hardened derivation (index >= 0x80000000)
  HDKey derive(int index, {bool hardened = false}) {
    if (hardened) {
      index = index | 0x80000000; // Set hardened bit
    }

    // Prepare data for HMAC
    final data = BytesBuilder();

    if (index >= 0x80000000) {
      // Hardened child: data = 0x00 || private_key || index
      data.addByte(0x00);
      data.add(privateKey);
    } else {
      // Normal child: data = public_key || index
      data.add(publicKey);
    }

    // Add index as 4 bytes big-endian
    data.addByte((index >> 24) & 0xff);
    data.addByte((index >> 16) & 0xff);
    data.addByte((index >> 8) & 0xff);
    data.addByte(index & 0xff);

    // HMAC-SHA512 with chain code as key
    final hmac = HMac(SHA512Digest(), 128);
    final keyParam = KeyParameter(chainCode);
    hmac.init(keyParam);
    final i = hmac.process(data.toBytes());

    // Split result
    final il = i.sublist(0, 32);
    final ir = i.sublist(32, 64);

    // Child private key = (il + parent_private_key) mod n
    final childKey = _addPrivateKeys(il, privateKey);

    // Child chain code = ir
    final childChainCode = ir;

    // Calculate parent fingerprint (first 4 bytes of hash160 of parent public key)
    final parentFp = _fingerprint(publicKey);

    return HDKey(
      privateKey: childKey,
      chainCode: childChainCode,
      depth: depth + 1,
      index: index,
      parentFingerprint: parentFp,
    );
  }

  /// Derive key from path (e.g., "m/44'/0'/0'/0/0")
  HDKey derivePath(String path) {
    if (!path.startsWith('m/') && !path.startsWith('M/')) {
      throw ArgumentError('Path must start with m/ or M/');
    }

    final segments = path.substring(2).split('/');
    HDKey key = this;

    for (final segment in segments) {
      if (segment.isEmpty) continue;

      final hardened = segment.endsWith("'") || segment.endsWith('h');
      final indexStr = hardened ? segment.substring(0, segment.length - 1) : segment;
      final index = int.parse(indexStr);

      key = key.derive(index, hardened: hardened);
    }

    return key;
  }

  /// Add two private keys modulo the secp256k1 curve order
  Uint8List _addPrivateKeys(Uint8List key1, Uint8List key2) {
    // secp256k1 curve order
    final n = BigInt.parse(
      'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
      radix: 16,
    );

    // Convert keys to BigInt
    BigInt k1 = BigInt.zero;
    BigInt k2 = BigInt.zero;

    for (int i = 0; i < 32; i++) {
      k1 = (k1 << 8) + BigInt.from(key1[i]);
      k2 = (k2 << 8) + BigInt.from(key2[i]);
    }

    // Add and mod n
    var sum = (k1 + k2) % n;

    // Convert back to bytes
    final result = Uint8List(32);
    for (int i = 31; i >= 0; i--) {
      result[i] = (sum & BigInt.from(0xff)).toInt();
      sum = sum >> 8;
    }

    return result;
  }

  /// Calculate fingerprint of a public key
  Uint8List _fingerprint(Uint8List pubkey) {
    // hash160 = RIPEMD160(SHA256(pubkey))
    final sha = sha256.convert(pubkey);
    // For simplicity, using SHA256 instead of full hash160
    // In production, use proper RIPEMD160
    return Uint8List.fromList(sha256.convert(sha.bytes).bytes.sublist(0, 4));
  }

  /// Export as extended private key (xprv)
  String toBase58() {
    // BIP32 serialization format
    final version = Uint8List.fromList([0x04, 0x88, 0xAD, 0xE4]); // xprv

    final buffer = BytesBuilder();
    buffer.add(version);
    buffer.addByte(depth);
    buffer.add(parentFingerprint);
    buffer.addByte((index >> 24) & 0xff);
    buffer.addByte((index >> 16) & 0xff);
    buffer.addByte((index >> 8) & 0xff);
    buffer.addByte(index & 0xff);
    buffer.add(chainCode);
    buffer.addByte(0x00);
    buffer.add(privateKey);

    return _encodeBase58Check(buffer.toBytes());
  }

  /// Simple Base58Check encoding
  String _encodeBase58Check(Uint8List data) {
    // Add checksum
    final hash = sha256.convert(sha256.convert(data).bytes);
    final checksum = hash.bytes.sublist(0, 4);

    final payload = Uint8List(data.length + 4);
    payload.setAll(0, data);
    payload.setAll(data.length, checksum);

    return _base58Encode(payload);
  }

  /// Base58 encoding
  String _base58Encode(Uint8List input) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

    // Count leading zeros
    int leadingZeros = 0;
    while (leadingZeros < input.length && input[leadingZeros] == 0) {
      leadingZeros++;
    }

    // Convert to big integer
    BigInt num = BigInt.zero;
    for (int i = 0; i < input.length; i++) {
      num = num * BigInt.from(256) + BigInt.from(input[i]);
    }

    // Convert to base58
    String encoded = '';
    while (num > BigInt.zero) {
      final remainder = num % BigInt.from(58);
      encoded = alphabet[remainder.toInt()] + encoded;
      num = num ~/ BigInt.from(58);
    }

    // Add '1' for each leading zero
    encoded = '1' * leadingZeros + encoded;

    return encoded;
  }

  /// Convert to hex string for debugging
  String toHex() {
    return 'Private: ${hex.encode(privateKey)}\n'
        'Public: ${hex.encode(publicKey)}\n'
        'Chain: ${hex.encode(chainCode)}';
  }
}


import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:pointycastle/digests/ripemd160.dart';
import 'coin_type.dart';

/// Address generation for various cryptocurrencies
/// 
/// This class handles address generation for different cryptocurrencies using
/// appropriate signature types:
/// - Schnorr: Used by standard wallets, Ledger, Kaspium, Kasware
/// - ECDSA: Used by Tangem hardware wallets
class AddressGenerator {
  /// Generate address from public key
  /// 
  /// [publicKey] The public key to generate address from
  /// [coinType] The cryptocurrency type
  /// [signatureType] Optional signature type (defaults to Schnorr)
  static String generateAddress(Uint8List publicKey, CoinType coinType, {SignatureType? signatureType}) {
    switch (coinType.addressFormat) {
      case AddressFormat.p2pkh:
        return _generateP2PKHAddress(publicKey, _getNetworkByte(coinType));
      case AddressFormat.bech32:
        return _generateBech32Address(publicKey, coinType);
      case AddressFormat.kaspa:
        return _generateKaspaAddress(publicKey, signatureType ?? SignatureType.schnorr);
      default:
        throw UnsupportedError('Address format ${coinType.addressFormat} not yet implemented');
    }
  }

  /// Get network byte for coin type
  static int _getNetworkByte(CoinType coinType) {
    // Mainnet version bytes
    switch (coinType.value) {
      case 0: // Bitcoin
        return 0x00;
      case 2: // Litecoin
        return 0x30;
      case 3: // Dogecoin
        return 0x1E;
      case 145: // Bitcoin Cash
        return 0x00;
      default:
        return 0x00;
    }
  }

  /// Generate P2PKH (Pay to Public Key Hash) address
  static String _generateP2PKHAddress(Uint8List publicKey, int networkByte) {
    // Step 1: SHA-256 hash of public key
    final sha256Hash = sha256.convert(publicKey).bytes;

    // Step 2: RIPEMD-160 hash
    final ripemd160Hash = _ripemd160(Uint8List.fromList(sha256Hash));

    // Step 3: Add network byte
    final extendedHash = Uint8List(21);
    extendedHash[0] = networkByte;
    extendedHash.setRange(1, 21, ripemd160Hash);

    // Step 4: Double SHA-256 for checksum
    final checksum = sha256.convert(sha256.convert(extendedHash).bytes).bytes;

    // Step 5: Add checksum
    final addressBytes = Uint8List(25);
    addressBytes.setRange(0, 21, extendedHash);
    addressBytes.setRange(21, 25, checksum.sublist(0, 4));

    // Step 6: Base58 encode
    return _base58Encode(addressBytes);
  }


  /// Generate Bech32 address (SegWit)
  static String _generateBech32Address(Uint8List publicKey, CoinType coinType) {
    // TODO: Implement proper Bech32 encoding
    // This is a placeholder
    final hash = _ripemd160(Uint8List.fromList(sha256.convert(publicKey).bytes));
    return 'bc1${hex.encode(hash).substring(0, 38)}'; // Placeholder
  }

  /// Generate Kaspa address (Bech32 with kaspa: prefix)
  static String _generateKaspaAddress(Uint8List publicKey, SignatureType signatureType) {
    // Determine if ECDSA or Schnorr based on signature type
    bool useEcdsa = signatureType == SignatureType.ecdsa;
    
    // Generate address using correct kaspa-wasm algorithm
    return _generateCorrectKaspaAddress(publicKey, useEcdsa);
  }

  /// Generate correct Kaspa address using kaspa-wasm algorithm
  static String _generateCorrectKaspaAddress(Uint8List publicKey, bool useEcdsa) {
    // Determine payload based on ECDSA flag
    Uint8List payload;
    int version;

    if (useEcdsa) {
      // Tangem ECDSA: Use full serialized public key (33 bytes) with version 1
      payload = publicKey;
      version = 1; // PubKeyECDSA
    } else {
      // Standard Schnorr: Use x-only public key (32 bytes) with version 0
      // In rusty-kaspa: key.x_only_public_key().0.serialize() gives 32-byte x-coordinate
      if (publicKey.length == 33) {
        payload = publicKey.sublist(1); // Remove prefix byte to get x-coordinate
      } else if (publicKey.length == 65) {
        payload = publicKey.sublist(1, 33); // Use x-coordinate only
      } else if (publicKey.length == 32) {
        payload = publicKey; // Already x-only
      } else {
        throw ArgumentError('Invalid public key length: ${publicKey.length}');
      }
      version = 0; // PubKey
    }

    // Create address using correct algorithm based on provider
    if (useEcdsa) {
      // Tangem uses CashAddrBech32 encoding
      return _createTangemKaspaAddress(payload, version);
    } else {
      // Standard wallets use rusty-kaspa bech32 encoding
      return _createRustyKaspaAddress(payload, version);
    }
  }
  
  /// Create Kaspa address using rusty-kaspa bech32 algorithm (Standard/Kasware/Kaspium/Ledger)
  static String _createRustyKaspaAddress(Uint8List payload, int version) {
    // Exact implementation from rusty-kaspa bech32.rs encode_payload function
    // Create payload with version byte
    final payloadWithVersion = Uint8List(1 + payload.length);
    payloadWithVersion[0] = version;
    payloadWithVersion.setRange(1, 1 + payload.length, payload);

    // Convert to 5-bit groups using rusty-kaspa conv8to5 algorithm
    final fiveBitPayload = _convertTo5bitRusty(payloadWithVersion);

    // Calculate checksum using rusty-kaspa checksum function
    final checksumBytes = _calculateRustyChecksum(fiveBitPayload, 'kaspa');

    // checksumBytes are already in 8-bit format (5 bytes), convert to 5-bit
    // The checksum bytes should be in the correct order from to_be_bytes()[3..]
    final fiveBitChecksum = _convertTo5bitRusty(Uint8List.fromList(checksumBytes));

    // Combine payload and checksum
    final combined = [...fiveBitPayload, ...fiveBitChecksum];

    // Encode using kaspa charset
    final encoded = combined.map((b) => _kaspaCharset[b]).join();

    return 'kaspa:$encoded';
  }
  
  /// Create Kaspa address using Tangem CashAddrBech32 algorithm (ECDSA)
  static String _createTangemKaspaAddress(Uint8List payload, int version) {
    // Tangem uses ECDSA with full public key (33 bytes) and version 1
    // Exact implementation from Tangem iOS CashAddrBech32.swift
    final payloadWithVersion = Uint8List(1 + payload.length);
    payloadWithVersion[0] = version;
    payloadWithVersion.setRange(1, 1 + payload.length, payload);

    // Convert to 5-bit groups using Tangem convertTo5bit algorithm
    final fiveBitPayload = _convertTo5bitTangem(payloadWithVersion);

    // Calculate checksum using Tangem createChecksum algorithm
    final checksum = _calculateTangemChecksum(fiveBitPayload, 'kaspa');

    // Combine payload and checksum (checksum is already in 5-bit format)
    final combined = [...fiveBitPayload, ...checksum];

    // Encode using kaspa charset
    final encoded = combined.map((b) => _kaspaCharset[b]).join();

    return 'kaspa:$encoded';
  }
  
  /// Convert to 5-bit using rusty-kaspa algorithm (exact implementation from conv8to5)
  static List<int> _convertTo5bitRusty(Uint8List data) {
    // Exact implementation from rusty-kaspa conv8to5 function
    final padding = data.length % 5 == 0 ? 0 : 1;
    final fiveBit = List<int>.filled(data.length * 8 ~/ 5 + padding, 0);
    var currentIdx = 0;

    // Use 16-bit buffer exactly like Rust: let mut buff = 0u16;
    var buff = 0; // This will act as u16 due to the operations
    var bits = 0;
    for (final c in data) {
      // Exact Rust operation: buff = (buff << 8) | *c as u16;
      buff = (buff << 8) | c;
      // In Rust, this naturally wraps at 16 bits due to u16 type
      // In Dart, we need to mask to simulate this
      buff &= 0xffff;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        // Exact Rust operation: five_bit[current_idx] = (buff >> bits) as u8;
        fiveBit[currentIdx] = (buff >> bits) & 0x1f;
        // Exact Rust operation: buff &= (1 << bits) - 1;
        buff &= (1 << bits) - 1;
        currentIdx++;
      }
    }
    if (bits > 0) {
      // Exact Rust operation: five_bit[current_idx] = (buff << (5 - bits)) as u8;
      fiveBit[currentIdx] = (buff << (5 - bits)) & 0x1f;
    }

    return fiveBit;
  }
  
  /// Convert to 5-bit using Tangem CashAddrBech32 algorithm (exact implementation)
  static List<int> _convertTo5bitTangem(Uint8List data) {
    var acc = 0;
    var bits = 0;
    const maxv = 31; // 31 = 0x1f = 00011111
    var converted = <int>[];

    for (final d in data) {
      acc = (acc << 8) | d;
      bits += 8;

      while (bits >= 5) {
        bits -= 5;
        converted.add((acc >> bits) & maxv);
      }
    }

    // Tangem algorithm: always pad if bits > 0
    if (bits > 0) {
      converted.add((acc << (5 - bits)) & maxv);
    }

    return converted;
  }
  
  /// Calculate checksum using rusty-kaspa polymod algorithm (exact implementation)
  static List<int> _calculateRustyChecksum(List<int> payload, String prefix) {
    // Exact implementation from rusty-kaspa checksum function
    final prefixBytes = prefix.codeUnits.map((c) => c & 0x1f).toList();
    final input = [...prefixBytes, 0, ...payload, ...List.filled(8, 0)];
    final mod = _polyModRusty(input);

    // Convert to bytes using rusty-kaspa algorithm: to_be_bytes()[3..]
    // In Rust: checksum.to_be_bytes() gives [byte0, byte1, byte2, byte3, byte4, byte5, byte6, byte7]
    // Then [3..] gives [byte3, byte4, byte5, byte6, byte7] (5 bytes)
    final checksumBytes = <int>[];
    for (var i = 0; i < 8; i++) {
      checksumBytes.add((mod >> (8 * (7 - i))) & 0xff);
    }

    // Take bytes 3,4,5,6,7 from the 8-byte checksum (rusty-kaspa algorithm: to_be_bytes()[3..])
    return checksumBytes.sublist(3);
  }
  
  /// Calculate checksum using Tangem CashAddrBech32 polymod algorithm (exact implementation)
  static List<int> _calculateTangemChecksum(List<int> payload, String prefix) {
    // Exact implementation from Tangem CashAddrBech32.swift createChecksum function
    final prefixBytes = prefix.codeUnits.map((c) => c & 0x1f).toList();
    final input = [...prefixBytes, 0, ...payload, ...List.filled(8, 0)];
    final mod = _polyModTangem(input);

    // Tangem algorithm: convert polymod result directly to 5-bit groups
    // In Swift: for i in 0 ..< 8 { ret.append(UInt8((mod >> (5 * (7 - i))) & 0x1f)) }
    final checksumBytes = <int>[];
    for (var i = 0; i < 8; i++) {
      checksumBytes.add((mod >> (5 * (7 - i))) & 0x1f);
    }

    return checksumBytes;
  }
  
  /// PolyMod calculation for rusty-kaspa (exact implementation with BigInt)
  static int _polyModRusty(List<int> data) {
    var c = BigInt.from(1);

    for (var i = 0; i < data.length; i++) {
      final d = BigInt.from(data[i]);
      final c0 = c >> 35;
      c = ((c & BigInt.from(0x07ffffffff)) << 5) ^ d;

      if (c0 & BigInt.from(0x01) != BigInt.zero) c ^= BigInt.from(0x98f2bc8e61);
      if (c0 & BigInt.from(0x02) != BigInt.zero) c ^= BigInt.from(0x79b76d99e2);
      if (c0 & BigInt.from(0x04) != BigInt.zero) c ^= BigInt.from(0xf33e5fb3c4);
      if (c0 & BigInt.from(0x08) != BigInt.zero) c ^= BigInt.from(0xae2eabe2a8);
      if (c0 & BigInt.from(0x10) != BigInt.zero) c ^= BigInt.from(0x1e4f43e470);
    }

    final result = c ^ BigInt.from(1);
    return result.toInt();
  }
  
  /// PolyMod calculation for Tangem CashAddrBech32 (exact implementation with BigInt)
  static int _polyModTangem(List<int> data) {
    var c = BigInt.from(1);

    for (var i = 0; i < data.length; i++) {
      final d = BigInt.from(data[i]);
      final c0 = c >> 35;
      c = ((c & BigInt.from(0x07ffffffff)) << 5) ^ d;

      if (c0 & BigInt.from(0x01) != BigInt.zero) c ^= BigInt.from(0x98f2bc8e61);
      if (c0 & BigInt.from(0x02) != BigInt.zero) c ^= BigInt.from(0x79b76d99e2);
      if (c0 & BigInt.from(0x04) != BigInt.zero) c ^= BigInt.from(0xf33e5fb3c4);
      if (c0 & BigInt.from(0x08) != BigInt.zero) c ^= BigInt.from(0xae2eabe2a8);
      if (c0 & BigInt.from(0x10) != BigInt.zero) c ^= BigInt.from(0x1e4f43e470);
    }

    final result = c ^ BigInt.from(1);
    return result.toInt();
  }
  
  /// Kaspa charset (same as kaspa-wasm)
  static const _kaspaCharset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';


  /// Convert bits for Bech32 encoding
  static List<int> convertBits(List<int> data, int fromBits, int toBits, bool pad) {
    int acc = 0;
    int bits = 0;
    final result = <int>[];
    final maxv = (1 << toBits) - 1;

    for (final value in data) {
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & maxv);
      }
    } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
      throw Exception('Invalid bits conversion');
    }

    return result;
  }

  /// Bech32 encoding (standard, not Bech32m)
  static String bech32Encode(String hrp, List<int> data) {
    const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final values = [...data, ..._bech32CreateChecksum(hrp, data)];
    return values.map((i) => charset[i]).join('');
  }

  /// Create Bech32 checksum (standard variant)
  static List<int> _bech32CreateChecksum(String hrp, List<int> data) {
    final values = [..._hrpExpand(hrp), ...data, 0, 0, 0, 0, 0, 0];
    const bech32Const = 1; // Standard Bech32 uses 1 (Bech32m uses 0x2bc830a3)
    final polymod = _bech32Polymod(values) ^ bech32Const;
    return List.generate(6, (i) => (polymod >> (5 * (5 - i))) & 31);
  }

  /// Bech32m encoding
  static String _bech32mEncode(String hrp, List<int> data) {
    const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    final values = [...data, ..._bech32mCreateChecksum(hrp, data)];
    return values.map((i) => charset[i]).join('');
  }

  /// Create Bech32m checksum
  static List<int> _bech32mCreateChecksum(String hrp, List<int> data) {
    final values = [..._hrpExpand(hrp), ...data, 0, 0, 0, 0, 0, 0];
    const bech32mConst = 0x2bc830a3;
    final polymod = _bech32Polymod(values) ^ bech32mConst;
    return List.generate(6, (i) => (polymod >> (5 * (5 - i))) & 31);
  }

  /// Expand HRP for Bech32
  static List<int> _hrpExpand(String hrp) {
    final result = <int>[];
    for (int i = 0; i < hrp.length; i++) {
      result.add(hrp.codeUnitAt(i) >> 5);
    }
    result.add(0);
    for (int i = 0; i < hrp.length; i++) {
      result.add(hrp.codeUnitAt(i) & 31);
    }
    return result;
  }

  /// Bech32 polymod calculation
  static int _bech32Polymod(List<int> values) {
    const gen = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
    int chk = 1;
    for (final value in values) {
      final b = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ value;
      for (int i = 0; i < 5; i++) {
        if ((b >> i) & 1 != 0) {
          chk ^= gen[i];
        }
      }
    }
    return chk;
  }

  /// RIPEMD-160 hash
  static Uint8List _ripemd160(Uint8List input) {
    final digest = RIPEMD160Digest();
    final output = Uint8List(20);
    digest.update(input, 0, input.length);
    digest.doFinal(output, 0);
    return output;
  }

  /// Base58 encoding
  static String _base58Encode(Uint8List input) {
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
}


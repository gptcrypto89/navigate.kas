import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'secp256k1_bindings.dart';

// nullptr constant
final Pointer<Void> nullptr = Pointer<Void>.fromAddress(0);

/// High-level interface for secp256k1 cryptographic operations
class Secp256k1 {
  final Secp256k1Bindings _bindings;
  late final Pointer<Void> _context;

  Secp256k1({String? libraryPath}) : _bindings = Secp256k1Bindings(libraryPath: libraryPath) {
    _context = _bindings.contextCreate(
      Secp256k1Bindings.secp256k1ContextSign |
          Secp256k1Bindings.secp256k1ContextVerify,
    );
  }

  /// Clean up resources
  void dispose() {
    _bindings.contextDestroy(_context);
  }

  /// Generate public key from private key
  /// 
  /// [privateKey] must be exactly 32 bytes
  /// [compressed] determines if the public key should be compressed (33 bytes) or uncompressed (65 bytes)
  /// 
  /// Returns the public key or null if generation failed
  Uint8List? generatePublicKey(Uint8List privateKey, {bool compressed = true}) {
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be exactly 32 bytes, got ${privateKey.length}');
    }

    // Allocate memory for private key
    final privKeyPtr = calloc<Uint8>(32);
    for (int i = 0; i < 32; i++) {
      privKeyPtr[i] = privateKey[i];
    }

    // Allocate memory for public key (64 bytes internal representation)
    final pubKeyPtr = calloc<Uint8>(64);

    try {
      // Generate public key
      final result = _bindings.ecPubkeyCreate(_context, pubKeyPtr, privKeyPtr);

      if (result != 1) {
        return null;
      }

      // Serialize public key
      final outputLen = calloc<Size>();
      outputLen.value = compressed ? 33 : 65;
      final outputPtr = calloc<Uint8>(outputLen.value);

      try {
        final serializeResult = _bindings.ecPubkeySerialize(
          _context,
          outputPtr,
          outputLen,
          pubKeyPtr,
          compressed
              ? Secp256k1Bindings.secp256k1EcCompressed
              : Secp256k1Bindings.secp256k1EcUncompressed,
        );

        if (serializeResult != 1) {
          return null;
        }

        // Copy result to Dart
        final publicKey = Uint8List(outputLen.value);
        for (int i = 0; i < outputLen.value; i++) {
          publicKey[i] = outputPtr[i];
        }

        return publicKey;
      } finally {
        calloc.free(outputPtr);
        calloc.free(outputLen);
      }
    } finally {
      calloc.free(privKeyPtr);
      calloc.free(pubKeyPtr);
    }
  }

  /// Verify that a private key is valid
  /// 
  /// Returns true if the private key can generate a valid public key
  bool verifyPrivateKey(Uint8List privateKey) {
    if (privateKey.length != 32) {
      return false;
    }
    return generatePublicKey(privateKey) != null;
  }

  /// Sign a message with a private key
  /// 
  /// [message] must be exactly 32 bytes (should be SHA256 hash of actual message)
  /// [privateKey] must be exactly 32 bytes
  /// 
  /// Returns 64-byte signature in compact format (r, s) or null if signing failed
  Uint8List? sign(Uint8List message, Uint8List privateKey) {
    if (message.length != 32) {
      throw ArgumentError('Message must be exactly 32 bytes (should be SHA256 hash)');
    }
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be exactly 32 bytes');
    }

    // Allocate memory
    final sigPtr = calloc<Uint8>(64); // Internal format
    final msgPtr = calloc<Uint8>(32);
    final seckeyPtr = calloc<Uint8>(32);

    try {
      // Copy data
      for (int i = 0; i < 32; i++) {
        msgPtr[i] = message[i];
        seckeyPtr[i] = privateKey[i];
      }

      // Sign (creates internal format signature)
      final result = _bindings.ecdsaSign(
        _context,
        sigPtr,
        msgPtr,
        seckeyPtr,
        nullptr, // noncefp
        nullptr, // ndata
      );

      if (result != 1) {
        return null;
      }

      // Serialize to compact format (64 bytes: r[32] + s[32])
      final outputPtr = calloc<Uint8>(64);
      try {
        final serializeResult = _bindings.ecdsaSignatureSerializeCompact(
          _context,
          outputPtr,
          sigPtr,
        );

        if (serializeResult != 1) {
          return null;
        }

        // Copy result
        final signature = Uint8List(64);
        for (int i = 0; i < 64; i++) {
          signature[i] = outputPtr[i];
        }

        return signature;
      } finally {
        calloc.free(outputPtr);
      }
    } finally {
      calloc.free(sigPtr);
      calloc.free(msgPtr);
      calloc.free(seckeyPtr);
    }
  }

  /// Verify a signature
  /// 
  /// [signature] must be exactly 64 bytes in compact format (r, s)
  /// [message] must be exactly 32 bytes (should be SHA256 hash of actual message)
  /// [publicKey] must be 33 bytes (compressed) or 65 bytes (uncompressed)
  /// 
  /// Returns true if signature is valid, false otherwise
  bool verify(Uint8List signature, Uint8List message, Uint8List publicKey) {
    if (signature.length != 64) {
      throw ArgumentError('Signature must be exactly 64 bytes');
    }
    if (message.length != 32) {
      throw ArgumentError('Message must be exactly 32 bytes (should be SHA256 hash)');
    }
    if (publicKey.length != 33 && publicKey.length != 65) {
      throw ArgumentError('Public key must be 33 bytes (compressed) or 65 bytes (uncompressed)');
    }

    // Allocate memory
    final pubkeyInternalPtr = calloc<Uint8>(64); // Internal format
    final pubkeyPtr = calloc<Uint8>(publicKey.length);
    final sigInternalPtr = calloc<Uint8>(64); // Internal format
    final sigPtr = calloc<Uint8>(64); // Compact format
    final msgPtr = calloc<Uint8>(32);

    try {
      // Copy data
      for (int i = 0; i < publicKey.length; i++) {
        pubkeyPtr[i] = publicKey[i];
      }
      for (int i = 0; i < 64; i++) {
        sigPtr[i] = signature[i];
      }
      for (int i = 0; i < 32; i++) {
        msgPtr[i] = message[i];
      }

      // Parse public key
      final parseResult = _bindings.ecPubkeyParse(
        _context,
        pubkeyInternalPtr,
        pubkeyPtr,
        publicKey.length,
      );

      if (parseResult != 1) {
        return false;
      }

      // Parse signature from compact format
      final sigParseResult = _bindings.ecdsaSignatureParseCompact(
        _context,
        sigInternalPtr,
        sigPtr,
      );

      if (sigParseResult != 1) {
        return false;
      }

      // Verify signature
      final verifyResult = _bindings.ecdsaVerify(
        _context,
        sigInternalPtr,
        msgPtr,
        pubkeyInternalPtr,
      );

      return verifyResult == 1;
    } finally {
      calloc.free(pubkeyInternalPtr);
      calloc.free(pubkeyPtr);
      calloc.free(sigInternalPtr);
      calloc.free(sigPtr);
      calloc.free(msgPtr);
    }
  }
}


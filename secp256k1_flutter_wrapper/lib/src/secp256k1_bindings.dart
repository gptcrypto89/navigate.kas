import 'dart:ffi';
import 'dart:io';

// Type definitions for secp256k1 C library
typedef Secp256k1ContextCreateNative = Pointer<Void> Function(Uint32 flags);
typedef Secp256k1ContextCreate = Pointer<Void> Function(int flags);

typedef Secp256k1ContextDestroyNative = Void Function(Pointer<Void> ctx);
typedef Secp256k1ContextDestroy = void Function(Pointer<Void> ctx);

typedef Secp256k1EcPubkeyCreateNative = Int32 Function(
  Pointer<Void> ctx,
  Pointer<Uint8> pubkey,
  Pointer<Uint8> seckey,
);
typedef Secp256k1EcPubkeyCreate = int Function(
  Pointer<Void> ctx,
  Pointer<Uint8> pubkey,
  Pointer<Uint8> seckey,
);

typedef Secp256k1EcPubkeySerializeNative = Int32 Function(
  Pointer<Void> ctx,
  Pointer<Uint8> output,
  Pointer<Size> outputlen,
  Pointer<Uint8> pubkey,
  Uint32 flags,
);
typedef Secp256k1EcPubkeySerialize = int Function(
  Pointer<Void> ctx,
  Pointer<Uint8> output,
  Pointer<Size> outputlen,
  Pointer<Uint8> pubkey,
  int flags,
);

typedef Secp256k1EcdsaSignNative = Int32 Function(
  Pointer<Void> ctx,
  Pointer<Uint8> sig,
  Pointer<Uint8> msg32,
  Pointer<Uint8> seckey,
  Pointer<Void> noncefp,
  Pointer<Void> ndata,
);
typedef Secp256k1EcdsaSign = int Function(
  Pointer<Void> ctx,
  Pointer<Uint8> sig,
  Pointer<Uint8> msg32,
  Pointer<Uint8> seckey,
  Pointer<Void> noncefp,
  Pointer<Void> ndata,
);

typedef Secp256k1EcdsaVerifyNative = Int32 Function(
  Pointer<Void> ctx,
  Pointer<Uint8> sig,
  Pointer<Uint8> msg32,
  Pointer<Uint8> pubkey,
);
typedef Secp256k1EcdsaVerify = int Function(
  Pointer<Void> ctx,
  Pointer<Uint8> sig,
  Pointer<Uint8> msg32,
  Pointer<Uint8> pubkey,
);

typedef Secp256k1EcPubkeyParseNative = Int32 Function(
  Pointer<Void> ctx,
  Pointer<Uint8> pubkey,
  Pointer<Uint8> input,
  Size inputlen,
);
typedef Secp256k1EcPubkeyParse = int Function(
  Pointer<Void> ctx,
  Pointer<Uint8> pubkey,
  Pointer<Uint8> input,
  int inputlen,
);

typedef Secp256k1EcdsaSignatureParseCompactNative = Int32 Function(
  Pointer<Void> ctx,
  Pointer<Uint8> sig,
  Pointer<Uint8> input64,
);
typedef Secp256k1EcdsaSignatureParseCompact = int Function(
  Pointer<Void> ctx,
  Pointer<Uint8> sig,
  Pointer<Uint8> input64,
);

typedef Secp256k1EcdsaSignatureSerializeCompactNative = Int32 Function(
  Pointer<Void> ctx,
  Pointer<Uint8> output64,
  Pointer<Uint8> sig,
);
typedef Secp256k1EcdsaSignatureSerializeCompact = int Function(
  Pointer<Void> ctx,
  Pointer<Uint8> output64,
  Pointer<Uint8> sig,
);

/// FFI bindings for secp256k1 library
class Secp256k1Bindings {
  late final DynamicLibrary _lib;
  late final Secp256k1ContextCreate contextCreate;
  late final Secp256k1ContextDestroy contextDestroy;
  late final Secp256k1EcPubkeyCreate ecPubkeyCreate;
  late final Secp256k1EcPubkeySerialize ecPubkeySerialize;
  late final Secp256k1EcPubkeyParse ecPubkeyParse;
  late final Secp256k1EcdsaSign ecdsaSign;
  late final Secp256k1EcdsaVerify ecdsaVerify;
  late final Secp256k1EcdsaSignatureParseCompact ecdsaSignatureParseCompact;
  late final Secp256k1EcdsaSignatureSerializeCompact ecdsaSignatureSerializeCompact;

  // secp256k1 constants
  static const int secp256k1ContextSign = 0x0101;
  static const int secp256k1ContextVerify = 0x0201;
  static const int secp256k1EcCompressed = 0x0102;
  static const int secp256k1EcUncompressed = 0x0002;

  Secp256k1Bindings({String? libraryPath}) {
    _lib = _loadLibrary(libraryPath);
    _bindFunctions();
  }

  DynamicLibrary _loadLibrary(String? customPath) {
    if (customPath != null) {
      return DynamicLibrary.open(customPath);
    }

    // Find secp256k1/build directory by walking up from current directory
    String? findSecp256k1BuildDir(String platform, String libName) {
      var searchDir = Directory.current;
      for (int i = 0; i < 10; i++) {
        final buildPath = '${searchDir.path}/secp256k1/build/$platform/lib/$libName';
        if (File(buildPath).existsSync()) {
          return buildPath;
        }
        final parent = searchDir.parent;
        if (parent.path == searchDir.path) break; // Reached root
        searchDir = parent;
      }
      return null;
    }

    if (Platform.isMacOS) {
      // 1. Try app bundle Frameworks (production)
      try {
        return DynamicLibrary.open('@executable_path/../Frameworks/libsecp256k1.dylib');
      } catch (e) {
        // Continue to next option
      }

      // 2. Try secp256k1/build/macos/lib
      final buildPath = findSecp256k1BuildDir('macos', 'libsecp256k1.dylib');
      if (buildPath != null) {
        try {
          return DynamicLibrary.open(buildPath);
        } catch (e) {
          // Continue to next option
        }
      }

      // 3. Try system paths
      for (final path in ['/opt/homebrew/lib/libsecp256k1.dylib', '/usr/local/lib/libsecp256k1.dylib']) {
        if (File(path).existsSync()) {
          try {
            return DynamicLibrary.open(path);
          } catch (e) {
            continue;
          }
        }
      }

      throw UnsupportedError('Could not load libsecp256k1.dylib for macOS');
    } else if (Platform.isIOS) {
      return DynamicLibrary.open('libsecp256k1.dylib');
    } else if (Platform.isAndroid) {
      return DynamicLibrary.open('libsecp256k1.so');
    } else if (Platform.isLinux) {
      // 1. Try secp256k1/build/linux/lib
      final buildPath = findSecp256k1BuildDir('linux', 'libsecp256k1.so');
      if (buildPath != null) {
        try {
          return DynamicLibrary.open(buildPath);
        } catch (e) {
          // Continue to next option
        }
      }

      // 2. Try system paths
      for (final path in ['/usr/local/lib/libsecp256k1.so', '/usr/lib/libsecp256k1.so']) {
        if (File(path).existsSync()) {
          try {
            return DynamicLibrary.open(path);
          } catch (e) {
            continue;
          }
        }
      }

      // 3. Try current directory
      try {
        return DynamicLibrary.open('libsecp256k1.so');
      } catch (e) {
        throw UnsupportedError('Could not load libsecp256k1.so for Linux');
      }
    } else if (Platform.isWindows) {
      for (final path in ['secp256k1.dll', 'libsecp256k1.dll', './secp256k1.dll', './libsecp256k1.dll']) {
        try {
          return DynamicLibrary.open(path);
        } catch (e) {
          continue;
        }
      }
      throw UnsupportedError('Could not load secp256k1.dll for Windows');
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }
  }

  void _bindFunctions() {
    contextCreate = _lib
        .lookup<NativeFunction<Secp256k1ContextCreateNative>>(
            'secp256k1_context_create')
        .asFunction();

    contextDestroy = _lib
        .lookup<NativeFunction<Secp256k1ContextDestroyNative>>(
            'secp256k1_context_destroy')
        .asFunction();

    ecPubkeyCreate = _lib
        .lookup<NativeFunction<Secp256k1EcPubkeyCreateNative>>(
            'secp256k1_ec_pubkey_create')
        .asFunction();

    ecPubkeySerialize = _lib
        .lookup<NativeFunction<Secp256k1EcPubkeySerializeNative>>(
            'secp256k1_ec_pubkey_serialize')
        .asFunction();

    ecPubkeyParse = _lib
        .lookup<NativeFunction<Secp256k1EcPubkeyParseNative>>(
            'secp256k1_ec_pubkey_parse')
        .asFunction();

    ecdsaSign = _lib
        .lookup<NativeFunction<Secp256k1EcdsaSignNative>>(
            'secp256k1_ecdsa_sign')
        .asFunction();

    ecdsaVerify = _lib
        .lookup<NativeFunction<Secp256k1EcdsaVerifyNative>>(
            'secp256k1_ecdsa_verify')
        .asFunction();

    ecdsaSignatureParseCompact = _lib
        .lookup<NativeFunction<Secp256k1EcdsaSignatureParseCompactNative>>(
            'secp256k1_ecdsa_signature_parse_compact')
        .asFunction();

    ecdsaSignatureSerializeCompact = _lib
        .lookup<NativeFunction<Secp256k1EcdsaSignatureSerializeCompactNative>>(
            'secp256k1_ecdsa_signature_serialize_compact')
        .asFunction();
  }
}


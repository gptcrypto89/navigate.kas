/// BIP44 derivation path utilities
class DerivationPath {
  /// Build BIP44 path: m/44'/coin_type'/account'/change/address_index
  static String bip44(int coinType, {int account = 0, int change = 0, int addressIndex = 0}) {
    return "m/44'/$coinType'/$account'/$change/$addressIndex";
  }

  /// Build BIP49 path (P2WPKH-nested-in-P2SH): m/49'/coin_type'/account'/change/address_index
  static String bip49(int coinType, {int account = 0, int change = 0, int addressIndex = 0}) {
    return "m/49'/$coinType'/$account'/$change/$addressIndex";
  }

  /// Build BIP84 path (P2WPKH native SegWit): m/84'/coin_type'/account'/change/address_index
  static String bip84(int coinType, {int account = 0, int change = 0, int addressIndex = 0}) {
    return "m/84'/$coinType'/$account'/$change/$addressIndex";
  }

  /// Custom derivation path
  static String custom(String path) {
    if (!path.startsWith('m/') && !path.startsWith('M/')) {
      throw ArgumentError('Path must start with m/ or M/');
    }
    return path;
  }

  /// Validate derivation path format
  static bool isValid(String path) {
    if (!path.startsWith('m/') && !path.startsWith('M/')) {
      return false;
    }

    final segments = path.substring(2).split('/');
    for (final segment in segments) {
      if (segment.isEmpty) return false;

      final hardened = segment.endsWith("'") || segment.endsWith('h');
      final indexStr = hardened ? segment.substring(0, segment.length - 1) : segment;

      if (int.tryParse(indexStr) == null) {
        return false;
      }
    }

    return true;
  }

  /// Parse path and extract components
  static PathComponents parse(String path) {
    if (!isValid(path)) {
      throw ArgumentError('Invalid derivation path: $path');
    }

    final segments = path.substring(2).split('/');
    final indices = <int>[];
    final hardened = <bool>[];

    for (final segment in segments) {
      final isHardened = segment.endsWith("'") || segment.endsWith('h');
      final indexStr = isHardened ? segment.substring(0, segment.length - 1) : segment;
      final index = int.parse(indexStr);

      indices.add(index);
      hardened.add(isHardened);
    }

    return PathComponents(indices, hardened);
  }
}

/// Components of a derivation path
class PathComponents {
  final List<int> indices;
  final List<bool> hardened;

  PathComponents(this.indices, this.hardened);

  /// Get purpose (first index) if exists
  int? get purpose => indices.isNotEmpty ? indices[0] : null;

  /// Get coin type (second index) if exists
  int? get coinType => indices.length > 1 ? indices[1] : null;

  /// Get account (third index) if exists
  int? get account => indices.length > 2 ? indices[2] : null;

  /// Get change (fourth index) if exists
  int? get change => indices.length > 3 ? indices[3] : null;

  /// Get address index (fifth index) if exists
  int? get addressIndex => indices.length > 4 ? indices[4] : null;
}


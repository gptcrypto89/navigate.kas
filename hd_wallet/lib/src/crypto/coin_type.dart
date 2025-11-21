/// BIP44 coin type constants
/// https://github.com/satoshilabs/slips/blob/master/slip-0044.md
class CoinType {
  final int value;
  final String symbol;
  final String name;
  final AddressFormat addressFormat;

  const CoinType._({
    required this.value,
    required this.symbol,
    required this.name,
    required this.addressFormat,
  });

  // Major cryptocurrencies
  static const bitcoin = CoinType._(value: 0, symbol: 'BTC', name: 'Bitcoin', addressFormat: AddressFormat.p2pkh);
  static const litecoin = CoinType._(value: 2, symbol: 'LTC', name: 'Litecoin', addressFormat: AddressFormat.p2pkh);
  static const dogecoin = CoinType._(value: 3, symbol: 'DOGE', name: 'Dogecoin', addressFormat: AddressFormat.p2pkh);
  static const bitcoinCash = CoinType._(value: 145, symbol: 'BCH', name: 'Bitcoin Cash', addressFormat: AddressFormat.p2pkh);
  static const kaspa = CoinType._(value: 111111, symbol: 'KAS', name: 'Kaspa', addressFormat: AddressFormat.kaspa);

  /// Get all supported coins
  static const List<CoinType> all = [
    bitcoin,
    litecoin,
    dogecoin,
    bitcoinCash,
    kaspa,
  ];

  /// Get coin by symbol
  static CoinType? fromSymbol(String symbol) {
    for (final coin in all) {
      if (coin.symbol.toUpperCase() == symbol.toUpperCase()) {
        return coin;
      }
    }
    return null;
  }

  /// Get coin by value
  static CoinType? fromValue(int value) {
    for (final coin in all) {
      if (coin.value == value) {
        return coin;
      }
    }
    return null;
  }

  /// Create custom coin type
  factory CoinType.custom({
    required int value,
    required String symbol,
    required String name,
    AddressFormat addressFormat = AddressFormat.p2pkh,
  }) {
    return CoinType._(
      value: value,
      symbol: symbol,
      name: name,
      addressFormat: addressFormat,
    );
  }

  @override
  String toString() => '$name ($symbol)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoinType && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Address format types
enum AddressFormat {
  p2pkh, // Pay to Public Key Hash (Legacy)
  p2sh, // Pay to Script Hash
  p2wpkh, // Pay to Witness Public Key Hash (SegWit)
  bech32, // Bech32 encoding (native SegWit)
  kaspa, // Kaspa Bech32m encoding with kaspa: prefix
}

/// Signature types for cryptographic operations
/// 
/// Signature types determine the cryptographic algorithm used for signing:
/// - schnorr: Used by standard wallets, Ledger, Kaspium, Kasware
/// - ecdsa: Used by Tangem hardware wallets
enum SignatureType {
  schnorr, // Standard signature type used by most wallets
  ecdsa,   // ECDSA signature type used by Tangem hardware wallets
}


import 'dart:convert';
import 'package:http/http.dart' as http;
import '../common/config.dart';

/// Client for interacting with the Kasplex KRC20 API
class KasplexApiClient {
  final String _baseUrl = AppConfig.kasplexApiUrl;
  final String _kaspaComUrl = AppConfig.kaspaComApiUrl;
  final Duration _timeout = Duration(seconds: AppConfig.kasplexApiTimeoutSeconds);

  /// Get KRC20 token list for an address
  /// API: GET /krc20/address/{address}/tokenlist
  Future<KRC20TokenListResult> getTokenList(String address, {String? next}) async {
    try {
      var url = '$_baseUrl/krc20/address/$address/tokenlist';
      if (next != null && next.isNotEmpty) {
        url += '?next=$next';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] == 'successful') {
          final List<dynamic> results = data['result'] ?? [];
          final tokens = results.map((t) => KRC20Token.fromJson(t)).toList();
          return KRC20TokenListResult(
            tokens: tokens,
            prev: data['prev'] as String?,
            next: data['next'] as String?,
          );
        }
      }
      return KRC20TokenListResult(tokens: [], prev: null, next: null);
    } catch (e) {
      print('❌ KasplexApiClient: Error fetching token list: $e');
      return KRC20TokenListResult(tokens: [], prev: null, next: null);
    }
  }

  /// Get portfolio info (prices and logos) for multiple tokens
  /// API: GET /krc20/portfolio?tickers=TICKER1,TICKER2
  Future<List<KRC20TokenInfo>> getPortfolio(List<String> tickers) async {
    if (tickers.isEmpty) return [];
    
    try {
      final tickersParam = tickers.join(',');
      final url = '$_kaspaComUrl/krc20/portfolio?tickers=$tickersParam';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((t) => KRC20TokenInfo.fromJson(t)).toList();
      }
      return [];
    } catch (e) {
      print('❌ KasplexApiClient: Error fetching portfolio: $e');
      return [];
    }
  }
}

/// Result of token list query
class KRC20TokenListResult {
  final List<KRC20Token> tokens;
  final String? prev;
  final String? next;

  KRC20TokenListResult({
    required this.tokens,
    this.prev,
    this.next,
  });

  bool get hasMore => next != null && next!.isNotEmpty;
}

/// Represents a KRC20 token balance
class KRC20Token {
  final String tick;
  final String balance;
  final String locked;
  final int decimals;
  final String opScoreMod;

  KRC20Token({
    required this.tick,
    required this.balance,
    required this.locked,
    required this.decimals,
    required this.opScoreMod,
  });

  factory KRC20Token.fromJson(Map<String, dynamic> json) {
    return KRC20Token(
      tick: json['tick'] as String? ?? '',
      balance: json['balance'] as String? ?? '0',
      locked: json['locked'] as String? ?? '0',
      decimals: int.tryParse(json['dec']?.toString() ?? '8') ?? 8,
      opScoreMod: json['opScoreMod'] as String? ?? '',
    );
  }

  /// Get balance as a formatted double
  double get balanceFormatted {
    final raw = BigInt.tryParse(balance) ?? BigInt.zero;
    return raw / BigInt.from(10).pow(decimals);
  }

  /// Get locked amount as a formatted double
  double get lockedFormatted {
    final raw = BigInt.tryParse(locked) ?? BigInt.zero;
    return raw / BigInt.from(10).pow(decimals);
  }
}

/// Extended token info with price and logo
class KRC20TokenInfo {
  final String ticker;
  final String state;
  final String? logo;
  final double? price;

  KRC20TokenInfo({
    required this.ticker,
    required this.state,
    this.logo,
    this.price,
  });

  factory KRC20TokenInfo.fromJson(Map<String, dynamic> json) {
    return KRC20TokenInfo(
      ticker: json['ticker'] as String? ?? '',
      state: json['state'] as String? ?? '',
      logo: json['logo'] as String?,
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}

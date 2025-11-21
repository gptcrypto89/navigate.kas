import 'dart:convert';
import 'package:http/http.dart' as http;
import '../common/config.dart';

/// Client for interacting with the KNS Domains API
class KNSApiClient {
  final String baseUrl;

  KNSApiClient({this.baseUrl = AppConfig.knsApiUrl});

  /// Check if a domain exists and is verified in KNS
  Future<KNSDomainResult> checkDomainExists(String domain) async {
    try {
      print('KNS API: Checking domain: $domain');
      
      final url = Uri.parse('$baseUrl/assets').replace(queryParameters: {
        'page': '1',
        'pageSize': '20',
        'asset': domain,
        'sortOrder': 'DESC',
      });

      final response = await http.get(url).timeout(
        const Duration(seconds: AppConfig.knsApiTimeoutSeconds),
      );

      print('KNS API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true && data.containsKey('data')) {
          final dataMap = data['data'] as Map<String, dynamic>;
          final assets = dataMap['assets'] as List<dynamic>? ?? [];
          
          // Look for exact match that is a verified domain
          for (var assetData in assets) {
            final asset = assetData as Map<String, dynamic>;
            final assetName = asset['asset'] as String?;
            final isDomain = asset['isDomain'] as bool? ?? false;
            final isVerified = asset['isVerifiedDomain'] as bool? ?? false;
            
            if (assetName == domain && isDomain && isVerified) {
              return KNSDomainResult(
                found: true,
                domain: KNSDomain.fromMap(asset),
              );
            }
          }
        }
        
        // Domain not found or not verified
        return KNSDomainResult(found: false);
      } else {
        throw Exception('HTTP Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('KNS API Error: $e');
      if (e.toString().contains('Connection') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Cannot connect to KNS API. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Get all verified domains owned by a specific wallet address with pagination
  Future<KNSDomainsResult> getDomainsByOwner(
    String ownerAddress, {
    int page = 1,
    int pageSize = AppConfig.knsDefaultPageSize,
  }) async {
    try {
      print('KNS API: Getting domains for owner: $ownerAddress (page: $page, pageSize: $pageSize)');
      
      final url = Uri.parse('$baseUrl/assets').replace(queryParameters: {
        'owner': ownerAddress,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        'sortOrder': 'DESC',
      });

      final response = await http.get(url).timeout(
        const Duration(seconds: AppConfig.knsApiTimeoutSeconds),
      );

      print('KNS API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true && data.containsKey('data')) {
          final dataMap = data['data'] as Map<String, dynamic>;
          final assets = dataMap['assets'] as List<dynamic>? ?? [];
          final pagination = dataMap['pagination'] as Map<String, dynamic>? ?? {};
          
          // Filter to only verified domains
          final domains = assets
              .map((asset) => asset as Map<String, dynamic>)
              .where((asset) {
                final isDomain = asset['isDomain'] as bool? ?? false;
                final isVerified = asset['isVerifiedDomain'] as bool? ?? false;
                return isDomain && isVerified;
              })
              .map((asset) => KNSDomain.fromMap(asset))
              .toList();
          
          print('KNS API: Found ${domains.length} verified domains');
          
          return KNSDomainsResult(
            domains: domains,
            currentPage: pagination['currentPage'] as int? ?? page,
            pageSize: pagination['pageSize'] as int? ?? pageSize,
            totalItems: pagination['totalItems'] as int? ?? 0,
            totalPages: pagination['totalPages'] as int? ?? 0,
          );
        }
        
        return KNSDomainsResult(
          domains: [],
          currentPage: page,
          pageSize: pageSize,
          totalItems: 0,
          totalPages: 0,
        );
      } else {
        throw Exception('HTTP Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('KNS API Error: $e');
      if (e.toString().contains('Connection') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Cannot connect to KNS API. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Get all assets owned by a specific wallet address (including non-domain assets)
  Future<List<KNSDomain>> getAllAssetsByOwner(String ownerAddress) async {
    try {
      print('KNS API: Getting all assets for owner: $ownerAddress');
      
      final url = Uri.parse('$baseUrl/assets').replace(queryParameters: {
        'owner': ownerAddress,
        'page': '1',
        'pageSize': '100',
        'sortOrder': 'DESC',
      });

      final response = await http.get(url).timeout(
        const Duration(seconds: AppConfig.knsApiTimeoutSeconds),
      );

      print('KNS API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true && data.containsKey('data')) {
          final dataMap = data['data'] as Map<String, dynamic>;
          final assets = dataMap['assets'] as List<dynamic>? ?? [];
          
          // Return all assets mapped to KNSDomain objects
          final allAssets = assets
              .map((asset) => asset as Map<String, dynamic>)
              .map((asset) => KNSDomain.fromMap(asset))
              .toList();
          
          print('KNS API: Found ${allAssets.length} total assets');
          return allAssets;
        }
        
        return [];
      } else {
        throw Exception('HTTP Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('KNS API Error: $e');
      if (e.toString().contains('Connection') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Cannot connect to KNS API. Please check your internet connection.');
      }
      rethrow;
    }
  }
}

/// Represents a domain asset from the KNS API
class KNSDomain {
  final String id;
  final String assetId;
  final String asset;
  final String owner;
  final DateTime creationBlockTime;
  final bool isDomain;
  final bool isVerifiedDomain;
  final String status;
  final String transactionId;

  KNSDomain({
    required this.id,
    required this.assetId,
    required this.asset,
    required this.owner,
    required this.creationBlockTime,
    required this.isDomain,
    required this.isVerifiedDomain,
    required this.status,
    required this.transactionId,
  });

  factory KNSDomain.fromMap(Map<String, dynamic> map) {
    return KNSDomain(
      id: map['id'] as String? ?? '',
      assetId: map['assetId'] as String? ?? '',
      asset: map['asset'] as String? ?? '',
      owner: map['owner'] as String? ?? '',
      creationBlockTime: DateTime.parse(map['creationBlockTime'] as String? ?? DateTime.now().toIso8601String()),
      isDomain: map['isDomain'] as bool? ?? false,
      isVerifiedDomain: map['isVerifiedDomain'] as bool? ?? false,
      status: map['status'] as String? ?? '',
      transactionId: map['transactionId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'assetId': assetId,
      'asset': asset,
      'owner': owner,
      'creationBlockTime': creationBlockTime.toIso8601String(),
      'isDomain': isDomain,
      'isVerifiedDomain': isVerifiedDomain,
      'status': status,
      'transactionId': transactionId,
    };
  }
}

/// Result of a domain lookup
class KNSDomainResult {
  final bool found;
  final KNSDomain? domain;

  KNSDomainResult({
    required this.found,
    this.domain,
  });
}

/// Result of paginated domains query
class KNSDomainsResult {
  final List<KNSDomain> domains;
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  KNSDomainsResult({
    required this.domains,
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  bool get hasMore => currentPage < totalPages;
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../common/config.dart';

/// Client for interacting with the Kaspa.com NFT (KRC721) API
class KaspaNftApiClient {
  final String _baseUrl = AppConfig.kaspaComApiUrl;
  static const String _metadataBaseUrl = 'https://cache.krc721.stream/krc721/mainnet/metadata';
  static const String _ipfsGateway = 'https://ipfs.io/ipfs';
  final Duration _timeout = Duration(seconds: AppConfig.kaspaComApiTimeoutSeconds);

  /// Get all NFTs for a wallet address
  /// API: GET /krc721/wallet-lookup-nft?walletAddress={address}
  Future<List<NFTCollection>> getNFTs(String address) async {
    try {
      final url = '$_baseUrl/krc721/wallet-lookup-nft?walletAddress=$address';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((c) => NFTCollection.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      print('❌ KaspaNftApiClient: Error fetching NFTs: $e');
      return [];
    }
  }

  /// Get floor price for an NFT collection
  /// API: GET /krc721-orders/floor-price/{ticker}
  Future<NFTFloorPrice?> getFloorPrice(String ticker) async {
    try {
      final url = '$_baseUrl/krc721-orders/floor-price/$ticker';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return NFTFloorPrice.fromJson(data);
      }
      return null;
    } catch (e) {
      print('❌ KaspaNftApiClient: Error fetching floor price for $ticker: $e');
      return null;
    }
  }

  /// Get floor prices for multiple NFT collections
  Future<Map<String, double>> getFloorPrices(List<String> tickers) async {
    final Map<String, double> prices = {};
    
    // Fetch floor prices in parallel (batches of 5 to avoid overwhelming the API)
    final batches = <List<String>>[];
    for (var i = 0; i < tickers.length; i += 5) {
      batches.add(tickers.sublist(i, i + 5 > tickers.length ? tickers.length : i + 5));
    }
    
    for (final batch in batches) {
      final futures = batch.map((ticker) => getFloorPrice(ticker));
      final results = await Future.wait(futures);
      
      for (var i = 0; i < batch.length; i++) {
        final result = results[i];
        if (result != null) {
          prices[batch[i]] = result.floorPrice;
        }
      }
    }
    
    return prices;
  }

  /// Get NFT metadata including image URL
  /// API: GET https://cache.krc721.stream/krc721/mainnet/metadata/{ticker}/{tokenId}
  Future<NFTMetadata?> getNftMetadata(String ticker, String tokenId) async {
    try {
      final url = '$_metadataBaseUrl/$ticker/$tokenId';
      print('🖼️ Fetching NFT metadata: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return NFTMetadata.fromJson(data);
      }
      return null;
    } catch (e) {
      print('❌ KaspaNftApiClient: Error fetching metadata for $ticker/$tokenId: $e');
      return null;
    }
  }

  /// Convert IPFS URL to HTTP gateway URL
  String convertIpfsToHttp(String ipfsUrl) {
    if (ipfsUrl.startsWith('ipfs://')) {
      final cid = ipfsUrl.substring(7); // Remove 'ipfs://'
      return '$_ipfsGateway/$cid';
    }
    return ipfsUrl;
  }

  /// Get NFT image URL for a specific token (fetches from metadata)
  Future<String?> getNftImageUrl(String ticker, String tokenId) async {
    final metadata = await getNftMetadata(ticker, tokenId);
    if (metadata != null && metadata.image.isNotEmpty) {
      return convertIpfsToHttp(metadata.image);
    }
    return null;
  }
}

/// Represents an NFT collection owned by a wallet
class NFTCollection {
  final String ticker;
  final List<String> tokenIds;
  // Cache for image URLs
  Map<String, String> imageUrls = {};

  NFTCollection({
    required this.ticker,
    required this.tokenIds,
  });

  factory NFTCollection.fromJson(Map<String, dynamic> json) {
    final List<dynamic> ids = json['tokenIds'] ?? [];
    return NFTCollection(
      ticker: json['ticker'] as String? ?? '',
      tokenIds: ids.map((id) => id.toString()).toList(),
    );
  }

  int get count => tokenIds.length;
}

/// Represents the floor price for an NFT collection
class NFTFloorPrice {
  final String ticker;
  final double floorPrice;

  NFTFloorPrice({
    required this.ticker,
    required this.floorPrice,
  });

  factory NFTFloorPrice.fromJson(Map<String, dynamic> json) {
    return NFTFloorPrice(
      ticker: json['ticker'] as String? ?? '',
      floorPrice: (json['floorPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Represents NFT metadata
class NFTMetadata {
  final String name;
  final String description;
  final String image;
  final int tokenId;
  final List<NFTAttribute> attributes;

  NFTMetadata({
    required this.name,
    required this.description,
    required this.image,
    required this.tokenId,
    required this.attributes,
  });

  factory NFTMetadata.fromJson(Map<String, dynamic> json) {
    final List<dynamic> attrs = json['attributes'] ?? [];
    return NFTMetadata(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      image: json['image'] as String? ?? '',
      tokenId: json['tokenid'] as int? ?? 0,
      attributes: attrs.map((a) => NFTAttribute.fromJson(a)).toList(),
    );
  }
}

/// Represents an NFT attribute
class NFTAttribute {
  final String traitType;
  final String value;

  NFTAttribute({
    required this.traitType,
    required this.value,
  });

  factory NFTAttribute.fromJson(Map<String, dynamic> json) {
    return NFTAttribute(
      traitType: json['trait_type'] as String? ?? '',
      value: json['value']?.toString() ?? '',
    );
  }
}

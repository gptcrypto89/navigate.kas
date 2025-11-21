import 'dart:convert';
import '../models/browser_models.dart';
import '../helpers/url_parsing_helper.dart';
import '../services/kns_api_client.dart';
import '../services/kaspa_explorer_client.dart';

/// Result of domain resolution
class DomainResolutionResult {
  final bool success;
  final String? resolvedIp;
  final Map<String, dynamic>? certificateData;
  final bool isVerified;
  final String? errorMessage;
  final String? errorType; // 'not_found', 'not_confirmed', 'no_dns'

  DomainResolutionResult({
    required this.success,
    this.resolvedIp,
    this.certificateData,
    this.isVerified = false,
    this.errorMessage,
    this.errorType,
  });
}

/// Service for browser-related operations
class BrowserService {
  /// Parse a URL string into components
  /// Uses UrlParsingHelper for comprehensive URL parsing
  static ParsedUrl parseUrl(String url) {
    return UrlParsingHelper.parseUrl(url);
  }

  /// Build display URL from domain and HTTPS URL
  static String buildDisplayUrl(String? domain, String httpsUrl, {int? port}) {
    return UrlParsingHelper.buildDisplayUrl(domain, httpsUrl, port: port);
  }

  /// Add entry to browser history
  static void addToHistory(BrowserTab tab, String domain, String url, {bool isVerified = false}) {
    if (tab.historyIndex < tab.history.length - 1) {
      tab.history.removeRange(tab.historyIndex + 1, tab.history.length);
    }
    
    tab.history.add(HistoryEntry(
      domain: domain,
      url: url,
      isVerified: isVerified,
    ));
    tab.historyIndex = tab.history.length - 1;
  }

  /// Resolve DNS and Certificate from owner assets with validation
  static Future<({String? resolvedIp, Map<String, dynamic>? certificateData})> resolveDnsAndCertificate({
    required String domain,
    required String owner,
    required KNSApiClient knsClient,
    required KaspaExplorerClient kaspaExplorer,
    required List ownershipTimeline, // List<OwnershipPeriod> - avoiding circular import
    required dynamic validator, // InscriptionValidator - avoiding circular import
  }) async {
    String? resolvedIp;
    Map<String, dynamic>? certificateData;
    
    try {
      final fetchedAssets = await knsClient.getAllAssetsByOwner(owner);
      final ownerAssets = List<KNSDomain>.from(fetchedAssets);

      // Extract domain name without ".kas" for matching
      final domainNameWithoutKas = domain.endsWith('.kas') 
          ? domain.substring(0, domain.length - 4) 
          : domain;
      
      // Separate DNS and Certificate candidates
      final dnsCandidates = <KNSDomain>[];
      final certCandidates = <KNSDomain>[];
      
      for (final asset in ownerAssets) {
        if (asset.isDomain) continue; // Skip domain assets
        
        try {
          final content = asset.asset;
          if (!content.trim().startsWith('{')) continue;
          
          final jsonContent = json.decode(content) as Map<String, dynamic>;
          
          // Check for DNS record: {"d": "domain", "ip": "127.0.0.1"}
          if (jsonContent.containsKey('d') && jsonContent.containsKey('ip')) {
            final dnsDomain = jsonContent['d'] as String?;
            if (dnsDomain == domainNameWithoutKas) {
              print('Found DNS candidate: ${asset.assetId}');
              
              // Verify transaction exists on blockchain
              final isConfirmed = await kaspaExplorer.verifyTransaction(asset.transactionId);
              if (isConfirmed) {
                dnsCandidates.add(asset);
              }
            }
          }
          
          // Check for Certificate: {"d": "domain", "c": "certificate"}
          if (jsonContent.containsKey('d') && jsonContent.containsKey('c')) {
            final certDomain = jsonContent['d'] as String?;
            if (certDomain == domainNameWithoutKas) {
              print('Found certificate candidate: ${asset.assetId}');
              
              // Verify transaction exists on blockchain
              final isConfirmed = await kaspaExplorer.verifyTransaction(asset.transactionId);
              if (isConfirmed) {
                certCandidates.add(asset);
              }
            }
          }
        } catch (e) {
          // Not a JSON asset or invalid format, ignore
          continue;
        }
      }
      
      // Validate and select DNS record
      if (dnsCandidates.isNotEmpty) {
        print('🔍 BrowserService: Validating ${dnsCandidates.length} DNS candidates');
        final validDns = await validator.selectValidDnsRecord(dnsCandidates, ownershipTimeline, owner);
        
        if (validDns != null) {
          try {
            final jsonContent = json.decode(validDns.asset) as Map<String, dynamic>;
            resolvedIp = jsonContent['ip'] as String?;
            print('✅ BrowserService: Using validated DNS: $resolvedIp');
          } catch (e) {
            print('❌ BrowserService: Error parsing validated DNS: $e');
          }
        } else {
          print('⚠️ BrowserService: No valid DNS records found (all failed ownership validation)');
        }
      }
      
      // Validate and select certificate
      if (certCandidates.isNotEmpty) {
        print('🔍 BrowserService: Validating ${certCandidates.length} certificate candidates');
        final validCert = await validator.selectValidCertificateRecord(certCandidates, ownershipTimeline, owner);
        
        if (validCert != null) {
          try {
            final jsonContent = json.decode(validCert.asset) as Map<String, dynamic>;
            certificateData = {
              'domain': domain,
              'certificate': jsonContent['c'] as String? ?? '',
            };
            print('✅ BrowserService: Using validated certificate');
          } catch (e) {
            print('❌ BrowserService: Error parsing validated certificate: $e');
          }
        } else {
          print('⚠️ BrowserService: No valid certificates found (all failed ownership validation)');
        }
      }
      
    } catch (e) {
      print('Error fetching/validating owner assets: $e');
      // Continue with defaults if fetching fails
    }
    
    return (resolvedIp: resolvedIp, certificateData: certificateData);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/browser_models.dart';
import '../helpers/url_parsing_helper.dart';
import '../widgets/browser/browser_error_pages.dart';

/// Helper class for URL navigation logic and validation.
class UrlNavigationHelper {
  /// Validates a URL and prepares it for navigation.
  /// 
  /// Returns a ParsedUrl if valid, or null if invalid.
  /// Shows appropriate error pages for invalid URLs.
  static Future<ParsedUrl?> validateAndParseUrl({
    required String url,
    required BrowserTab tab,
    required VoidCallback onInvalidUrl,
  }) async {
    if (url.isEmpty) {
      return null;
    }

    // Normalize URL (add scheme if missing)
    final normalizedUrl = UrlParsingHelper.normalizeUrl(url);
    print('🌐 Navigation: Processing URL: $normalizedUrl');
    
    // Parse URL to extract components
    ParsedUrl parsed;
    try {
      parsed = UrlParsingHelper.parseUrl(normalizedUrl);
    } catch (e) {
      // Invalid URL format
      if (tab.controller != null) {
        onInvalidUrl();
        BrowserErrorPages.showDomainNotSupported(tab, url);
      }
      return null;
    }
    
    return parsed;
  }

  /// Checks if a domain is a KNS domain (.kas).
  /// 
  /// Shows an error page for non-.kas domains.
  /// Returns true if the domain is valid for navigation.
  static Future<bool> validateKnsDomain({
    required ParsedUrl parsed,
    required BrowserTab tab,
    required VoidCallback onInvalidDomain,
  }) async {
    final isKns = UrlParsingHelper.isKnsDomain(parsed.host);
    
    if (!isKns) {
      // Show error page for non-.kas domains
      if (tab.controller != null) {
        onInvalidDomain();
        BrowserErrorPages.showDomainNotSupported(tab, parsed.host);
      }
      return false;
    }
    
    return true;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/browser_models.dart';
import '../helpers/url_parsing_helper.dart';
import '../widgets/browser/browser_error_pages.dart';

/// Helper class for bookmark navigation logic.
/// Provides reusable methods for navigating to bookmarked URLs.
class BookmarkNavigationHelper {
  /// Navigates to a bookmark URL with proper validation and error handling.
  /// 
  /// This handles URL normalization, parsing, KNS domain validation,
  /// and delegates to the domain resolution callback.
  static Future<void> navigateToBookmark({
    required BuildContext context,
    required String url,
    required BrowserTab tab,
    required TextEditingController urlController,
    required Future<void> Function(String, {String? path, String scheme, int port, Map<String, String>? queryParameters, String? fragment}) onResolveAndLoad,
    required VoidCallback onNavigationStarted,
  }) async {
    // Set URL in controller
    urlController.text = url;
    
    // Close bookmark panel
    onNavigationStarted();
    
    // Normalize URL before parsing
    final normalizedUrl = UrlParsingHelper.normalizeUrl(url);
    
    // Parse URL to extract components
    ParsedUrl parsed;
    try {
      parsed = UrlParsingHelper.parseUrl(normalizedUrl);
    } catch (e) {
      // Invalid URL format
      if (tab.controller != null) {
        BrowserErrorPages.showDomainNotSupported(tab, url);
      }
      return;
    }
    
    // Check if it's a KNS domain - only .kas domains are allowed
    final isKns = UrlParsingHelper.isKnsDomain(parsed.host);
    
    if (!isKns) {
      // Show error page for non-.kas domains
      if (tab.controller != null) {
        BrowserErrorPages.showDomainNotSupported(tab, parsed.host);
      }
      return;
    }
    
    // Resolve KNS domain
    await onResolveAndLoad(
      parsed.host,
      path: parsed.path,
      scheme: parsed.scheme ?? 'https',
      port: parsed.port ?? 443,
      queryParameters: parsed.queryParameters,
      fragment: parsed.fragment,
    );
  }
}

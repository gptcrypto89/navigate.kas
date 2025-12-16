import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../models/browser_models.dart';
import '../../utils/html_pages.dart';

/// Utility class for displaying various error pages in the browser.
class BrowserErrorPages {
  /// Shows a "Domain not found" error page.
  static void showDomainNotFound(BrowserTab tab, String domain) {
    tab.controller?.loadData(
      data: HtmlPages.domainNotFoundPage(domain),
      baseUrl: WebUri('about:blank'),
    );
  }

  /// Shows a "Domain not confirmed on blockchain" error page.
  static void showDomainNotConfirmed(BrowserTab tab, String domain) {
    tab.controller?.loadData(
      data: HtmlPages.domainNotConfirmedPage(domain),
      baseUrl: WebUri('about:blank'),
    );
  }

  /// Shows a "No DNS record found" error page.
  static void showNoDnsRecord(BrowserTab tab, String domain) {
    tab.controller?.loadData(
      data: HtmlPages.noDnsRecordPage(domain),
      baseUrl: WebUri('about:blank'),
    );
  }

  /// Shows a "Domain not supported" error page (for non-.kas domains).
  static void showDomainNotSupported(BrowserTab tab, String domain) {
    tab.controller?.loadData(
      data: HtmlPages.domainNotSupportedPage(domain),
      baseUrl: WebUri('about:blank'),
    );
  }

  /// Shows a "Certificate error" error page.
  static void showCertificateError(BrowserTab tab, String host) {
    tab.controller?.loadData(
      data: HtmlPages.certificateErrorPage(host),
      baseUrl: WebUri('about:blank'),
    );
  }

  /// Shows a "Connection error" error page with details.
  static void showConnectionError(BrowserTab tab, String domain, String errorType, String? errorDetails) {
    tab.controller?.loadData(
      data: HtmlPages.connectionErrorPage(domain, errorType, errorDetails),
      baseUrl: WebUri('about:blank'),
    );
  }
}

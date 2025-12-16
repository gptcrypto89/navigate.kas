import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../models/browser_models.dart';
import '../../utils/html_pages.dart';

/// Utility class for managing browser loading states and displaying loading pages.
class BrowserLoadingWidget {
  /// Shows a loading page with a specific status message.
  static void showLoadingPage(BrowserTab tab, String domain, String status) {
    tab.controller?.loadData(
      data: HtmlPages.loadingPage(domain, status),
      baseUrl: WebUri('about:blank'),
    );
  }

  /// Shows an empty page (new tab page).
  static void showEmptyPage(BrowserTab tab) {
    if (tab.controller != null) {
      tab.controller!.loadData(
        data: HtmlPages.emptyPage(),
        baseUrl: WebUri('about:blank'),
      );
    }
  }
}

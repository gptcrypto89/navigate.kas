import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../models/browser_models.dart';
import '../../services/settings_service.dart';

class BrowserWebViewArea extends StatefulWidget {
  final List<BrowserTab> tabs;
  final int currentIndex;
  final Function(int, InAppWebViewController) onWebViewCreated;
  final Future<ServerTrustAuthResponse?> Function(int, InAppWebViewController, URLAuthenticationChallenge) onReceivedServerTrustAuthRequest;
  final Function(int, InAppWebViewController, WebUri?) onLoadStart;
  final Function(int, InAppWebViewController, WebUri?) onLoadStop;
  final Function(int, InAppWebViewController, WebResourceRequest, WebResourceError) onReceivedError;

  const BrowserWebViewArea({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onWebViewCreated,
    required this.onReceivedServerTrustAuthRequest,
    required this.onLoadStart,
    required this.onLoadStop,
    required this.onReceivedError,
  });

  @override
  State<BrowserWebViewArea> createState() => _BrowserWebViewAreaState();
}

class _BrowserWebViewAreaState extends State<BrowserWebViewArea> {
  InAppWebViewSettings? _browserSettings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getBrowserSettings();
      if (mounted) {
        setState(() {
          _browserSettings = InAppWebViewSettings(
            javaScriptEnabled: settings['enableJavaScript'] ?? true,
            allowsInlineMediaPlayback: true,
            mediaPlaybackRequiresUserGesture: false,
            allowFileAccessFromFileURLs: false,
            allowUniversalAccessFromFileURLs: false,
          );
        });
      }
    } catch (e) {
      print('Error loading browser settings: $e');
      if (mounted) {
        setState(() {
          _browserSettings = InAppWebViewSettings(
            javaScriptEnabled: true,
            allowsInlineMediaPlayback: true,
            mediaPlaybackRequiresUserGesture: false,
            allowFileAccessFromFileURLs: false,
            allowUniversalAccessFromFileURLs: false,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_browserSettings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return IndexedStack(
      index: widget.currentIndex,
      children: widget.tabs.asMap().entries.map((entry) {
        final tabIndex = entry.key;
        final tabData = entry.value;
        
        return InAppWebView(
          key: ValueKey(tabData.id),
          initialSettings: _browserSettings,
          initialUrlRequest: tabData.currentUrl.isNotEmpty
              ? URLRequest(url: WebUri('about:blank'))
              : null,
          onWebViewCreated: (controller) => widget.onWebViewCreated(tabIndex, controller),
          onReceivedServerTrustAuthRequest: (controller, challenge) => 
              widget.onReceivedServerTrustAuthRequest(tabIndex, controller, challenge),
          onLoadStart: (controller, url) => widget.onLoadStart(tabIndex, controller, url),
          onLoadStop: (controller, url) => widget.onLoadStop(tabIndex, controller, url),
          onReceivedError: (controller, request, error) => 
              widget.onReceivedError(tabIndex, controller, request, error),
        );
      }).toList(),
    );
  }
}

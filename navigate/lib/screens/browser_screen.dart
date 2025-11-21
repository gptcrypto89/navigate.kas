import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:window_manager/window_manager.dart';
import '../services/kns_api_client.dart';
import '../services/kaspa_explorer_client.dart';
import '../services/wallet_service.dart';
import '../services/browser_service.dart';
import '../helpers/url_parsing_helper.dart';
import '../models/bookmark_models.dart';
import '../models/browser_models.dart';
import '../services/bookmark_service.dart';
import '../utils/html_pages.dart';
import '../panels/ai_assistant_panel.dart';
import '../panels/bookmark_panel.dart';
import '../widgets/browser/certificate_info_dialog.dart';
import '../widgets/browser/add_bookmark_dialog.dart';
import '../services/settings_service.dart';
import 'wallets_screen.dart';
import 'master_password_screen.dart';
import '../services/certificate_pinning_service.dart';
import '../services/domain_ownership_service.dart';
import '../services/inscription_validator.dart';
import '../widgets/browser/browser_tab_bar.dart';
import '../widgets/browser/browser_navigation_bar.dart';
import '../widgets/browser/browser_error_bar.dart';
import '../widgets/browser/browser_web_view_area.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> with WindowListener {
  // Tab management
  final List<BrowserTab> _tabs = [];
  int _currentTabIndex = 0;
  bool _isAIPanelOpen = false;
  bool _isBookmarkPanelOpen = false;
  String _balance = "0.00";
  bool _isFullScreen = false; // Track fullscreen state - start in maximized, not fullscreen
  bool _isAIEnabled = true; // Track if AI assistant is enabled
  Map<String, dynamic> _aiSettings = {}; // Store AI settings
  Timer? _balanceTimer; // Timer for periodic balance updates
  
  // Bookmark management
  List<Bookmark> _bookmarks = [];
  List<BookmarkFolder> _folders = [];
  Bookmark? _currentPageBookmark;
  
  BrowserTab get _currentTab => _tabs[_currentTabIndex];
  
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkFullScreen();
    _createNewTab();
    _loadBalance();
    _loadBookmarks();
    _loadAISettings();
    
    // Start periodic balance updates every 5 seconds
    _balanceTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadBalance();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload AI settings when dependencies change (e.g., coming back from settings)
    _loadAISettings();
  }

  Future<void> _loadAISettings() async {
    try {
      final aiSettings = await SettingsService.getAISettings();
      if (mounted) {
        setState(() {
          _aiSettings = aiSettings;
          _isAIEnabled = aiSettings['enableAI'] ?? true;
          // Close AI panel if AI was disabled
          if (!_isAIEnabled && _isAIPanelOpen) {
            _isAIPanelOpen = false;
          }
        });
      }
    } catch (e) {
      // If wallet not unlocked, default to enabled
      if (mounted) {
        setState(() {
          _isAIEnabled = true;
          _aiSettings = {};
        });
      }
    }
  }
  
  @override
  void dispose() {
    _balanceTimer?.cancel();
    windowManager.removeListener(this);
    for (final tab in _tabs) {
      tab.dispose();
    }
    super.dispose();
  }
  
  // Window listener methods
  @override
  void onWindowEnterFullScreen() {
    setState(() {
      _isFullScreen = true;
    });
  }
  
  @override
  void onWindowLeaveFullScreen() {
    setState(() {
      _isFullScreen = false;
    });
  }
  
  Future<void> _checkFullScreen() async {
    final isFullScreen = await windowManager.isFullScreen();
    if (mounted) {
      setState(() {
        _isFullScreen = isFullScreen;
      });
    }
  }
  
  Future<void> _loadBalance() async {
    try {
      final address = await WalletService.getWalletAddress();
      if (address == null || address.isEmpty) {
        setState(() {
          _balance = "0.00";
        });
        return;
      }

      final explorerClient = KaspaExplorerClient();
      final balanceData = await explorerClient.getAddressBalance(address);
      
      if (mounted && balanceData != null) {
        setState(() {
          _balance = balanceData.balanceInKas.toStringAsFixed(2);
        });
      } else if (mounted) {
        setState(() {
          _balance = "0.00";
        });
      }
    } catch (e) {
      print('Error loading balance: $e');
      if (mounted) {
        setState(() {
          _balance = "0.00";
        });
      }
    }
  }
  
  // Bookmark management methods
  Future<void> _loadBookmarks() async {
    final bookmarks = await BookmarkService.getBookmarks();
    final folders = await BookmarkService.getFolders();
    
    if (mounted) {
      setState(() {
        _bookmarks = bookmarks;
        _folders = folders;
      });
      _checkCurrentPageBookmark();
    }
  }
  
  Future<void> _checkCurrentPageBookmark() async {
    if (_currentTab.currentUrl.isEmpty) {
      setState(() {
        _currentPageBookmark = null;
      });
      return;
    }
    
    final bookmark = await BookmarkService.getBookmarkByUrl(_currentTab.currentUrl);
    if (mounted) {
      setState(() {
        _currentPageBookmark = bookmark;
      });
    }
  }
  
  Future<void> _toggleBookmark() async {
    if (_currentPageBookmark != null) {
      // Remove bookmark
      await BookmarkService.deleteBookmark(_currentPageBookmark!.id);
      await _loadBookmarks();
    } else {
      // Add bookmark
      _showAddBookmarkDialog();
    }
  }
  
  void _showAddBookmarkDialog() async {
    final bookmark = await AddBookmarkDialog.show(
      context,
      initialName: _currentTab.title,
                  url: _currentTab.currentUrl,
      folders: _folders,
                );
                
    if (bookmark != null) {
                await BookmarkService.addBookmark(bookmark);
                await _loadBookmarks();
    }
  }
  
  Future<void> _deleteBookmark(String id) async {
    await BookmarkService.deleteBookmark(id);
    await _loadBookmarks();
  }
  
  void _switchToTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      setState(() {
        _currentTabIndex = index;
      });
      _checkCurrentPageBookmark(); // Update bookmark status when switching tabs
    }
  }
  
  void _closeTab(int index) {
    if (_tabs.length <= 1) {
      // Don't close the last tab, just clear it
      final tab = _tabs[0];
      tab.dispose();
      _tabs[0] = _createTab();
      setState(() {
        _currentTabIndex = 0;
      });
      _showEmptyPage(_tabs[0]);
      return;
    }
    
    final tab = _tabs[index];
    tab.dispose();
    _tabs.removeAt(index);
    
    setState(() {
      if (_currentTabIndex >= _tabs.length) {
        _currentTabIndex = _tabs.length - 1;
      } else if (_currentTabIndex > index) {
        _currentTabIndex--;
      }
    });
  }
  
  void _closeOtherTabs(int keepIndex) {
    // Close all tabs except the one at keepIndex
    final tabToKeep = _tabs[keepIndex];
    for (int i = _tabs.length - 1; i >= 0; i--) {
      if (i != keepIndex) {
        _tabs[i].dispose();
      }
    }
    _tabs.clear();
    _tabs.add(tabToKeep);
    setState(() {
      _currentTabIndex = 0;
    });
  }
  
  void _closeTabsToLeft(int index) {
    if (index == 0) return;
    
    for (int i = index - 1; i >= 0; i--) {
      _tabs[i].dispose();
    }
    final remainingTabs = _tabs.sublist(index);
    _tabs.clear();
    _tabs.addAll(remainingTabs);
    
    setState(() {
      _currentTabIndex = 0;
    });
  }
  
  void _closeTabsToRight(int index) {
    if (index == _tabs.length - 1) return;
    
    for (int i = _tabs.length - 1; i > index; i--) {
      _tabs[i].dispose();
    }
    _tabs.removeRange(index + 1, _tabs.length);
    
    setState(() {
      if (_currentTabIndex > index) {
        _currentTabIndex = index;
      }
    });
  }
  
  void _duplicateTab(int index) {
    final originalTab = _tabs[index];
    final newTab = _createTab();
    
    // Copy properties from original tab
    newTab.currentUrl = originalTab.currentUrl;
    newTab.currentDomain = originalTab.currentDomain;
    newTab.title = originalTab.title;
    newTab.isVerified = originalTab.isVerified;
    
    setState(() {
      _tabs.insert(index + 1, newTab);
      _currentTabIndex = index + 1;
    });
    
    // Load the same URL in the new tab
    if (originalTab.currentUrl.isNotEmpty) {
      _loadUrlInTab(newTab, originalTab.currentUrl);
    }
  }
  
  void _loadUrlInTab(BrowserTab tab, String url) {
    setState(() {
      tab.currentUrl = url;
      tab.isLoading = true;
    });
    
    // Trigger navigation
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // Direct URL
      tab.controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    } else {
      // Domain name - resolve it
      _resolveAndLoadDomain(url);
    }
  }
  
  void _showTabContextMenu(BuildContext context, int index, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'close',
          child: Row(
            children: [
              Icon(Icons.close, size: 18),
              SizedBox(width: 8),
              Text('Close'),
            ],
          ),
        ),
        if (_tabs.length > 1)
          const PopupMenuItem(
            value: 'close_others',
            child: Row(
              children: [
                Icon(Icons.tab, size: 18),
                SizedBox(width: 8),
                Text('Close Others'),
              ],
            ),
          ),
        if (index > 0)
          const PopupMenuItem(
            value: 'close_left',
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 18),
                SizedBox(width: 8),
                Text('Close to Left'),
              ],
            ),
          ),
        if (index < _tabs.length - 1)
          const PopupMenuItem(
            value: 'close_right',
            child: Row(
              children: [
                Icon(Icons.arrow_forward, size: 18),
                SizedBox(width: 8),
                Text('Close to Right'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.content_copy, size: 18),
              SizedBox(width: 8),
              Text('Duplicate'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      
      switch (value) {
        case 'close':
          _closeTab(index);
          break;
        case 'close_others':
          _closeOtherTabs(index);
          break;
        case 'close_left':
          _closeTabsToLeft(index);
          break;
        case 'close_right':
          _closeTabsToRight(index);
          break;
        case 'duplicate':
          _duplicateTab(index);
          break;
      }
    });
  }
  
  void _createNewTab() {
    final tab = _createTab();
    _tabs.add(tab);
    setState(() {
      _currentTabIndex = _tabs.length - 1;
    });
    _showEmptyPage(tab);
  }
  
  BrowserTab _createTab() {
    // Create the tab - controller will be set when InAppWebView is created
    final tab = BrowserTab(
      id: DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString(),
      controller: null, // Will be set in onWebViewCreated
      urlController: TextEditingController(),
      knsClient: KNSApiClient(),
      kaspaExplorer: KaspaExplorerClient(),
    );
    
    return tab;
  }

  void _showLoadingPage(BrowserTab tab, String domain, String status) {
    tab.controller?.loadData(
      data: HtmlPages.loadingPage(domain, status),
      baseUrl: WebUri('about:blank'),
    );
  }

  void _showEmptyPage(BrowserTab tab) {
    setState(() {
      tab.currentUrl = '';
      tab.currentDomain = null;
      tab.isVerified = false;
      tab.errorMessage = null;
      tab.isLoading = false;
      tab.title = 'New Tab';
    });
    
    if (tab.controller != null) {
      tab.controller!.loadData(
        data: HtmlPages.emptyPage(),
        baseUrl: WebUri('about:blank'),
      );
    }
  }

  Future<void> _resolveAndLoadDomain(
    String domain, {
    String? path,
    String scheme = 'https',
    int port = 443,
    Map<String, String>? queryParameters,
    String? fragment,
  }) async {
    final tab = _currentTab;
    
    setState(() {
      tab.isLoading = true;
      tab.errorMessage = null;
      tab.isVerified = false;
      tab.currentUrl = '';
      tab.currentDomain = null;
    });

    // Show loading page immediately
    _showLoadingPage(tab, domain, 'Checking domain in KNS...');

    try {
      print('Resolving domain via KNS API: $domain');
      
      final result = await tab.knsClient.checkDomainExists(domain);
      
      if (!result.found || result.domain == null) {
        _showDomainNotFoundPage(tab, domain);
        return;
      }

      // Domain found and verified in KNS
      final knsDomain = result.domain!;
      
      // Update loading page for blockchain verification
      _showLoadingPage(tab, domain, 'Verifying on Kaspa blockchain...');
      
      // Double-check: Verify transaction on Kaspa blockchain
      print('Verifying transaction on Kaspa blockchain: ${knsDomain.transactionId}');
      final isTransactionConfirmed = await tab.kaspaExplorer.verifyTransaction(knsDomain.transactionId);
      
      if (!isTransactionConfirmed) {
        print('Transaction verification failed on blockchain');
        setState(() {
          tab.isLoading = false;
          tab.errorMessage = 'Domain transaction not confirmed on blockchain';
        });
        _showDomainNotConfirmedPage(tab, domain);
        return;
      }
      
      print('Transaction confirmed on blockchain - domain is valid');
      
      // Update loading page for ownership tracking
      _showLoadingPage(tab, domain, 'Building ownership timeline...');
      
      // Build ownership timeline for anti-hijacking validation
      final ownershipService = DomainOwnershipService(
        knsClient: tab.knsClient,
        kaspaExplorer: tab.kaspaExplorer,
      );
      
      final ownershipTimeline = await ownershipService.buildOwnershipTimeline(domain);
      
      if (ownershipTimeline.isEmpty) {
        print('⚠️ Browser: Could not build ownership timeline, proceeding without validation');
      }
      
      // Update loading page for DNS and Certificate search
      _showLoadingPage(tab, domain, 'Fetching & validating DNS records...');
      
      // Create validator
      final validator = InscriptionValidator(
        kaspaExplorer: tab.kaspaExplorer,
        ownershipService: ownershipService,
      );
      
      // Use validated DNS/certificate resolution
      String? resolvedIp;
      Map<String, dynamic>? certificateData;
      
      final dnsResult = await BrowserService.resolveDnsAndCertificate(
        domain: domain,
        owner: knsDomain.owner,
        knsClient: tab.knsClient,
        kaspaExplorer: tab.kaspaExplorer,
        ownershipTimeline: ownershipTimeline,
        validator: validator,
      );
      
      resolvedIp = dnsResult.resolvedIp;
      certificateData = dnsResult.certificateData;
      
      if (resolvedIp == null) {
        print('No DNS record found for $domain');
        setState(() {
          tab.isLoading = false;
          tab.errorMessage = 'No DNS record found for $domain';
        });
        
        tab.controller?.loadData(
          data: HtmlPages.noDnsRecordPage(domain),
          baseUrl: WebUri('about:blank'),
        );
        return;
      }

      // Update loading page for final step
      _showLoadingPage(tab, domain, 'Loading content...');
      
      // Build ParsedUrl object for URL construction
      final parsedUrl = ParsedUrl(
        scheme: 'https',
        host: domain,
        port: port,
        path: path,
        queryParameters: queryParameters ?? {},
        fragment: fragment,
      );
      
      // Build HTTPS URL using resolved IP (for actual navigation)
      final httpsUrl = parsedUrl.buildHttpsUrl(resolvedIp);
      
      // Build display URL (for showing in address bar)
      final displayUrl = parsedUrl.buildDisplayUrl();
      
      setState(() {
        tab.isVerified = knsDomain.isVerifiedDomain; // Base verification
        tab.certificateData = certificateData;
        tab.currentDomain = domain;
        tab.currentUrl = displayUrl;
        tab.urlController.text = displayUrl;
        tab.title = domain;
      });
      
      BrowserService.addToHistory(tab, domain, httpsUrl, isVerified: knsDomain.isVerifiedDomain);
      
      // Pass certificate data to load function if needed, or handle unsecure warning
      if (certificateData == null) {
        // Show warning for unsecure connection
        setState(() {
          tab.isLoading = false;
        });
        
        final shouldProceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Unsecured Connection', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(
              'No valid SSL certificate found for $domain.\n\nYour connection to this site is not secure. Do you want to proceed?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Go Back', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Proceed Anyway', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        
        if (shouldProceed != true) {
          _showEmptyPage(tab);
          return;
        }
        
        setState(() {
          tab.isLoading = true;
        });
      }
      
      await _loadPageFromHTTPS(tab, httpsUrl);
      
    } catch (e) {
      print('KNS lookup error: $e');
      _showDomainNotFoundPage(tab, domain);
    }
  }

  void _showDomainNotFoundPage(BrowserTab tab, String domain) {
    setState(() {
      tab.isLoading = false;
      tab.isVerified = false;
      tab.currentUrl = '';
      tab.currentDomain = null;
      tab.errorMessage = null;
      tab.title = 'New Tab';
    });
    
    tab.controller?.loadData(
      data: HtmlPages.domainNotFoundPage(domain),
      baseUrl: WebUri('about:blank'),
    );
  }

  void _showDomainNotConfirmedPage(BrowserTab tab, String domain) {
    setState(() {
      tab.isLoading = false;
      tab.isVerified = false;
      tab.currentUrl = '';
      tab.currentDomain = null;
      tab.errorMessage = null;
      tab.title = 'New Tab';
    });
    
    tab.controller?.loadData(
      data: HtmlPages.domainNotConfirmedPage(domain),
      baseUrl: WebUri('about:blank'),
    );
    }

  Future<void> _goBack() async {
    final tab = _currentTab;
    if (!tab.canGoBack) return;
    
    tab.historyIndex--;
    final entry = tab.history[tab.historyIndex];
    
    final displayUrl = BrowserService.buildDisplayUrl(entry.domain, entry.url);
    
    setState(() {
      tab.currentDomain = entry.domain;
      tab.currentUrl = displayUrl;
      tab.isVerified = entry.isVerified;
      tab.urlController.text = displayUrl;
      tab.title = entry.domain.isEmpty ? 'New Tab' : entry.domain;
    });
    
    await _loadPageFromHTTPS(tab, entry.url);
  }

  Future<void> _goForward() async {
    final tab = _currentTab;
    if (!tab.canGoForward) return;
    
    tab.historyIndex++;
    final entry = tab.history[tab.historyIndex];
    
    final displayUrl = BrowserService.buildDisplayUrl(entry.domain, entry.url);
    
    setState(() {
      tab.currentDomain = entry.domain;
      tab.currentUrl = displayUrl;
      tab.isVerified = entry.isVerified;
      tab.urlController.text = displayUrl;
      tab.title = entry.domain.isEmpty ? 'New Tab' : entry.domain;
    });
    
    await _loadPageFromHTTPS(tab, entry.url);
  }

  Future<void> _refresh() async {
    final tab = _currentTab;
    if (tab.currentUrl.isEmpty || tab.historyIndex < 0) {
      if (tab.currentUrl.isEmpty) {
        _showEmptyPage(tab);
      }
      return;
    }
    
    // If controller is available, just reload the current page
    if (tab.controller != null) {
      try {
        await tab.controller!.reload();
        return;
      } catch (e) {
        print('Error reloading: $e');
      }
    }
    
    // Fallback: reload from history
    final entry = tab.history[tab.historyIndex];
    await _loadPageFromHTTPS(tab, entry.url);
  }

  void _stopLoading() {
    final tab = _currentTab;
    if (tab.controller != null) {
      tab.controller!.stopLoading();
    }
    setState(() {
      tab.isLoading = false;
    });
  }

  Future<void> _loadPageFromHTTPS(BrowserTab tab, String httpsUrl) async {
    if (tab.isLoadingPage) {
      print('Already loading a page, ignoring: $httpsUrl');
      return;
    }

    setState(() {
      tab.isLoading = true;
      tab.isLoadingPage = true;
      tab.errorMessage = null;
    });

    try {
      print('Loading page via HTTPS: $httpsUrl');
      
      // Load the URL directly in the WebView
      if (tab.controller != null) {
        await tab.controller!.loadUrl(
          urlRequest: URLRequest(url: WebUri(httpsUrl)),
        );
      }
      
      setState(() {
        tab.isLoading = false;
        tab.isLoadingPage = false;
      });
    } catch (e) {
      print('Error loading page: $e');
      setState(() {
        tab.isLoading = false;
        tab.isLoadingPage = false;
        tab.errorMessage = 'Failed to load page: $e';
      });
    }
  }


  Future<void> _navigateToUrl() async {
    final tab = _currentTab;
    var url = tab.urlController.text.trim();
    
    if (url.isEmpty) {
      _showEmptyPage(tab);
      return;
    }

    // Normalize URL (add scheme if missing) before parsing
    url = UrlParsingHelper.normalizeUrl(url);
    print('🌐 Navigation: Processing URL: $url');
    
    // Parse URL to extract the host/domain properly
    ParsedUrl parsed;
    try {
      parsed = UrlParsingHelper.parseUrl(url);
    } catch (e) {
      // Invalid URL format
      if (tab.controller != null) {
        setState(() {
          tab.isLoading = false;
          tab.isLoadingPage = false;
          tab.currentUrl = '';
          tab.currentDomain = null;
          tab.errorMessage = 'Invalid URL format';
        });
        await tab.controller!.loadData(
          data: HtmlPages.domainNotSupportedPage(url),
          baseUrl: WebUri('about:blank'),
        );
      }
      return;
    }
    
    // Check if it's a KNS domain - only .kas domains are allowed
    final isKns = UrlParsingHelper.isKnsDomain(parsed.host);
    
    if (!isKns) {
      // Show error page for non-.kas domains
      if (tab.controller != null) {
        setState(() {
          tab.isLoading = false;
          tab.isLoadingPage = false;
          tab.currentUrl = '';
          tab.currentDomain = null;
          tab.errorMessage = 'Only .kas domains are supported';
        });
        await tab.controller!.loadData(
          data: HtmlPages.domainNotSupportedPage(parsed.host),
          baseUrl: WebUri('about:blank'),
        );
      }
      return;
    }
    
    // Parse for KNS domain resolution
    print('🔍 Navigation: Starting KNS resolution for domain: ${parsed.host}');
    await _resolveAndLoadDomain(
      parsed.host,
      path: parsed.path,
      scheme: parsed.scheme ?? 'https',
      port: parsed.port ?? 443,
      queryParameters: parsed.queryParameters,
      fragment: parsed.fragment,
    );
  }

  // WebView Callbacks
  void _handleWebViewCreated(int tabIndex, InAppWebViewController controller) {
                    // Store the controller in the specific tab
                    _tabs[tabIndex].controller = controller;
                    // Load empty page if no URL
    if (_tabs[tabIndex].currentUrl.isEmpty) {
                      _showEmptyPage(_tabs[tabIndex]);
                    }
  }

  Future<ServerTrustAuthResponse?> _handleServerTrustAuthRequest(
      int tabIndex, InAppWebViewController controller, URLAuthenticationChallenge challenge) async {
                    final host = challenge.protectionSpace.host;
                    print('🔐 Navigation: Received server trust auth request for $host');
                    
                    // Check if we have a pinned certificate for this domain
                    final currentTab = _tabs[tabIndex];
                    final certData = currentTab.certificateData;
                    
                    if (certData != null && certData['certificate'] != null) {
                      final String trustedRoot = certData['certificate'];
                      final serverCert = challenge.protectionSpace.sslCertificate?.x509Certificate;
                      
                      if (serverCert != null) {
                        print('🛡️ Navigation: Validating certificate for $host against pinned root...');
                        print('📜 Navigation: Pinned Root (preview): ${trustedRoot.length > 50 ? trustedRoot.substring(0, 50) : trustedRoot}...');
                        
                        final isValid = await CertificatePinningService.validateCertificate(
                          serverCert: serverCert.encoded!,
                          trustedRoot: trustedRoot,
                          domain: host,
                        );
                        
                        if (isValid) {
                          print('✅ Navigation: Certificate validation SUCCESS for $host. Connection secure.');
                          return ServerTrustAuthResponse(
                            action: ServerTrustAuthResponseAction.PROCEED,
                          );
                        } else {
                          print('❌ Navigation: Certificate validation FAILED for $host. Potential MITM attack blocked.');
                          
                          // Show error page
                          controller.loadData(
                            data: HtmlPages.certificateErrorPage(host),
                            mimeType: 'text/html',
                            encoding: 'utf-8',
                          );
                          
                          return ServerTrustAuthResponse(
                            action: ServerTrustAuthResponseAction.CANCEL,
                          );
                        }
                      } else {
                         print('⚠️ Navigation: Server certificate is null for $host');
                      }
                    }
                    
                    // If we are here, it means either:
                    // 1. It's not a KNS domain (standard web)
                    // 2. It IS a KNS domain but we failed to resolve a certificate for it (which should be blocked)
                    // Given the requirement "no man in the middle", if we expect a cert and don't validate it, we should fail.
                    
                    if (UrlParsingHelper.isKnsDomain(host)) {
                         print('🛑 Navigation: Blocking connection to $host - KNS domain without valid pinned certificate verification');
                         
                         // Show error page
                          controller.loadData(
                            data: HtmlPages.certificateErrorPage(host),
                            mimeType: 'text/html',
                            encoding: 'utf-8',
                          );
                          
                         return ServerTrustAuthResponse(
                            action: ServerTrustAuthResponseAction.CANCEL,
                          );
                    }

                    print('🌍 Navigation: Allowing connection to $host (standard validation)');
                    return null; // Use default system validation
  }

  void _handleLoadStart(int tabIndex, InAppWebViewController controller, WebUri? url) {
                    setState(() {
                      _tabs[tabIndex].isLoading = true;
                    });
  }

  Future<void> _handleLoadStop(int tabIndex, InAppWebViewController controller, WebUri? url) async {
                    final title = await controller.getTitle();
                    setState(() {
                      _tabs[tabIndex].isLoading = false;
                      _tabs[tabIndex].isLoadingPage = false;
                      if (title != null && title.isNotEmpty) {
                        _tabs[tabIndex].title = title;
                      }
                    });
                    // Update bookmark status after page loads
                    if (tabIndex == _currentTabIndex) {
                      _checkCurrentPageBookmark();
                    }
  }

  void _handleWebViewError(int tabIndex, InAppWebViewController controller, WebResourceRequest request, WebResourceError error) {
                    print('WebView error: ${error.description} - ${error.type}');
                    
                    // Get error details
                    final errorDescription = error.description ?? 'Unknown error';
                    final errorTypeString = error.type?.toString() ?? '';
                    
                    // Determine error type for better messaging
                    String errorType = errorDescription.toLowerCase();
                    String? errorDetails;
                    
                    // Check if domain and certificate were found (connection issue)
                    if (_tabs[tabIndex].currentDomain != null && _tabs[tabIndex].certificateData != null) {
                      // Domain and certificate found, but connection failed
                      if (errorType.contains('connection refused') || 
                          errorType.contains('refused') ||
                          errorTypeString.contains('CONNECTION_REFUSED')) {
                        errorType = 'connection refused';
                        errorDetails = 'The domain and certificate were found, but the server is not accepting connections. Please check if the server is running and the port number is correct.';
                      } else if (errorType.contains('timeout') || 
                                 errorType.contains('timed out') ||
                                 errorTypeString.contains('TIMEOUT')) {
                        errorType = 'timeout';
                        errorDetails = 'The domain and certificate were found, but the connection timed out. The server may be slow or unreachable.';
                      } else if (errorType.contains('host') || 
                                 errorType.contains('not found') ||
                                 errorTypeString.contains('HOST_NOT_FOUND')) {
                        errorType = 'host not found';
                        errorDetails = 'The domain was found, but the hostname could not be resolved.';
                      } else if (errorType.contains('ssl') || 
                                 errorType.contains('certificate') ||
                                 errorTypeString.contains('SSL')) {
                        errorType = 'ssl error';
                        errorDetails = 'The domain and certificate were found, but there was an SSL/TLS error.';
                      } else {
                        errorDetails = 'The domain and certificate were found, but the connection failed.';
                      }
                    }
                    
                    // Show error page instead of just error message
                    final domain = _tabs[tabIndex].currentDomain ?? 'the server';
                    controller.loadData(
                      data: HtmlPages.connectionErrorPage(domain, errorType, errorDetails),
                      baseUrl: WebUri('about:blank'),
                    );
                    
                    setState(() {
                      _tabs[tabIndex].isLoading = false;
                      _tabs[tabIndex].isLoadingPage = false;
                      // Set a more descriptive error message
                      if (errorDetails != null) {
                        _tabs[tabIndex].errorMessage = errorDetails;
                      } else {
                        _tabs[tabIndex].errorMessage = 'Connection error: ${errorDescription}';
                      }
                    });
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
                );
    }
    
    final tab = _currentTab;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.primary,
        toolbarHeight: 0,
      ),
      body: Stack(
        children: [
          // Main browser content
          Column(
            children: [
              // Tab Bar
              BrowserTabBar(
                tabs: _tabs,
                currentIndex: _currentTabIndex,
                isFullScreen: _isFullScreen,
                balance: _balance,
                onTabSelected: _switchToTab,
                onTabClosed: _closeTab,
                onNewTab: _createNewTab,
                onTabContextMenu: (index, position) => _showTabContextMenu(context, index, position),
                onBackToWallets: () {
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const WalletsScreen()),
                    );
                  }
                },
                onSettings: () async {
                  await Navigator.of(context).pushNamed('/settings');
                  // Reload AI settings when returning from settings
                  _loadAISettings();
                },
                onChat: () {
                  Navigator.of(context).pushNamed('/chat');
                },
                onWalletInfo: () {
                  Navigator.of(context).pushNamed('/wallet-info');
                },
              ),
              // Navigation Toolbar
              BrowserNavigationBar(
                currentTab: tab,
                currentPageBookmark: _currentPageBookmark,
                isBookmarkPanelOpen: _isBookmarkPanelOpen,
                isAIPanelOpen: _isAIPanelOpen,
                isAIEnabled: _isAIEnabled,
                onBack: _goBack,
                onForward: _goForward,
                onRefresh: _refresh,
                onStop: _stopLoading,
                onUrlSubmitted: (url) => _navigateToUrl(),
                onToggleBookmark: _toggleBookmark,
                onToggleBookmarkPanel: () {
                  setState(() {
                    _isBookmarkPanelOpen = !_isBookmarkPanelOpen;
                    if (_isBookmarkPanelOpen) {
                      _isAIPanelOpen = false; // Close AI panel if open
                    }
                  });
                },
                onToggleAIPanel: () {
                  setState(() {
                    _isAIPanelOpen = !_isAIPanelOpen;
                    if (_isAIPanelOpen) {
                      _isBookmarkPanelOpen = false; // Close bookmark panel if open
                    }
                  });
                },
                onCertificateTap: () {
                   if (tab.certificateData != null) {
                     CertificateInfoDialog.show(context, tab.certificateData!);
                   }
                },
              ),
              // Error Bar
              BrowserErrorBar(
                errorMessage: tab.errorMessage,
                onClose: () {
                  setState(() {
                    tab.errorMessage = null;
                  });
                },
              ),
              // WebView Area
              Expanded(
                child: BrowserWebViewArea(
                  tabs: _tabs,
                  currentIndex: _currentTabIndex,
                  onWebViewCreated: _handleWebViewCreated,
                  onReceivedServerTrustAuthRequest: _handleServerTrustAuthRequest,
                  onLoadStart: _handleLoadStart,
                  onLoadStop: _handleLoadStop,
                  onReceivedError: _handleWebViewError,
            ),
          ),
        ],
      ),
          // Bookmark Panel Overlay
          if (_isBookmarkPanelOpen)
            Positioned(
              right: 0,
              top: 92, // Start below tabs and navigation bar
              bottom: 0,
              child: Material(
                elevation: 8,
                child: Container(
                  width: 350,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: BookmarkPanel(
                    bookmarks: _bookmarks,
                    folders: _folders,
                    onDeleteBookmark: (id) async {
                      await _deleteBookmark(id);
                    },
                    onNavigateToUrl: (url) async {
                      // Load bookmark URL
                      _currentTab.urlController.text = url;
                                setState(() {
                                  _isBookmarkPanelOpen = false;
                                });
                      
                      // Normalize URL before parsing
                      final normalizedUrl = UrlParsingHelper.normalizeUrl(url);
                      
                      // Parse URL to extract the host/domain properly
                      ParsedUrl parsed;
                      try {
                        parsed = UrlParsingHelper.parseUrl(normalizedUrl);
                      } catch (e) {
                        // Invalid URL format
                        if (_currentTab.controller != null) {
                          setState(() {
                            _currentTab.isLoading = false;
                            _currentTab.isLoadingPage = false;
                            _currentTab.currentUrl = '';
                            _currentTab.currentDomain = null;
                            _currentTab.errorMessage = 'Invalid URL format';
                          });
                          await _currentTab.controller!.loadData(
                            data: HtmlPages.domainNotSupportedPage(url),
                            baseUrl: WebUri('about:blank'),
                          );
                        }
                        return;
                      }
                      
                      // Check if it's a KNS domain - only .kas domains are allowed
                      final isKns = UrlParsingHelper.isKnsDomain(parsed.host);
                      
                      if (!isKns) {
                        // Show error page for non-.kas domains
                        if (_currentTab.controller != null) {
                                      setState(() {
                            _currentTab.isLoading = false;
                            _currentTab.isLoadingPage = false;
                            _currentTab.currentUrl = '';
                            _currentTab.currentDomain = null;
                            _currentTab.errorMessage = 'Only .kas domains are supported';
                          });
                          await _currentTab.controller!.loadData(
                            data: HtmlPages.domainNotSupportedPage(parsed.host),
                            baseUrl: WebUri('about:blank'),
                          );
                        }
                        return;
                      }
                      
                      // Parse and resolve KNS domain
                      await _resolveAndLoadDomain(
                        parsed.host,
                        path: parsed.path,
                        scheme: parsed.scheme ?? 'https',
                        port: parsed.port ?? 443,
                        queryParameters: parsed.queryParameters,
                        fragment: parsed.fragment,
                      );
                                    },
                    onClose: () {
                      setState(() {
                        _isBookmarkPanelOpen = false;
                      });
                                },
                              ),
                      ),
              ),
            ),
          // AI Assistant Panel Overlay (only show if enabled)
          if (_isAIPanelOpen && _isAIEnabled)
            Positioned(
              right: 0,
              top: 92, // Start below tabs and navigation bar
              bottom: 0,
              child: Material(
                elevation: 8,
                child: Container(
                  width: 400,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: AIAssistantPanel(
                    currentUrl: _currentTab.currentUrl,
                    currentDomain: _currentTab.currentDomain,
                    webViewController: _currentTab.controller,
                    aiSettings: _aiSettings,
                    onClose: () {
                      setState(() {
                        _isAIPanelOpen = false;
                      });
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

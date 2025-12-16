import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:secp256k1_flutter_wrapper/secp256k1_flutter_wrapper.dart';
import 'package:window_manager/window_manager.dart';
import '../common/enums.dart';
import '../services/wallet_service.dart';
import 'master_password_screen.dart';
import '../services/kns_api_client.dart';
import '../services/kaspa_explorer_client.dart';
import '../services/kasplex_api_client.dart';
import '../services/kaspa_nft_api_client.dart';
import '../widgets/browser/certificate_info_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

class WalletInfoScreen extends StatefulWidget {
  const WalletInfoScreen({super.key});

  @override
  State<WalletInfoScreen> createState() => _WalletInfoScreenState();
}

class _WalletInfoScreenState extends State<WalletInfoScreen> with SingleTickerProviderStateMixin, WindowListener {
  String? _walletAddress;
  String? _walletPublicKey;
  bool _isLoading = true;
  bool _showMnemonic = false;
  String? _mnemonic;
  List<KNSDomain> _domains = [];
  bool _isLoadingDomains = false;
  final KNSApiClient _knsClient = KNSApiClient();
  final KaspaExplorerClient _explorerClient = KaspaExplorerClient();
  final KasplexApiClient _kasplexClient = KasplexApiClient();
  final KaspaNftApiClient _nftClient = KaspaNftApiClient();
  late TabController _tabController;
  bool _isFullScreen = true; // Track fullscreen state
  String _balance = "0.00";
  bool _isLoadingBalance = false;
  Timer? _balanceTimer; // Timer for periodic balance updates
  List<KaspaFullTransaction> _transactions = [];
  bool _isLoadingTransactions = false;
  int _transactionOffset = 0;
  static const int _transactionLimit = 20;
  bool _hasMoreTransactions = true;
  // Domain pagination
  int _domainPage = 1;
  static const int _domainPageSize = 10;
  int _totalDomainPages = 0;
  int _totalDomainItems = 0;
  bool _hasMoreDomains = false;
  // Domain DNS and Certificate cache
  Map<String, Map<String, dynamic>> _domainDnsCache = {};
  Map<String, Map<String, dynamic>> _domainCertCache = {};
  // Tokens
  List<KRC20Token> _tokens = [];
  Map<String, KRC20TokenInfo> _tokenInfoMap = {};
  bool _isLoadingTokens = false;
  String? _tokensNextPage;
  bool _hasMoreTokens = false;
  // NFTs
  List<NFTCollection> _nfts = [];
  Map<String, double> _nftFloorPrices = {};
  Map<String, String> _nftImageUrls = {}; // Cache for NFT image URLs
  bool _isLoadingNfts = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    windowManager.addListener(this);
    _checkFullScreen();
    print('ℹ️ WalletInfo: Initializing Wallet Info Screen');
    _loadWalletInfo();
  }

  @override
  void dispose() {
    _balanceTimer?.cancel();
    _tabController.dispose();
    windowManager.removeListener(this);
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

  Future<void> _loadWalletInfo() async {
    print('📥 WalletInfo: Loading wallet details...');
    final address = await WalletService.getWalletAddress();
    final publicKey = await WalletService.getWalletPublicKey();
    setState(() {
      _walletAddress = address;
      _walletPublicKey = publicKey;
      _isLoading = false;
    });
    if (address != null) {
      _loadDomains();
      _loadBalance();
      _loadTransactions();
      _loadTokens();
      _loadNfts();
    }
  }

  Future<void> _loadBalance() async {
    if (_walletAddress == null || _walletAddress!.isEmpty) return;
    
    setState(() {
      _isLoadingBalance = true;
    });

    try {
      // Only log initial balance load to avoid spamming
      if (_balance == "0.00" && !_isLoadingBalance) {
         print('💰 WalletInfo: Fetching balance for $_walletAddress');
      }
      final balanceData = await _explorerClient.getAddressBalance(_walletAddress!);
      if (mounted && balanceData != null) {
        setState(() {
          _balance = balanceData.balanceInKas.toStringAsFixed(2);
          _isLoadingBalance = false;
        });
      } else if (mounted) {
        setState(() {
          _balance = "0.00";
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      print('❌ WalletInfo: Error loading balance');
      if (mounted) {
        setState(() {
          _balance = "0.00";
          _isLoadingBalance = false;
        });
      }
    }
  }

  Future<void> _loadTransactions({bool loadMore = false}) async {
    if (_walletAddress == null || _walletAddress!.isEmpty) return;
    if (_isLoadingTransactions) return;
    
    setState(() {
      _isLoadingTransactions = true;
    });

    try {
      final offset = loadMore ? _transactionOffset : 0;
      print('📜 WalletInfo: Fetching transactions (offset: $offset)...');
      final transactions = await _explorerClient.getAddressTransactions(
        _walletAddress!,
        limit: _transactionLimit,
        offset: offset,
      );
      
      if (mounted) {
        setState(() {
          if (loadMore) {
            _transactions.addAll(transactions);
          } else {
            _transactions = transactions;
            _transactionOffset = 0;
          }
          _transactionOffset += transactions.length;
          _hasMoreTransactions = transactions.length == _transactionLimit;
          _isLoadingTransactions = false;
        });
      }
    } catch (e) {
      print('❌ WalletInfo: Error loading transactions');
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
        });
      }
    }
  }

  Future<void> _loadDomains({bool loadMore = false}) async {
    if (_walletAddress == null) return;
    if (_isLoadingDomains) return;
    
    setState(() {
      _isLoadingDomains = true;
    });

    try {
      final page = loadMore ? _domainPage + 1 : 1;
      print('🌐 WalletInfo: Fetching domains (page: $page)...');
      final result = await _knsClient.getDomainsByOwner(
        _walletAddress!,
        page: page,
        pageSize: _domainPageSize,
      );
      
      if (mounted) {
      setState(() {
          if (loadMore) {
            _domains.addAll(result.domains);
          } else {
            _domains = result.domains;
          }
          _domainPage = result.currentPage;
          _totalDomainPages = result.totalPages;
          _totalDomainItems = result.totalItems;
          _hasMoreDomains = result.hasMore;
        _isLoadingDomains = false;
      });
        
        // Load DNS and Certificate info for new domains
        for (final domain in result.domains) {
          _loadDomainDnsAndCert(domain);
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingDomains = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading domains: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadTokens({bool loadMore = false}) async {
    if (_walletAddress == null || _walletAddress!.isEmpty) return;
    if (_isLoadingTokens) return;
    
    setState(() {
      _isLoadingTokens = true;
    });

    try {
      final nextPage = loadMore ? _tokensNextPage : null;
      print('\ud83d\udcb0 WalletInfo: Fetching tokens...');
      final result = await _kasplexClient.getTokenList(_walletAddress!, next: nextPage);
      
      if (mounted) {
        final newTokens = result.tokens;
        
        setState(() {
          if (loadMore) {
            _tokens.addAll(newTokens);
          } else {
            _tokens = newTokens;
          }
          _tokensNextPage = result.next;
          _hasMoreTokens = result.hasMore;
          _isLoadingTokens = false;
        });
        
        // Load portfolio info (prices and logos) for the tokens
        if (newTokens.isNotEmpty) {
          final tickers = newTokens.map((t) => t.tick).toList();
          final portfolio = await _kasplexClient.getPortfolio(tickers);
          if (mounted) {
            setState(() {
              for (final info in portfolio) {
                _tokenInfoMap[info.ticker] = info;
              }
            });
          }
        }
      }
    } catch (e) {
      print('\u274c WalletInfo: Error loading tokens: $e');
      if (mounted) {
        setState(() {
          _isLoadingTokens = false;
        });
      }
    }
  }

  Future<void> _loadNfts() async {
    if (_walletAddress == null || _walletAddress!.isEmpty) return;
    if (_isLoadingNfts) return;
    
    setState(() {
      _isLoadingNfts = true;
    });

    try {
      print('\ud83d\uddbc\ufe0f WalletInfo: Fetching NFTs...');
      final nfts = await _nftClient.getNFTs(_walletAddress!);
      
      if (mounted) {
        setState(() {
          _nfts = nfts;
          _isLoadingNfts = false;
        });
        
        // Load floor prices for all collections
        if (nfts.isNotEmpty) {
          final tickers = nfts.map((n) => n.ticker).toList();
          final prices = await _nftClient.getFloorPrices(tickers);
          if (mounted) {
            setState(() {
              _nftFloorPrices = prices;
            });
          }
          
          // Load preview images for each collection (first token)
          for (final nft in nfts) {
            if (nft.tokenIds.isNotEmpty) {
              final firstTokenId = nft.tokenIds.first;
              final cacheKey = '${nft.ticker}/$firstTokenId';
              if (!_nftImageUrls.containsKey(cacheKey)) {
                _loadNftImage(nft.ticker, firstTokenId);
              }
            }
          }
        }
      }
    } catch (e) {
      print('\u274c WalletInfo: Error loading NFTs: $e');
      if (mounted) {
        setState(() {
          _isLoadingNfts = false;
        });
      }
    }
  }

  Future<void> _loadNftImage(String ticker, String tokenId) async {
    final cacheKey = '$ticker/$tokenId';
    if (_nftImageUrls.containsKey(cacheKey)) return;
    
    try {
      final imageUrl = await _nftClient.getNftImageUrl(ticker, tokenId);
      if (mounted && imageUrl != null) {
        setState(() {
          _nftImageUrls[cacheKey] = imageUrl;
        });
      }
    } catch (e) {
      print('\u274c Error loading NFT image for $cacheKey: $e');
    }
  }

  Future<void> _loadDomainDnsAndCert(KNSDomain domain) async {
    try {
      // Get all assets for the owner
      final allAssets = await _knsClient.getAllAssetsByOwner(domain.owner);
      
      // Extract domain name without ".kas" for matching
      final domainNameWithoutKas = domain.asset.endsWith('.kas') 
          ? domain.asset.substring(0, domain.asset.length - 4) 
          : domain.asset;
      
      // Find DNS record - new format: {"d": "domain", "ip": "127.0.0.1"}
      for (final asset in allAssets) {
        if (asset.isDomain) continue;
        
        try {
          final content = asset.asset;
          if (!content.trim().startsWith('{')) continue;
          
          final jsonContent = json.decode(content) as Map<String, dynamic>;
          
          // Check for DNS record in new format: {"d": "domain", "ip": "127.0.0.1"}
          if (jsonContent.containsKey('d') && jsonContent.containsKey('ip')) {
            final dnsDomain = jsonContent['d'] as String?;
            if (dnsDomain == domainNameWithoutKas) {
              final isConfirmed = await _explorerClient.verifyTransaction(asset.transactionId);
              if (isConfirmed) {
                setState(() {
                  _domainDnsCache[domain.asset] = jsonContent;
                });
                break;
              }
            }
          }
        } catch (e) {
          continue;
        }
      }
      
      // Find Certificate record - new format: {"d": "domain", "c": "certificate"}
      for (final asset in allAssets) {
        if (asset.isDomain) continue;
        
        try {
          final content = asset.asset;
          if (!content.trim().startsWith('{')) continue;
          
          final jsonContent = json.decode(content) as Map<String, dynamic>;
          
          // Check for Certificate in new format: {"d": "domain", "c": "certificate"}
          if (jsonContent.containsKey('d') && jsonContent.containsKey('c')) {
            final certDomain = jsonContent['d'] as String?;
            if (certDomain == domainNameWithoutKas) {
              final isConfirmed = await _explorerClient.verifyTransaction(asset.transactionId);
              if (isConfirmed) {
                // Convert to old format for compatibility with CertificateInfoDialog
                setState(() {
                  _domainCertCache[domain.asset] = {
                    'domain': domain.asset,
                    'certificate': jsonContent['c'] as String? ?? '',
                  };
                });
                break;
              }
            }
          }
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      print('❌ WalletInfo: Error loading DNS/Cert for ${domain.asset}');
    }
  }

  Future<void> _showMnemonicPhrase() async {
    // Require password confirmation before showing mnemonic
    final passwordController = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter your master password to view your recovery phrase.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text;
              if (password.isEmpty) return;
              
              final isValid = await WalletService.verifyPassword(password);
              Navigator.of(context).pop(isValid);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (verified == true) {
      final mnemonic = await WalletService.getMnemonic();
      setState(() {
        _mnemonic = mnemonic;
        _showMnemonic = true;
      });
    } else if (verified == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect password'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showQRCode() {
    if (_walletAddress == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wallet Address QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: _walletAddress!,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              _walletAddress!,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout? You will need to import your wallet again to access it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      WalletService.clearWallet();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MasterPasswordScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
        leadingWidth: 100,
        leading: Padding(
          padding: EdgeInsets.only(left: _isFullScreen ? 8 : 72), // Dynamic padding
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            splashColor: Colors.transparent, // Remove splash
            highlightColor: Colors.transparent, // Remove highlight
            hoverColor: Colors.transparent, // Remove hover
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Balance and Wallet Info Section
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Wallet Address First
                      if (_walletAddress != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Wallet Address',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.qr_code,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                  onPressed: _showQRCode,
                                  tooltip: 'Show QR Code',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    Icons.copy,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                  onPressed: () => _copyToClipboard(
                                    _walletAddress!,
                                    'Address',
                                  ),
                                  tooltip: 'Copy address',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          child: SelectableText(
                            _walletAddress!,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              color: colorScheme.onSurface,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Balance Card Below Address
                      Text(
                        'Balance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            _isLoadingBalance
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    _balance,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            Text(
                              'KAS',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Tabs
                Container(
                  color: colorScheme.surface,
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Transactions'),
                      Tab(text: 'Tokens'),
                      Tab(text: 'NFTs'),
                      Tab(text: 'Domains'),
                    ],
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                    indicatorColor: colorScheme.primary,
                  ),
                ),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActivitiesTab(colorScheme),
                      _buildTokensTab(colorScheme),
                      _buildNftsTab(colorScheme),
                      _buildDomainsTab(colorScheme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDomainsTab(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Header with Add Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                Text(
                  'My Domains',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
            ],
          ),
        ),
        // Domains List
        Expanded(
          child: _isLoadingDomains
              ? const Center(child: CircularProgressIndicator())
              : _domains.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.domain,
                              size: 64,
                              color: colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No domains registered',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Click the + button to register a new domain',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadDomains(loadMore: false),
                      child: ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                        itemCount: _domains.length + (_hasMoreDomains ? 1 : 0),
                      itemBuilder: (context, index) {
                          if (index == _domains.length) {
                            // Load more button
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: ElevatedButton(
                                  onPressed: _isLoadingDomains
                                      ? null
                                      : () => _loadDomains(loadMore: true),
                                  child: _isLoadingDomains
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Text('Load More (Page $_domainPage of $_totalDomainPages)'),
                                ),
                              ),
                            );
                          }
                          return _buildDomainCard(_domains[index], colorScheme);
                      },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildComingSoonTab(String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '$title',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokensTab(ColorScheme colorScheme) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'KRC20 Tokens',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              if (_isLoadingTokens)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        // Tokens List
        Expanded(
          child: _isLoadingTokens && _tokens.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _tokens.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.token,
                              size: 64,
                              color: colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tokens found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your KRC20 tokens will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadTokens(loadMore: false),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _tokens.length + (_hasMoreTokens ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _tokens.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: ElevatedButton(
                                  onPressed: _isLoadingTokens
                                      ? null
                                      : () => _loadTokens(loadMore: true),
                                  child: _isLoadingTokens
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Load More'),
                                ),
                              ),
                            );
                          }
                          return _buildTokenCard(_tokens[index], colorScheme);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTokenCard(KRC20Token token, ColorScheme colorScheme) {
    final info = _tokenInfoMap[token.tick];
    final balance = token.balanceFormatted;
    final price = info?.price ?? 0.0;
    final value = balance * price;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Token Logo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: info?.logo != null
                    ? Image.network(
                        info!.logo!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            token.tick.substring(0, token.tick.length > 2 ? 2 : token.tick.length),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          token.tick.substring(0, token.tick.length > 2 ? 2 : token.tick.length),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Token Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.tick,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTokenBalance(balance),
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Value
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (price > 0)
                  Text(
                    '${value.toStringAsFixed(2)} KAS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                if (price > 0)
                  Text(
                    '\$${_formatPrice(price)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTokenBalance(double balance) {
    if (balance >= 1000000000) {
      return '${(balance / 1000000000).toStringAsFixed(2)}B';
    } else if (balance >= 1000000) {
      return '${(balance / 1000000).toStringAsFixed(2)}M';
    } else if (balance >= 1000) {
      return '${(balance / 1000).toStringAsFixed(2)}K';
    } else {
      return balance.toStringAsFixed(2);
    }
  }

  String _formatPrice(double price) {
    if (price < 0.0001) {
      return price.toStringAsExponential(2);
    } else if (price < 0.01) {
      return price.toStringAsFixed(6);
    } else if (price < 1) {
      return price.toStringAsFixed(4);
    } else {
      return price.toStringAsFixed(2);
    }
  }

  Widget _buildNftsTab(ColorScheme colorScheme) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NFT Collections',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              if (_isLoadingNfts)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        // NFT Collections List
        Expanded(
          child: _isLoadingNfts && _nfts.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _nfts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.collections,
                              size: 64,
                              color: colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No NFTs found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your NFT collections will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadNfts();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _nfts.length,
                        itemBuilder: (context, index) {
                          return _buildNftCollectionCard(_nfts[index], colorScheme);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildNftImage(String ticker, String tokenId, double? size, ColorScheme colorScheme) {
    final cacheKey = '$ticker/$tokenId';
    final imageUrl = _nftImageUrls[cacheKey];
    
    if (imageUrl == null) {
      // Image not loaded yet, show loading indicator
      return Center(
        child: SizedBox(
          width: size != null ? size / 2 : 24,
          height: size != null ? size / 2 : 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
      );
    }
    
    return Image.network(
      imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: size != null ? size / 2 : 24,
            height: size != null ? size / 2 : 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Center(
        child: Icon(
          Icons.image,
          size: size != null ? size / 2 : 24,
          color: colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildNftCollectionCard(NFTCollection collection, ColorScheme colorScheme) {
    final floorPrice = _nftFloorPrices[collection.ticker];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showNftCollectionDetails(collection, colorScheme),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // NFT Preview (first token image)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildNftImage(
                        collection.ticker,
                        collection.tokenIds.first,
                        64,
                        colorScheme,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Collection Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.ticker,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${collection.count} ${collection.count == 1 ? 'item' : 'items'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Floor Price
                  if (floorPrice != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Floor',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        Text(
                          '${floorPrice.toStringAsFixed(0)} KAS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNftCollectionDetails(NFTCollection collection, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(collection.ticker),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: collection.tokenIds.length,
            itemBuilder: (context, index) {
              final tokenId = collection.tokenIds[index];
              // Load image if not cached yet
              final cacheKey = '${collection.ticker}/$tokenId';
              if (!_nftImageUrls.containsKey(cacheKey)) {
                _loadNftImage(collection.ticker, tokenId);
              }
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildNftImage(
                        collection.ticker,
                        tokenId,
                        null, // Full size
                        colorScheme,
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$tokenId',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainCard(KNSDomain domain, ColorScheme colorScheme) {
    final hasDns = _domainDnsCache.containsKey(domain.asset);
    final hasCert = _domainCertCache.containsKey(domain.asset);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDomainInfo(domain, colorScheme),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
              children: [
                if (domain.isVerifiedDomain)
                  Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Icon(Icons.verified, color: colorScheme.primary, size: 20),
                  ),
                        Expanded(
                          child: Text(
                            domain.asset,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
            ),
          ],
        ),
                  ),
                  IconButton(
          icon: const Icon(Icons.info_outline),
                    onPressed: () => _showDomainInfo(domain, colorScheme),
          tooltip: 'View domain details',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Created: ${_formatDate(domain.creationBlockTime)}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusChip(
                    'DNS',
                    hasDns,
                    Icons.dns,
                    colorScheme,
                    () => _showDnsInfo(domain, colorScheme),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    'Certificate',
                    hasCert,
                    Icons.lock,
                    colorScheme,
                    () => _showCertificateInfo(domain, colorScheme),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    String label,
    bool available,
    IconData icon,
    ColorScheme colorScheme,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: available ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: available
              ? colorScheme.primaryContainer.withOpacity(0.3)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: available
                ? colorScheme.primary.withOpacity(0.5)
                : colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: available
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: available
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            if (available) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showDnsInfo(KNSDomain domain, ColorScheme colorScheme) async {
    final dnsData = _domainDnsCache[domain.asset];
    if (dnsData == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.dns, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text('DNS Records: ${domain.asset}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDnsRecordsView(dnsData, domain.asset, colorScheme),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDnsRecordsView(Map<String, dynamic> dnsData, String domain, ColorScheme colorScheme) {
    // New simplified format: {"d": "domain", "ip": "127.0.0.1"}
    if (dnsData.containsKey('d') && dnsData.containsKey('ip')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Domain', dnsData['d'] as String? ?? '', colorScheme),
          const SizedBox(height: 12),
          _buildInfoRow('IP Address', dnsData['ip'] as String? ?? '', colorScheme),
        ],
      );
    }
    
    return Text(
      'No DNS records found',
      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
    );
  }

  Future<void> _showCertificateInfo(KNSDomain domain, ColorScheme colorScheme) async {
    final certData = _domainCertCache[domain.asset];
    if (certData == null) return;

    // Import the certificate dialog widget
    showDialog(
      context: context,
      builder: (context) => CertificateInfoDialog(certificateData: certData),
    );
  }

  Future<void> _showDomainInfo(KNSDomain domain, ColorScheme colorScheme) async {
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Domain: ${domain.asset}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Domain', domain.asset, colorScheme),
              const SizedBox(height: 12),
              _buildInfoRow('Asset ID', domain.assetId, colorScheme),
              const SizedBox(height: 12),
              _buildInfoRow('Owner', domain.owner, colorScheme),
              const SizedBox(height: 12),
              _buildInfoRow('Created', _formatDate(domain.creationBlockTime), colorScheme),
              const SizedBox(height: 12),
              _buildInfoRow('Transaction ID', domain.transactionId, colorScheme),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    domain.isVerifiedDomain ? Icons.check_circle : Icons.cancel,
                    color: domain.isVerifiedDomain ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    domain.isVerifiedDomain ? 'Verified Domain' : 'Not Verified',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: domain.isVerifiedDomain ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildActivitiesTab(ColorScheme colorScheme) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              if (_isLoadingTransactions)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        // Transactions List
        Expanded(
          child: _isLoadingTransactions && _transactions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your transaction history will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadTransactions(loadMore: false),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _transactions.length + (_hasMoreTransactions ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _transactions.length) {
                            // Load more button
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: ElevatedButton(
                                  onPressed: _isLoadingTransactions
                                      ? null
                                      : () => _loadTransactions(loadMore: true),
                                  child: _isLoadingTransactions
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Load More'),
                                ),
                              ),
                            );
                          }
                          return _buildTransactionCard(_transactions[index], colorScheme);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(KaspaFullTransaction transaction, ColorScheme colorScheme) {
    // Calculate net amount for this address
    double netAmount = 0.0;
    for (final output in transaction.outputs) {
      if (output.scriptPublicKeyAddress == _walletAddress) {
        netAmount += output.amountInKas;
      }
    }
    for (final input in transaction.inputs) {
      // Inputs are spent, so subtract (we'd need to check previous outputs for exact amount)
      // For simplicity, we'll show outputs only
    }

    final isReceived = netAmount > 0;
    final date = DateTime.fromMillisecondsSinceEpoch(transaction.blockTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction, colorScheme),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isReceived ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isReceived ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isReceived ? 'Received' : 'Sent',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isReceived ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${netAmount.abs().toStringAsFixed(8)} KAS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Transaction ID: ${transaction.transactionId.substring(0, 16)}...',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDateTime(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        transaction.isConfirmed ? Icons.check_circle : Icons.pending,
                        size: 16,
                        color: transaction.isConfirmed ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        transaction.isConfirmed ? 'Confirmed' : 'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          color: transaction.isConfirmed ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showTransactionDetails(KaspaFullTransaction transaction, ColorScheme colorScheme) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transaction Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Transaction ID', transaction.transactionId, colorScheme),
              const SizedBox(height: 12),
              _buildInfoRow('Hash', transaction.hash, colorScheme),
              const SizedBox(height: 12),
              _buildInfoRow('Status', transaction.isConfirmed ? 'Confirmed' : 'Pending', colorScheme),
              const SizedBox(height: 12),
              _buildInfoRow('Block Time', _formatDateTime(DateTime.fromMillisecondsSinceEpoch(transaction.blockTime)), colorScheme),
              const SizedBox(height: 12),
              _buildInfoRow('Inputs', '${transaction.inputs.length}', colorScheme),
              const SizedBox(height: 12),
              _buildInfoRow('Outputs', '${transaction.outputs.length}', colorScheme),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

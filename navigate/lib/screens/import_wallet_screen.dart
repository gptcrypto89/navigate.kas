import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hd_wallet/hd_wallet.dart';
import 'package:window_manager/window_manager.dart';
import '../common/enums.dart';
import '../common/constants.dart';
import '../services/wallet_service.dart';
import '../models/wallet_models.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> with WindowListener {
  final TextEditingController _mnemonicController = TextEditingController();
  final TextEditingController _importPassphraseController = TextEditingController();
  WalletProvider _importWalletProvider = WalletProvider.kasware;
  bool _showImportMnemonic = false;
  bool _showImportPassphrase = false;
  String? _importAddressPreview;
  bool _isImporting = false;
  bool _isFullScreen = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkFullScreen();
    print('📥 Wallet: Initializing Import Wallet Screen');
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _mnemonicController.dispose();
    _importPassphraseController.dispose();
    super.dispose();
  }

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

  Future<void> _updateImportAddressPreview() async {
    final mnemonic = _mnemonicController.text.trim();
    if (mnemonic.isEmpty) {
      setState(() {
        _importAddressPreview = null;
      });
      return;
    }
    
    try {
      final address = await WalletService.generateAddressPreview(
        mnemonic,
        passphrase: _importPassphraseController.text.trim(),
        provider: _importWalletProvider,
      );
      
      if (mounted) {
        setState(() {
          _importAddressPreview = address;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importAddressPreview = null;
        });
      }
    }
  }

  Future<void> _importWallet() async {
    final mnemonic = _mnemonicController.text.trim();
    
    if (mnemonic.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your mnemonic phrase';
      });
      return;
    }

    if (!Mnemonic.validate(mnemonic)) {
      setState(() {
        _errorMessage = 'Invalid mnemonic phrase. Please check and try again.';
      });
      return;
    }

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    print('⚡ Wallet: Importing wallet from mnemonic...');
    try {
      final account = await WalletService.importWallet(
        mnemonic,
        passphrase: _importPassphraseController.text.trim(),
        provider: _importWalletProvider,
      );
      
      final metadata = await _showWalletMetadataDialog();
      if (metadata == null) {
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final encryptedMnemonic = WalletService.encryptMnemonic(mnemonic);
      final passphrase = _importPassphraseController.text.trim();
      final encryptedPassphrase = passphrase.isNotEmpty 
          ? WalletService.encryptMnemonic(passphrase)
          : null;
      
      final wallet = SavedWallet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: metadata['name'] as String,
        address: account.address,
        publicKey: account.publicKeyHex,
        encryptedMnemonic: encryptedMnemonic,
        encryptedPassphrase: encryptedPassphrase,
        walletProvider: _importWalletProvider,
        avatarEmoji: metadata['avatar'] as String?,
        createdAt: DateTime.now(),
      );

      await WalletService.saveWalletToList(wallet);

      if (mounted) {
        print('✅ Wallet: Wallet imported and saved successfully');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('❌ Wallet: Error importing wallet');
      setState(() {
        _errorMessage = 'Error importing wallet: $e';
        _isImporting = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _showWalletMetadataDialog() async {
    final nameController = TextEditingController();
    String? selectedEmoji;

    final emojis = ['🚀', '💎', '⭐', '🔥', '💰', '🎯', '🌟', '🏆', '💼', '🎨'];

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: colorScheme.surface,
            title: Text(
              DIALOG_WALLET_SETTINGS_TITLE,
              style: TextStyle(color: colorScheme.onSurface),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: DIALOG_WALLET_NAME_LABEL,
                        hintText: DIALOG_WALLET_NAME_HINT,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      DIALOG_AVATAR_LABEL,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: emojis.map((emoji) {
                        final isSelected = selectedEmoji == emoji;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedEmoji = isSelected ? null : emoji;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary.withOpacity(0.2)
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outline.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(emoji, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(DIALOG_BTN_CANCEL),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isEmpty) {
                    return;
                  }
                  Navigator.pop(context, {
                    'name': nameController.text,
                    'avatar': selectedEmoji,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(DIALOG_BTN_SAVE),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(IMPORT_WALLET_TITLE),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
        elevation: 0,
        leadingWidth: 100,
        leading: Padding(
          padding: EdgeInsets.only(left: _isFullScreen ? 8 : 72),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.file_download_outlined,
              size: 80,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              IMPORT_WALLET_HEADER,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              IMPORT_WALLET_SUBHEADER,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text(
              CREATE_WALLET_PROVIDER_LABEL,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProviderOption(
                      WalletProvider.kasware,
              WALLET_PROVIDER_KASWARE,
              WALLET_DESC_KASWARE,
                      colorScheme,
                    ),
                    const Divider(),
                    _buildProviderOption(
                      WalletProvider.kaspium,
              WALLET_PROVIDER_KASPIUM,
              WALLET_DESC_KASPIUM,
                      colorScheme,
                    ),
                    const Divider(),
                    _buildProviderOption(
                      WalletProvider.ledger,
              WALLET_PROVIDER_LEDGER,
              WALLET_DESC_LEDGER,
                      colorScheme,
                    ),
                    const Divider(),
                    _buildProviderOption(
                      WalletProvider.tangem,
              WALLET_PROVIDER_TANGEM,
              WALLET_DESC_TANGEM,
                      colorScheme,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  IMPORT_WALLET_PHRASE_LABEL,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(_showImportMnemonic ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showImportMnemonic = !_showImportMnemonic;
                    });
                  },
                  tooltip: _showImportMnemonic ? 'Hide' : 'Show',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _mnemonicController,
                obscureText: !_showImportMnemonic,
                onChanged: (_) => _updateImportAddressPreview(),
                decoration: InputDecoration(
                  labelText: IMPORT_WALLET_PHRASE_LABEL,
                  hintText: IMPORT_WALLET_PHRASE_HINT,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.all(20),
                ),
                maxLines: 5,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  CREATE_WALLET_PASSPHRASE_LABEL,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(_showImportPassphrase ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showImportPassphrase = !_showImportPassphrase;
                    });
                  },
                  tooltip: _showImportPassphrase ? 'Hide' : 'Show',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _importPassphraseController,
              obscureText: !_showImportPassphrase,
              onChanged: (_) => _updateImportAddressPreview(),
              decoration: InputDecoration(
                hintText: CREATE_WALLET_PASSPHRASE_HINT,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              IMPORT_WALLET_PASSPHRASE_NOTE,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            if (_importAddressPreview != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Wallet Address',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _importAddressPreview!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(MSG_ADDRESS_COPIED),
                          backgroundColor: colorScheme.primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Copy',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        _importAddressPreview!,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            ElevatedButton(
              onPressed: _isImporting ? null : _importWallet,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isImporting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                      ),
                    )
                  : const Text(IMPORT_WALLET_BTN_IMPORT),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderOption(
    WalletProvider provider,
    String name,
    String description,
    ColorScheme colorScheme,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _importWalletProvider = provider;
        });
        _updateImportAddressPreview();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Radio<WalletProvider>(
              value: provider,
              groupValue: _importWalletProvider,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _importWalletProvider = value;
                  });
                  _updateImportAddressPreview();
                }
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


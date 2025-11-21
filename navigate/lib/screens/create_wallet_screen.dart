import 'package:hd_wallet/hd_wallet.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/enums.dart';
import '../common/constants.dart';
import '../services/wallet_service.dart';
import '../models/wallet_models.dart';
import '../widgets/common/error_message.dart';
import '../widgets/common/warning_message.dart';
import '../widgets/wallet/wallet_provider_selection.dart';
import '../widgets/wallet/mnemonic_display.dart';
import '../widgets/wallet/wallet_address_display.dart';
import '../widgets/common/password_text_field.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> with WindowListener {
  // Wallet creation state
  String? _generatedMnemonic;
  String? _walletAddress;
  String? _walletPublicKey;
  bool _hasConfirmedBackup = false;
  final TextEditingController _passphraseController = TextEditingController();
  WalletProvider _walletProvider = WalletProvider.kasware;
  bool _showMnemonic = false;
  bool _showPassphrase = false;
  bool _isGeneratingAddress = false;
  bool _isFullScreen = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkFullScreen();
    print('🆕 Wallet: Initializing Create Wallet Screen');
    _createWallet();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _passphraseController.dispose();
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

  Future<void> _createWallet() async {
    setState(() {
      _errorMessage = null;
      _passphraseController.clear();
      _walletProvider = WalletProvider.kasware;
      _showMnemonic = false;
      _showPassphrase = false;
    });

    print('⚡ Wallet: Generating new wallet...');
    try {
      final result = await WalletService.createWallet(
        passphrase: _passphraseController.text.trim(),
        provider: _walletProvider,
      );
      
      setState(() {
        _generatedMnemonic = result.mnemonic;
        _walletAddress = result.account.address;
        _walletPublicKey = result.account.publicKeyHex;
      });

      _updateAddressPreview();
      print('✅ Wallet: New wallet generated successfully');
    } catch (e) {
      print('❌ Wallet: Error generating wallet');
      setState(() {
        _errorMessage = 'Error creating wallet: $e';
      });
    }
  }

  Future<void> _regenerateWallet() async {
    final wasMnemonicVisible = _showMnemonic;
    final wasPassphraseVisible = _showPassphrase;
    
    setState(() {
      _errorMessage = null;
      _hasConfirmedBackup = false;
    });
    await _createWallet();
    
    setState(() {
      _showMnemonic = wasMnemonicVisible;
      _showPassphrase = wasPassphraseVisible;
    });
  }

  Future<void> _updateAddressPreview() async {
    if (_generatedMnemonic == null || _generatedMnemonic!.isEmpty) return;
    
    setState(() {
      _isGeneratingAddress = true;
    });

    try {
      final address = await WalletService.generateAddressPreview(
        _generatedMnemonic!,
        passphrase: _passphraseController.text.trim(),
        provider: _walletProvider,
      );
      
      if (mounted) {
        setState(() {
          _walletAddress = address;
          _isGeneratingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingAddress = false;
        });
      }
    }
  }

  Future<void> _saveCreatedWallet() async {
    if (!_hasConfirmedBackup) {
      setState(() {
        _errorMessage = 'Please confirm that you have saved your recovery phrase.';
      });
      return;
    }

    final metadata = await _showWalletMetadataDialog();
    if (metadata == null) return;

    print('💾 Wallet: Saving new wallet...');
    try {
      final encryptedMnemonic = WalletService.encryptMnemonic(_generatedMnemonic!);
      final passphrase = _passphraseController.text.trim();
      final encryptedPassphrase = passphrase.isNotEmpty 
          ? WalletService.encryptMnemonic(passphrase)
          : null;
      
      final wallet = SavedWallet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: metadata['name'] as String,
        address: _walletAddress!,
        publicKey: _walletPublicKey!,
        encryptedMnemonic: encryptedMnemonic,
        encryptedPassphrase: encryptedPassphrase,
        walletProvider: _walletProvider,
        avatarEmoji: metadata['avatar'] as String?,
        createdAt: DateTime.now(),
      );

      await WalletService.saveWalletToList(wallet);
      
      if (mounted) {
        print('✅ Wallet: Wallet saved successfully');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('❌ Wallet: Error saving wallet');
      setState(() {
        _errorMessage = 'Error saving wallet: $e';
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
        title: const Text(CREATE_WALLET_TITLE),
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
            const WarningMessage(
              title: CREATE_WALLET_WARNING_TITLE,
              message: CREATE_WALLET_WARNING_MSG,
            ),
            const SizedBox(height: 24),
            Text(
              CREATE_WALLET_PROVIDER_LABEL,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            WalletProviderSelection(
              selectedProvider: _walletProvider,
              onProviderChanged: (provider) {
                setState(() {
                  _walletProvider = provider;
                });
                _updateAddressPreview();
              },
            ),
            const SizedBox(height: 24),
            if (_generatedMnemonic != null)
              MnemonicDisplay(
                mnemonic: _generatedMnemonic!,
                isVisible: _showMnemonic,
                onToggleVisibility: () {
                  setState(() {
                    _showMnemonic = !_showMnemonic;
                  });
                },
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: _generatedMnemonic!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(MSG_SEED_COPIED),
                      backgroundColor: colorScheme.primary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                onRegenerate: _regenerateWallet,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showPassphrase && _passphraseController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _passphraseController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(MSG_PASSPHRASE_COPIED),
                              backgroundColor: colorScheme.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        tooltip: 'Copy',
                      ),
                    IconButton(
                      icon: Icon(_showPassphrase ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _showPassphrase = !_showPassphrase;
                        });
                      },
                      tooltip: _showPassphrase ? 'Hide' : 'Show',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            PasswordTextField(
              controller: _passphraseController,
              labelText: 'Passphrase',
              hintText: CREATE_WALLET_PASSPHRASE_HINT,
              enabled: true,
              onChanged: (_) => _updateAddressPreview(),
            ),
            const SizedBox(height: 8),
            Text(
              CREATE_WALLET_PASSPHRASE_WARNING,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            WalletAddressDisplay(
              address: _walletAddress,
              isGenerating: _isGeneratingAddress,
              onCopy: () {
                if (_walletAddress != null) {
                  Clipboard.setData(ClipboardData(text: _walletAddress!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(MSG_ADDRESS_COPIED),
                      backgroundColor: colorScheme.primary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _hasConfirmedBackup,
                    onChanged: (value) {
                      setState(() {
                        _hasConfirmedBackup = value ?? false;
                        _errorMessage = null;
                      });
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CREATE_WALLET_CONFIRM_BACKUP,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CREATE_WALLET_CONFIRM_UNDERSTAND,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorMessage(message: _errorMessage!),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveCreatedWallet,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(CREATE_WALLET_BTN_CONTINUE),
            ),
          ],
        ),
      ),
    );
  }
}

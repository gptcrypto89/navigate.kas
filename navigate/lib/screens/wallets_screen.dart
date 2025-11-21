import 'package:flutter/material.dart';
import 'package:hd_wallet/hd_wallet.dart';
import 'package:window_manager/window_manager.dart';
import '../common/enums.dart';
import '../common/constants.dart';
import '../services/wallet_service.dart';
import '../models/wallet_models.dart';
import 'master_password_screen.dart';
import 'create_wallet_screen.dart';
import 'import_wallet_screen.dart';
import '../widgets/wallet/wallet_card.dart';
import '../widgets/master_password/master_password_dialog.dart';
import '../widgets/common/confirmation_dialog.dart';
import '../widgets/wallet/wallet_metadata_dialog.dart';
import '../widgets/wallet/wallet_secrets_dialog.dart';
import '../widgets/common/error_message.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> with WindowListener {
  List<SavedWallet> _savedWallets = [];
  bool _isLoading = true;
  bool _isFullScreen = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkFullScreen();
    print('👛 Wallets: Initializing Wallets Screen');
    _loadSavedWallets();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
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

  Future<void> _loadSavedWallets() async {
    print('📂 Wallets: Loading saved wallets...');
    try {
      final wallets = await WalletService.getSavedWallets();
      setState(() {
        _savedWallets = wallets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _savedWallets = [];
        _isLoading = false;
        _errorMessage = 'Error loading wallets: $e';
      });
    }
  }

  Future<void> _unlockWallet(SavedWallet wallet) async {
    print('🔓 Wallets: Unlocking wallet ${wallet.name}...');
    try {
      await WalletService.setActiveWallet(wallet);
      if (mounted) {
        print('✅ Wallets: Wallet unlocked successfully');
        Navigator.of(context).pushReplacementNamed('/browser');
      }
    } catch (e) {
      print('❌ Wallets: Error unlocking wallet');
      final colorScheme = Theme.of(context).colorScheme;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unlocking wallet: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _editWallet(SavedWallet wallet) async {
    final metadata = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WalletMetadataDialog(
        initialName: wallet.name,
        initialAvatar: wallet.avatarEmoji,
      ),
    );

    if (metadata == null) return;

    try {
      final updatedWallet = SavedWallet(
        id: wallet.id,
        name: metadata['name'] as String,
        address: wallet.address,
        publicKey: wallet.publicKey,
        encryptedMnemonic: wallet.encryptedMnemonic,
        encryptedPassphrase: wallet.encryptedPassphrase,
        walletProvider: wallet.walletProvider,
        avatarEmoji: metadata['avatar'] as String?,
        createdAt: wallet.createdAt,
      );

      await WalletService.updateWallet(updatedWallet);
      print('✅ Wallets: Wallet updated successfully');
      _loadSavedWallets();
      
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Wallet updated successfully'),
            backgroundColor: colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      final colorScheme = Theme.of(context).colorScheme;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating wallet: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showWalletSecrets(SavedWallet wallet) async {
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const MasterPasswordDialog(),
    );

    if (password == null) return;
    
    WalletService.setMasterPassword(password);
    
    final colorScheme = Theme.of(context).colorScheme;
    
    String? mnemonic;
    String? passphrase;
    
    try {
      mnemonic = WalletService.decryptMnemonic(wallet.encryptedMnemonic);
      if (wallet.encryptedPassphrase != null && wallet.encryptedPassphrase!.isNotEmpty) {
        passphrase = WalletService.decryptMnemonic(wallet.encryptedPassphrase!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error decrypting wallet: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => WalletSecretsDialog(
        mnemonic: mnemonic!,
        passphrase: passphrase,
      ),
    );
  }

  void _logout() {
    WalletService.clearWallet();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MasterPasswordScreen()),
      );
    }
  }

  Future<void> _deleteWallet(SavedWallet wallet) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Delete Wallet',
        content: 'Are you sure you want to delete "${wallet.name}"? This action cannot be undone.',
        confirmText: 'Delete',
        confirmTextColor: colorScheme.error,
      ),
    );

    if (confirmed == true) {
      try {
        print('🗑️ Wallets: Deleting wallet ${wallet.name}...');
        await WalletService.deleteWallet(wallet.id);
        print('✅ Wallets: Wallet deleted successfully');
        _loadSavedWallets();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting wallet: $e'),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(WALLET_SCREEN_TITLE),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_savedWallets.isNotEmpty) ...[
                    Text(
                      WALLET_YOUR_WALLETS_TITLE,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._savedWallets.map((wallet) => WalletCard(
                      wallet: wallet,
                      onUnlock: () => _unlockWallet(wallet),
                      onEdit: () => _editWallet(wallet),
                      onShowSeed: () => _showWalletSecrets(wallet),
                      onDelete: () => _deleteWallet(wallet),
                    )),
                    const SizedBox(height: 24),
                    Divider(color: colorScheme.outline.withOpacity(0.2)),
                    const SizedBox(height: 24),
                  ],
                  if (_savedWallets.isEmpty) ...[
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 80,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      WALLET_WELCOME_TITLE,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      WALLET_WELCOME_SUBTITLE,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                  ],
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const CreateWalletScreen()),
                      ).then((_) => _loadSavedWallets());
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text(WALLET_BTN_CREATE_NEW),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ImportWalletScreen()),
                      ).then((_) => _loadSavedWallets());
                    },
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text(WALLET_BTN_IMPORT_EXISTING),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: colorScheme.primary),
                      foregroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _logout,
                    icon: Icon(Icons.logout, color: colorScheme.error),
                    label: Text(
                      WALLET_BTN_LOGOUT,
                      style: TextStyle(color: colorScheme.error),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 24),
                    ErrorMessage(message: _errorMessage!),
                  ],
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/encrypted_storage_service.dart';
import 'wallets_screen.dart';
import 'browser_screen.dart';
import '../widgets/common/password_text_field.dart';
import '../widgets/common/loading_button.dart';
import '../widgets/common/error_message.dart';

/// Screen for setting up or entering master password
class MasterPasswordScreen extends StatefulWidget {
  const MasterPasswordScreen({super.key});

  @override
  State<MasterPasswordScreen> createState() => _MasterPasswordScreenState();
}

class _MasterPasswordScreenState extends State<MasterPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  
  bool _isFirstTime = false;
  bool _isChangingPassword = false;
  bool _isLoading = true;
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkStorage();
    print('🔐 Auth: Initializing Master Password Screen');
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkStorage() async {
    final hasStorage = await EncryptedStorage().hasPassword();
    setState(() {
      _isFirstTime = !hasStorage;
      _isLoading = false;
    });
  }

  Future<void> _setupMasterPassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Password cannot be empty';
      });
      return;
    }

    if (password.length < 8) {
      setState(() {
        _errorMessage = 'Password must be at least 8 characters long';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    print('🔐 Auth: Setting up new master password...');
    try {
      await WalletService.initializeStorage(password);
      // Set master password in WalletService so it can be used for wallet operations
      WalletService.setMasterPassword(password);
      
      if (mounted) {
        print('✅ Auth: Master password setup successful');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WalletsScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Error setting up password: $e';
      });
    }
  }

  Future<void> _login() async {
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    print('🔐 Auth: Verifying master password...');
    try {
      final isValid = await WalletService.verifyPassword(password);
      
      if (!isValid) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Invalid password. Please try again.';
        });
        print('❌ Auth: Invalid password attempt');
        return;
      }
      print('✅ Auth: Password verified successfully');

      // Set master password in WalletService so it can be used for wallet operations
      WalletService.setMasterPassword(password);

      // Check if there are any wallets
      final wallets = await WalletService.getSavedWallets();
      
      if (mounted) {
        if (wallets.isEmpty) {
          // No wallets, go to setup
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const WalletsScreen()),
          );
        } else {
          // Has wallets, check if one is active
          final isInitialized = WalletService.isWalletInitialized();
          if (isInitialized) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const BrowserPage()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const WalletsScreen()),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Error verifying password: $e';
      });
    }
  }

  Future<void> _changePassword() async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmNewPassword = _confirmNewPasswordController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmNewPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
      });
      return;
    }

    if (newPassword.length < 8) {
      setState(() {
        _errorMessage = 'New password must be at least 8 characters long';
      });
      return;
    }

    if (newPassword != confirmNewPassword) {
      setState(() {
        _errorMessage = 'New passwords do not match';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    print('🔐 Auth: Changing master password...');
    try {
      await WalletService.changePassword(oldPassword, newPassword);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        print('✅ Auth: Password changed successfully');
        
        setState(() {
          _isChangingPassword = false;
          _oldPasswordController.clear();
          _newPasswordController.clear();
          _confirmNewPasswordController.clear();
        });
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Error changing password: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: _isChangingPassword
                        ? _buildChangePasswordForm(colorScheme)
                        : _isFirstTime
                            ? _buildSetupForm(colorScheme)
                            : _buildLoginForm(colorScheme),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupForm(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.lock_outline,
          size: 64,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Set Master Password',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Create a secure password to protect your wallets and data',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        PasswordTextField(
          controller: _passwordController,
          labelText: 'Master Password',
          hintText: 'Enter a secure password',
          enabled: !_isVerifying,
          onSubmitted: (_) => _setupMasterPassword(),
        ),
        const SizedBox(height: 16),
        PasswordTextField(
          controller: _confirmPasswordController,
          labelText: 'Confirm Password',
          hintText: 'Re-enter your password',
          enabled: !_isVerifying,
          onSubmitted: (_) => _setupMasterPassword(),
        ),
        const SizedBox(height: 8),
        Text(
          'Password must be at least 8 characters long',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          ErrorMessage(message: _errorMessage!),
        ],
        const SizedBox(height: 24),
        LoadingButton(
          isLoading: _isVerifying,
          onPressed: _isVerifying ? null : _setupMasterPassword,
          text: 'Continue',
        ),
      ],
    );
  }

  Widget _buildLoginForm(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.lock,
          size: 64,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Enter Master Password',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your master password to access your wallets',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        PasswordTextField(
          controller: _passwordController,
          labelText: 'Master Password',
          hintText: 'Enter your password',
          enabled: !_isVerifying,
          autofocus: true,
          onSubmitted: (_) => _login(),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          ErrorMessage(message: _errorMessage!),
        ],
        const SizedBox(height: 24),
        LoadingButton(
          isLoading: _isVerifying,
          onPressed: _isVerifying ? null : _login,
          text: 'Unlock',
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isVerifying
              ? null
              : () {
                  setState(() {
                    _isChangingPassword = true;
                    _errorMessage = null;
                  });
                },
          child: Text(
            'Change Password',
            style: TextStyle(color: colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildChangePasswordForm(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _isVerifying
                  ? null
                  : () {
                      setState(() {
                        _isChangingPassword = false;
                        _errorMessage = null;
                        _oldPasswordController.clear();
                        _newPasswordController.clear();
                        _confirmNewPasswordController.clear();
                      });
                    },
            ),
            Expanded(
              child: Text(
                'Change Master Password',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 48), // Balance the back button
          ],
        ),
        const SizedBox(height: 24),
        PasswordTextField(
          controller: _oldPasswordController,
          labelText: 'Current Password',
          hintText: 'Enter your current password',
          enabled: !_isVerifying,
          autofocus: true,
        ),
        const SizedBox(height: 16),
        PasswordTextField(
          controller: _newPasswordController,
          labelText: 'New Password',
          hintText: 'Enter new password',
          enabled: !_isVerifying,
        ),
        const SizedBox(height: 16),
        PasswordTextField(
          controller: _confirmNewPasswordController,
          labelText: 'Confirm New Password',
          hintText: 'Re-enter new password',
          enabled: !_isVerifying,
          onSubmitted: (_) => _changePassword(),
        ),
        const SizedBox(height: 8),
        Text(
          'New password must be at least 8 characters long',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          ErrorMessage(message: _errorMessage!),
        ],
        const SizedBox(height: 24),
        LoadingButton(
          isLoading: _isVerifying,
          onPressed: _isVerifying ? null : _changePassword,
          text: 'Change Password',
        ),
      ],
    );
  }
}

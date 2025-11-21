import 'package:flutter/material.dart';

class WalletSecretsDialog extends StatefulWidget {
  final String mnemonic;
  final String? passphrase;

  const WalletSecretsDialog({
    super.key,
    required this.mnemonic,
    this.passphrase,
  });

  @override
  State<WalletSecretsDialog> createState() => _WalletSecretsDialogState();
}

class _WalletSecretsDialogState extends State<WalletSecretsDialog> {
  bool _showMnemonic = false;
  bool _showPassphrase = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      title: Text(
        'Wallet Secrets',
        style: TextStyle(color: colorScheme.onSurface),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Seed Phrase',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(_showMnemonic ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _showMnemonic = !_showMnemonic;
                      });
                    },
                    tooltip: _showMnemonic ? 'Hide' : 'Show',
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
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: SelectableText(
                  _showMnemonic ? widget.mnemonic : '• • • • • • • • • • • • • • • • • • • • • • • •',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    fontFamily: 'monospace',
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (widget.passphrase != null && widget.passphrase!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Passphrase',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
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
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: SelectableText(
                    _showPassphrase ? widget.passphrase! : '• • • • • • • • • • • • • • • • • • • • • • • •',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontFamily: 'monospace',
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Keep this information secure. Never share it with anyone.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}


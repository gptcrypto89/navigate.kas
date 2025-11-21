import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WalletAddressDisplay extends StatelessWidget {
  final String? address;
  final bool isGenerating;
  final VoidCallback onCopy;

  const WalletAddressDisplay({
    super.key,
    this.address,
    this.isGenerating = false,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            if (address != null && !isGenerating)
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: onCopy,
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
              if (isGenerating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.account_balance_wallet, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: SelectableText(
                  address ?? 'Generating...',
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
      ],
    );
  }
}


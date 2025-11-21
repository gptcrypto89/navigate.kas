import 'package:flutter/material.dart';
import '../../common/enums.dart';
import '../../common/constants.dart';
import '../../models/wallet_models.dart';

class WalletProviderSelection extends StatelessWidget {
  final WalletProvider selectedProvider;
  final ValueChanged<WalletProvider> onProviderChanged;

  const WalletProviderSelection({
    super.key,
    required this.selectedProvider,
    required this.onProviderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
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
    );
  }

  Widget _buildProviderOption(
    WalletProvider provider,
    String name,
    String description,
    ColorScheme colorScheme,
  ) {
    return InkWell(
      onTap: () => onProviderChanged(provider),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Radio<WalletProvider>(
              value: provider,
              groupValue: selectedProvider,
              onChanged: (value) {
                if (value != null) {
                  onProviderChanged(value);
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


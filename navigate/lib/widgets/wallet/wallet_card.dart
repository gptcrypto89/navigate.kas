import 'package:flutter/material.dart';
import 'package:hd_wallet/hd_wallet.dart';
import '../../common/enums.dart';
import '../../common/constants.dart';
import '../../models/wallet_models.dart';

class WalletCard extends StatelessWidget {
  final SavedWallet wallet;
  final VoidCallback onUnlock;
  final VoidCallback onEdit;
  final VoidCallback onShowSeed;
  final VoidCallback onDelete;

  const WalletCard({
    super.key,
    required this.wallet,
    required this.onUnlock,
    required this.onEdit,
    required this.onShowSeed,
    required this.onDelete,
  });

  String _getProviderName(WalletProvider provider) {
    switch (provider) {
      case WalletProvider.kasware:
        return WALLET_PROVIDER_KASWARE;
      case WalletProvider.kaspium:
        return WALLET_PROVIDER_KASPIUM;
      case WalletProvider.ledger:
        return WALLET_PROVIDER_LEDGER;
      case WalletProvider.tangem:
        return WALLET_PROVIDER_TANGEM;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPassphrase = wallet.encryptedPassphrase != null && wallet.encryptedPassphrase!.isNotEmpty;
    final providerName = _getProviderName(wallet.walletProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: onUnlock,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    wallet.avatarEmoji ?? wallet.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wallet.address.length > 24
                          ? '${wallet.address.substring(0, 12)}...${wallet.address.substring(wallet.address.length - 8)}'
                          : wallet.address,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          label: Text(
                            providerName,
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
                          ),
                          backgroundColor: colorScheme.primaryContainer.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        if (hasPassphrase)
                          Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 12, color: colorScheme.onSurface),
                                const SizedBox(width: 4),
                                Text(
                                  'Passphrase',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
                                ),
                              ],
                            ),
                            backgroundColor: colorScheme.secondaryContainer.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: colorScheme.onSurface.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, color: colorScheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Text('Edit', style: TextStyle(color: colorScheme.onSurface)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'show_seed',
                    child: Row(
                      children: [
                        Icon(Icons.vpn_key_outlined, color: colorScheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Text('Show Seed Phrase', style: TextStyle(color: colorScheme.onSurface)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                        const SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: colorScheme.error)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  } else if (value == 'edit') {
                    onEdit();
                  } else if (value == 'show_seed') {
                    onShowSeed();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}


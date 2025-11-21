import 'package:flutter/material.dart';
import '../../models/browser_models.dart';

class BrowserTabBar extends StatelessWidget {
  final List<BrowserTab> tabs;
  final int currentIndex;
  final bool isFullScreen;
  final String balance;
  final Function(int) onTabSelected;
  final Function(int) onTabClosed;
  final VoidCallback onNewTab;
  final Function(int, Offset) onTabContextMenu;
  final VoidCallback onBackToWallets;
  final VoidCallback onSettings;
  final VoidCallback onChat;
  final VoidCallback onWalletInfo;

  const BrowserTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.isFullScreen,
    required this.balance,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onNewTab,
    required this.onTabContextMenu,
    required this.onBackToWallets,
    required this.onSettings,
    required this.onChat,
    required this.onWalletInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: EdgeInsets.fromLTRB(
        isFullScreen ? 8 : 80, // Add left padding when not fullscreen
        4,
        8,
        4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back to wallets icon
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: onBackToWallets,
              tooltip: 'Back to Wallets',
              iconSize: 26,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          // Settings icon
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                Icons.settings,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: onSettings,
              tooltip: 'Settings',
              iconSize: 26,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length + 1, // +1 for new tab button
              itemBuilder: (context, index) {
                if (index == tabs.length) {
                  // New tab button
                  return InkWell(
                    onTap: onNewTab,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }
                
                final tabAtIndex = tabs[index];
                final isActive = index == currentIndex;
                
                return GestureDetector(
                  onTap: () => onTabSelected(index),
                  onSecondaryTapDown: (details) {
                    onTabContextMenu(index, details.globalPosition);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive 
                          ? Theme.of(context).colorScheme.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive 
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            tabAtIndex.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                              color: isActive 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (tabs.length > 1)
                          InkWell(
                            onTap: () => onTabClosed(index),
                            borderRadius: BorderRadius.circular(4),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Chat icon
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: IconButton(
              icon: Icon(
                Icons.chat_bubble_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: onChat,
              tooltip: 'Chat',
              iconSize: 26,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          // Balance display
          Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$balance KAS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          // Profile icon at the end of tab bar
          Container(
            margin: const EdgeInsets.only(right: 8, left: 8),
            child: IconButton(
              icon: Icon(
                Icons.account_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: onWalletInfo,
              tooltip: 'Wallet Information',
              iconSize: 28,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}


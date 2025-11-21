import 'package:flutter/material.dart';
import '../../models/browser_models.dart';
import '../../models/bookmark_models.dart';

class BrowserNavigationBar extends StatelessWidget {
  final BrowserTab currentTab;
  final Bookmark? currentPageBookmark;
  final bool isBookmarkPanelOpen;
  final bool isAIPanelOpen;
  final bool isAIEnabled;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh;
  final VoidCallback onStop;
  final Function(String) onUrlSubmitted;
  final VoidCallback onToggleBookmark;
  final VoidCallback onToggleBookmarkPanel;
  final VoidCallback onToggleAIPanel;
  final VoidCallback onCertificateTap;

  const BrowserNavigationBar({
    super.key,
    required this.currentTab,
    this.currentPageBookmark,
    required this.isBookmarkPanelOpen,
    required this.isAIPanelOpen,
    required this.isAIEnabled,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onStop,
    required this.onUrlSubmitted,
    required this.onToggleBookmark,
    required this.onToggleBookmarkPanel,
    required this.onToggleAIPanel,
    required this.onCertificateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: currentTab.canGoBack ? onBack : null,
            tooltip: 'Back',
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: currentTab.canGoForward ? onForward : null,
            tooltip: 'Forward',
            iconSize: 20,
          ),
          IconButton(
            icon: Icon(currentTab.isLoading ? Icons.close : Icons.refresh),
            onPressed: currentTab.isLoading ? onStop : onRefresh,
            tooltip: currentTab.isLoading ? 'Stop' : 'Refresh',
            iconSize: 20,
          ),
          const SizedBox(width: 8.0),
          const VerticalDivider(width: 1),
          const SizedBox(width: 8.0),
          Expanded(
            child: TextField(
              controller: currentTab.urlController,
              decoration: InputDecoration(
                hintText: 'Enter domain name (e.g., navigate.kas)',
                prefixIcon: currentTab.isVerified
                    ? Padding(
                        padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                        child: currentTab.certificateData != null
                            ? GestureDetector(
                                onTap: onCertificateTap,
                                child: Tooltip(
                                  message: 'Secured connection',
                                  child: Icon(
                                    Icons.lock,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              )
                            : Tooltip(
                                message: 'Unsecured connection',
                                child: const Icon(
                                  Icons.lock_open,
                                  size: 18,
                                  color: Colors.orange,
                                ),
                              ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                isDense: true,
              ),
              onSubmitted: onUrlSubmitted,
              textInputAction: TextInputAction.go,
            ),
          ),
          const SizedBox(width: 8.0),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => onUrlSubmitted(currentTab.urlController.text),
            tooltip: 'Go',
            iconSize: 20,
          ),
          // Favorite/Bookmark toggle icon
          if (currentTab.currentUrl.isNotEmpty)
            IconButton(
              icon: Icon(
                currentPageBookmark != null ? Icons.star : Icons.star_border,
                color: currentPageBookmark != null
                    ? Colors.amber
                    : Theme.of(context).colorScheme.primary,
              ),
              onPressed: onToggleBookmark,
              tooltip: currentPageBookmark != null ? 'Remove Bookmark' : 'Add Bookmark',
              iconSize: 20,
            ),
          // Bookmarks list icon
          IconButton(
            icon: Icon(
              Icons.bookmarks,
              color: isBookmarkPanelOpen
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.primary,
            ),
            onPressed: onToggleBookmarkPanel,
            tooltip: 'Bookmarks',
            iconSize: 20,
          ),
          // AI Assistant icon (only show if enabled)
          if (isAIEnabled)
            IconButton(
              icon: Icon(
                Icons.auto_awesome,
                color: isAIPanelOpen
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.primary,
              ),
              onPressed: onToggleAIPanel,
              tooltip: 'AI Assistant',
              iconSize: 20,
            ),
          if (currentTab.isLoading)
            const Padding(
              padding: EdgeInsets.only(left: 4.0, right: 8.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}


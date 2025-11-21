import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../models/bookmark_models.dart';

/// Bookmark Panel widget for displaying and managing bookmarks
class BookmarkPanel extends StatelessWidget {
  final List<Bookmark> bookmarks;
  final List<BookmarkFolder> folders;
  final Function(String) onDeleteBookmark;
  final Function(String) onNavigateToUrl;
  final VoidCallback onClose;

  const BookmarkPanel({
    super.key,
    required this.bookmarks,
    required this.folders,
    required this.onDeleteBookmark,
    required this.onNavigateToUrl,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.bookmarks, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Bookmarks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                iconSize: 20,
              ),
            ],
          ),
        ),
        // Bookmark List
        Expanded(
          child: bookmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No bookmarks yet', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = bookmarks[index];
                    final folder = folders.firstWhere(
                      (f) => f.id == bookmark.folderId,
                      orElse: () => BookmarkFolder(
                        id: 'default',
                        name: 'All Bookmarks',
                        createdAt: DateTime.now(),
                      ),
                    );
                    
                    return ListTile(
                      leading: Icon(Icons.star, color: Colors.amber, size: 20),
                      title: Text(
                        bookmark.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bookmark.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            folder.name,
                            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        onPressed: () => onDeleteBookmark(bookmark.id),
                      ),
                      onTap: () => onNavigateToUrl(bookmark.url),
                    );
                  },
                ),
        ),
      ],
    );
  }
}


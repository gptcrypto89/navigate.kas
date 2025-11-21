import 'package:flutter/material.dart';
import '../../models/bookmark_models.dart';
import '../../services/bookmark_service.dart';

/// Dialog widget for adding a bookmark
class AddBookmarkDialog extends StatefulWidget {
  final String initialName;
  final String url;
  final List<BookmarkFolder> folders;

  const AddBookmarkDialog({
    super.key,
    required this.initialName,
    required this.url,
    required this.folders,
  });

  static Future<Bookmark?> show(
    BuildContext context, {
    required String initialName,
    required String url,
    required List<BookmarkFolder> folders,
  }) async {
    return await showDialog<Bookmark>(
      context: context,
      builder: (context) => AddBookmarkDialog(
        initialName: initialName,
        url: url,
        folders: folders,
      ),
    );
  }

  @override
  State<AddBookmarkDialog> createState() => _AddBookmarkDialogState();
}

class _AddBookmarkDialogState extends State<AddBookmarkDialog> {
  late TextEditingController _nameController;
  late String _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedFolderId = BookmarkService.getDefaultFolderId();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Bookmark'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedFolderId,
            decoration: const InputDecoration(
              labelText: 'Folder',
              border: OutlineInputBorder(),
            ),
            items: widget.folders.map((folder) {
              return DropdownMenuItem(
                value: folder.id,
                child: Text(folder.name),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedFolderId = value;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            
            final bookmark = Bookmark(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              url: widget.url,
              folderId: _selectedFolderId,
              createdAt: DateTime.now(),
            );
            
            Navigator.of(context).pop(bookmark);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}


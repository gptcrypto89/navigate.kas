import 'package:flutter/material.dart';

class WalletMetadataDialog extends StatefulWidget {
  final String? initialName;
  final String? initialAvatar;

  const WalletMetadataDialog({
    super.key,
    this.initialName,
    this.initialAvatar,
  });

  @override
  State<WalletMetadataDialog> createState() => _WalletMetadataDialogState();
}

class _WalletMetadataDialogState extends State<WalletMetadataDialog> {
  late TextEditingController _nameController;
  String? _selectedEmoji;

  final List<String> _emojis = ['🚀', '💎', '⭐', '🔥', '💰', '🎯', '🌟', '🏆', '💼', '🎨'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedEmoji = widget.initialAvatar;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      title: Text(
        'Wallet Settings',
        style: TextStyle(color: colorScheme.onSurface),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Wallet Name',
                  hintText: 'My Wallet',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Text(
                'Choose Avatar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _emojis.map((emoji) {
                  final isSelected = _selectedEmoji == emoji;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedEmoji = isSelected ? null : emoji;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withOpacity(0.2)
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isEmpty) {
              return;
            }
            Navigator.pop(context, {
              'name': _nameController.text,
              'avatar': _selectedEmoji,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}


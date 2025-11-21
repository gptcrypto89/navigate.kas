import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AIInputArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const AIInputArea({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && 
            event.logicalKey == LogicalKeyboardKey.enter) {
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
          if (!isShiftPressed) {
            // Enter without Shift - send message
            if (!isLoading && controller.text.trim().isNotEmpty) {
              onSend();
              return KeyEventResult.handled;
            }
          }
          // Shift+Enter - allow new line (default behavior)
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                minLines: 1,
                enabled: !isLoading,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Ask me anything...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Stack(
              alignment: Alignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.error,
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: isLoading
                        ? colorScheme.errorContainer
                        : colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: isLoading
                        ? Icon(
                            Icons.stop,
                            color: colorScheme.onErrorContainer,
                          )
                        : Icon(
                            Icons.send,
                            color: colorScheme.onPrimary,
                          ),
                    onPressed: isLoading ? onStop : onSend,
                    tooltip: isLoading ? 'Stop' : 'Send',
                    iconSize: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


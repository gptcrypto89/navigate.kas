import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MnemonicDisplay extends StatelessWidget {
  final String mnemonic;
  final bool isVisible;
  final VoidCallback onToggleVisibility;
  final VoidCallback onCopy;
  final VoidCallback? onRegenerate;
  final String label;

  const MnemonicDisplay({
    super.key,
    required this.mnemonic,
    required this.isVisible,
    required this.onToggleVisibility,
    required this.onCopy,
    this.onRegenerate,
    this.label = 'Recovery Phrase',
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
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isVisible) ...[
                  if (onRegenerate != null)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: onRegenerate,
                      tooltip: 'Regenerate',
                    ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: onCopy,
                    tooltip: 'Copy',
                  ),
                ],
                IconButton(
                  icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: onToggleVisibility,
                  tooltip: isVisible ? 'Hide' : 'Show',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: SelectableText(
            isVisible ? mnemonic : '• • • • • • • • • • • • • • • • • • • • • • • •',
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              fontFamily: 'monospace',
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}


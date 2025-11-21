import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AIMessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isStreaming;

  const AIMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isError = false,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isStreaming) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: _buildMarkdown(context, colorScheme),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isError
              ? colorScheme.errorContainer
              : isUser
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 12),
          ),
        ),
        child: isUser || isError
            ? Text(
                text,
                style: TextStyle(
                  color: isError
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimary,
                  fontSize: 14,
                ),
              )
            : _buildMarkdown(context, colorScheme),
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context, ColorScheme colorScheme) {
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 14,
          height: 1.4,
        ),
        strong: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        em: TextStyle(
          color: colorScheme.onSurface,
          fontStyle: FontStyle.italic,
        ),
        code: TextStyle(
          color: colorScheme.primary,
          backgroundColor: colorScheme.surface.withOpacity(0.5),
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        codeblockPadding: const EdgeInsets.all(8),
        listBullet: TextStyle(
          color: colorScheme.onSurface,
        ),
        h1: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        h2: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        h3: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        blockquote: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.7),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          border: Border(
            left: BorderSide(
              color: colorScheme.primary,
              width: 3,
            ),
          ),
        ),
      ),
    );
  }
}


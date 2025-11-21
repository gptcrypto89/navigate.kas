import 'package:flutter/material.dart';

class AIWelcomeView extends StatelessWidget {
  final String? currentDomain;

  const AIWelcomeView({
    super.key,
    this.currentDomain,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_outlined,
            size: 48,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Ask me anything about this page',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          if (currentDomain != null) ...[
            const SizedBox(height: 8),
            Text(
              'I can analyze the page content and help you understand it',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}


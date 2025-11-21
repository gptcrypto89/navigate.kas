import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../widgets/chat/chat_feature_chip.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WindowListener {
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkFullScreen();
    print('💬 Chat: Initializing Chat Screen (Coming Soon)');
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowEnterFullScreen() {
    setState(() {
      _isFullScreen = true;
    });
  }

  @override
  void onWindowLeaveFullScreen() {
    setState(() {
      _isFullScreen = false;
    });
  }

  Future<void> _checkFullScreen() async {
    final isFullScreen = await windowManager.isFullScreen();
    if (mounted) {
      setState(() {
        _isFullScreen = isFullScreen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
        elevation: 0,
        leadingWidth: 100,
        leading: Padding(
          padding: EdgeInsets.only(left: _isFullScreen ? 8 : 72), // Dynamic padding
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            splashColor: Colors.transparent, // Remove splash
            highlightColor: Colors.transparent, // Remove highlight
            hoverColor: Colors.transparent, // Remove hover
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 120,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'Kaspa Messaging',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  'We\'re working on bringing you secure,\nblockchain-based messaging on Kaspa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withOpacity(0.7),
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              const Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  ChatFeatureChip(
                    icon: Icons.lock_outline,
                    label: 'Secure',
                  ),
                  ChatFeatureChip(
                    icon: Icons.account_tree_outlined,
                    label: 'Blockchain',
                  ),
                  ChatFeatureChip(
                    icon: Icons.bolt_outlined,
                    label: 'Fast',
                  ),
                  ChatFeatureChip(
                    icon: Icons.verified_outlined,
                    label: 'Verified',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

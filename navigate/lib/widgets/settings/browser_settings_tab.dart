import 'package:flutter/material.dart';
import 'settings_section_header.dart';

class BrowserSettingsTab extends StatelessWidget {
  final bool enableJavaScript;
  final bool enableCookies;
  final ValueChanged<bool> onJavaScriptChanged;
  final ValueChanged<bool> onCookiesChanged;
  final VoidCallback onClearCache;
  final VoidCallback onClearHistory;

  const BrowserSettingsTab({
    super.key,
    required this.enableJavaScript,
    required this.enableCookies,
    required this.onJavaScriptChanged,
    required this.onCookiesChanged,
    required this.onClearCache,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Privacy & Security Section
        const SettingsSectionHeader(
          title: 'Privacy & Security',
          icon: Icons.security,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable JavaScript'),
                  subtitle: const Text('Required for most modern websites'),
                  value: enableJavaScript,
                  onChanged: onJavaScriptChanged,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Enable Cookies'),
                  subtitle: const Text('Store site data and preferences'),
                  value: enableCookies,
                  onChanged: onCookiesChanged,
                ),
                const Divider(),
                ListTile(
                  title: const Text('Clear Cache'),
                  subtitle: const Text('Remove temporary files'),
                  trailing: ElevatedButton(
                    onPressed: onClearCache,
                    child: const Text('Clear'),
                  ),
                ),
                ListTile(
                  title: const Text('Clear History'),
                  subtitle: const Text('Remove browsing history'),
                  trailing: ElevatedButton(
                    onPressed: onClearHistory,
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}


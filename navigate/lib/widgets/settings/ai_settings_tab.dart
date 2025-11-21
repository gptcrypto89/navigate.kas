import 'package:flutter/material.dart';
import 'settings_section_header.dart';

class AISettingsTab extends StatelessWidget {
  final bool enableAI;
  final ValueChanged<bool> onEnableAIChanged;
  final TextEditingController apiUrlController;
  final TextEditingController modelNameController;
  final TextEditingController apiKeyController;
  final TextEditingController systemPromptController;
  final double temperature;
  final ValueChanged<double> onTemperatureChanged;

  const AISettingsTab({
    super.key,
    required this.enableAI,
    required this.onEnableAIChanged,
    required this.apiUrlController,
    required this.modelNameController,
    required this.apiKeyController,
    required this.systemPromptController,
    required this.temperature,
    required this.onTemperatureChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // AI Features Section
        const SettingsSectionHeader(
          title: 'AI Features',
          icon: Icons.psychology,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SwitchListTile(
              title: const Text('Enable AI Assistant'),
              subtitle: const Text('Show AI assistant panel in browser'),
              value: enableAI,
              onChanged: onEnableAIChanged,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // API Configuration
        const SettingsSectionHeader(
          title: 'API Configuration',
          icon: Icons.settings,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('API URL', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: apiUrlController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'https://api.openai.com',
                    labelText: 'OpenAI Compatible URL',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Model Name', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: modelNameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'gpt-4',
                    labelText: 'Model Name',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('API Key (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'sk-... (leave empty for local models)',
                    labelText: 'API Key (Optional)',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Supports OpenAI, local models (Ollama, LM Studio), and other OpenAI-compatible APIs. API key is optional for local models.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Model Configuration
        const SettingsSectionHeader(
          title: 'Model Configuration',
          icon: Icons.tune,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Temperature', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: temperature,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label: temperature.toStringAsFixed(1),
                        onChanged: onTemperatureChanged,
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        temperature.toStringAsFixed(1),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Higher values make output more random, lower values more focused',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // System Prompt
        const SettingsSectionHeader(
          title: 'System Prompt',
          icon: Icons.code,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Custom System Prompt', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: systemPromptController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter custom system prompt for AI...',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Define how the AI assistant should behave and respond',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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


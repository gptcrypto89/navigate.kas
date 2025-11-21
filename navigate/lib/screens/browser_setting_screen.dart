import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../services/settings_service.dart';
import '../widgets/settings/browser_settings_tab.dart';
import '../widgets/settings/ai_settings_tab.dart';

class BrowserSettingScreen extends StatefulWidget {
  const BrowserSettingScreen({super.key});

  @override
  State<BrowserSettingScreen> createState() => _BrowserSettingScreenState();
}

class _BrowserSettingScreenState extends State<BrowserSettingScreen> with SingleTickerProviderStateMixin, WindowListener {
  late TabController _tabController;
  bool _isFullScreen = false;
  
  // Browser settings
  bool _enableJavaScript = true;
  bool _enableCookies = true;
  
  // AI Assistant settings
  final _apiUrlController = TextEditingController();
  final _modelNameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _systemPromptController = TextEditingController();
  double _temperature = 0.7;
  bool _enableAI = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Update UI when tab changes to show correct save button
    });
    _checkFullScreen();
    print('⚙️ Settings: Initializing Browser Setting Screen');
    _loadSettings();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _apiUrlController.dispose();
    _modelNameController.dispose();
    _apiKeyController.dispose();
    _systemPromptController.dispose();
    _tabController.dispose();
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


  Future<void> _loadSettings() async {
    print('📥 Settings: Loading user preferences...');
    try {
      final browserSettings = await SettingsService.getBrowserSettings();
      final aiSettings = await SettingsService.getAISettings();
      
      setState(() {
        _enableJavaScript = browserSettings['enableJavaScript'] ?? true;
        _enableCookies = browserSettings['enableCookies'] ?? true;
        
        _enableAI = aiSettings['enableAI'] ?? true;
        _apiUrlController.text = aiSettings['apiUrl'] ?? 'https://api.openai.com';
        _modelNameController.text = aiSettings['modelName'] ?? 'gpt-4';
        _apiKeyController.text = aiSettings['apiKey'] ?? '';
        _temperature = (aiSettings['temperature'] ?? 0.7).toDouble();
        _systemPromptController.text = aiSettings['systemPrompt'] ?? 'You are a helpful assistant that helps users understand and interact with web pages. When provided with page content, analyze it and provide helpful insights.';
        _isLoading = false;
      });
      print('✅ Settings: User preferences loaded successfully');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _saveBrowserSettings() async {
    print('💾 Settings: Saving browser settings...');
    try {
      await SettingsService.updateBrowserSettings({
        'enableJavaScript': _enableJavaScript,
        'enableCookies': _enableCookies,
      });
      if (mounted) {
        print('✅ Settings: Browser settings saved successfully');
        _showSaveConfirmation('Browser settings saved');
      }
    } catch (e) {
      print('❌ Settings: Error saving browser settings');
      if (mounted) {
        _showSaveError('Error saving settings: $e');
      }
    }
  }

  Future<void> _saveAISettings() async {
    print('🤖 Settings: Saving AI settings...');
    try {
      await SettingsService.updateAISettings({
        'enableAI': _enableAI,
        'apiUrl': _apiUrlController.text.trim(),
        'modelName': _modelNameController.text.trim(),
        'apiKey': _apiKeyController.text.trim(),
        'temperature': _temperature,
        'systemPrompt': _systemPromptController.text.trim(),
      });
      if (mounted) {
        print('✅ Settings: AI settings saved successfully');
        _showSaveConfirmation('AI settings saved');
      }
    } catch (e) {
      print('❌ Settings: Error saving AI settings');
      if (mounted) {
        _showSaveError('Error saving settings: $e');
      }
    }
  }

  void _showSaveConfirmation(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
    // Auto-dismiss after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  void _showSaveError(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: colorScheme.onErrorContainer,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
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
        actions: [
          // Save button for current tab
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _tabController.index == 0
                ? IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _saveBrowserSettings,
                    tooltip: 'Save Browser Settings',
                    iconSize: 26,
                    padding: const EdgeInsets.all(12),
                  )
                : IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _saveAISettings,
                    tooltip: 'Save AI Settings',
                    iconSize: 26,
                    padding: const EdgeInsets.all(12),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Browser'),
                Tab(text: 'AI Assistant'),
              ],
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
              indicatorColor: colorScheme.primary,
              overlayColor: WidgetStateProperty.all(Colors.transparent), // Remove hover effect
            ),
          ),
          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
              controller: _tabController,
              children: [
                      BrowserSettingsTab(
                        enableJavaScript: _enableJavaScript,
                        enableCookies: _enableCookies,
                        onJavaScriptChanged: (value) {
                    setState(() {
                      _enableJavaScript = value;
                    });
                  },
                        onCookiesChanged: (value) {
                    setState(() {
                      _enableCookies = value;
                    });
                  },
                        onClearCache: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cache cleared')),
                      );
                    },
                        onClearHistory: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('History cleared')),
                      );
                    },
                      ),
                      AISettingsTab(
                        enableAI: _enableAI,
                        onEnableAIChanged: (value) {
                setState(() {
                  _enableAI = value;
                });
              },
                        apiUrlController: _apiUrlController,
                        modelNameController: _modelNameController,
                        apiKeyController: _apiKeyController,
                        systemPromptController: _systemPromptController,
                        temperature: _temperature,
                        onTemperatureChanged: (value) {
                          setState(() {
                            _temperature = value;
                          });
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

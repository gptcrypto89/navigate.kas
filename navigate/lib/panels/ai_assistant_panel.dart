import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../services/ai_client_service.dart';
import '../../services/settings_service.dart';
import '../widgets/ai_assistant/ai_assistant_header.dart';
import '../widgets/ai_assistant/ai_input_area.dart';
import '../widgets/ai_assistant/ai_message_bubble.dart';
import '../widgets/ai_assistant/ai_welcome_view.dart';

/// AI Assistant Panel widget for browser page
class AIAssistantPanel extends StatefulWidget {
  final String currentUrl;
  final String? currentDomain;
  final InAppWebViewController? webViewController;
  final VoidCallback onClose;
  final Map<String, dynamic>? aiSettings;

  const AIAssistantPanel({
    super.key,
    required this.currentUrl,
    required this.currentDomain,
    this.webViewController,
    required this.onClose,
    this.aiSettings,
  });

  @override
  State<AIAssistantPanel> createState() => _AIAssistantPanelState();
}

class _AIAssistantPanelState extends State<AIAssistantPanel> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _currentStreamingText;
  StreamSubscription<String>? _streamSubscription;
  AIClientService? _aiClient;

  @override
  void initState() {
    super.initState();
    _initializeAIClient();
  }

  @override
  void didUpdateWidget(AIAssistantPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.aiSettings != oldWidget.aiSettings) {
      _initializeAIClient();
    }
  }

  @override
  void dispose() {
    _stopStream();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _stopStream() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    if (mounted) {
      setState(() {
        if (_isLoading) {
          // Save any partial response before stopping
          if (_currentStreamingText != null && _currentStreamingText!.isNotEmpty) {
            _messages.add({
              'text': _currentStreamingText!,
              'isUser': false,
              'timestamp': DateTime.now(),
            });
            _currentStreamingText = null;
          }
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _initializeAIClient() async {
    try {
      Map<String, dynamic> aiSettings;
      
      if (widget.aiSettings != null && widget.aiSettings!.isNotEmpty) {
        aiSettings = widget.aiSettings!;
      } else {
        aiSettings = await SettingsService.getAISettings();
      }
      
      final apiUrl = aiSettings['apiUrl'] as String? ?? 'https://api.openai.com';
      final modelName = aiSettings['modelName'] as String? ?? 'gpt-4';
      final apiKey = aiSettings['apiKey'] as String? ?? '';
      final temperature = (aiSettings['temperature'] ?? 0.7).toDouble();
      final systemPrompt = aiSettings['systemPrompt'] as String? ?? 
          'You are a helpful assistant that helps users understand and interact with web pages. When provided with page content, analyze it and provide helpful insights.';

      // API key is optional (for local models)
      setState(() {
        _aiClient = AIClientService(
          baseUrl: apiUrl,
          apiKey: apiKey,
          model: modelName,
          temperature: temperature,
          systemPrompt: systemPrompt,
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'text': 'Error initializing AI client: $e',
            'isUser': false,
            'timestamp': DateTime.now(),
            'isError': true,
          });
        });
      }
    }
  }

  Future<String?> _extractPageContent() async {
    if (widget.webViewController == null) {
      return null;
    }

    try {
      // Extract page content using JavaScript
      final script = '''
        (function() {
          // Get page title
          const title = document.title || '';
          
          // Get main content (try to find article, main, or body)
          let content = '';
          const article = document.querySelector('article');
          const main = document.querySelector('main');
          const body = document.body;
          
          const contentElement = article || main || body;
          if (contentElement) {
            // Remove script and style elements
            const clone = contentElement.cloneNode(true);
            const scripts = clone.querySelectorAll('script, style, nav, header, footer, aside');
            scripts.forEach(el => el.remove());
            
            // Get text content
            content = clone.innerText || clone.textContent || '';
            
            // Limit content length to avoid token limits
            if (content.length > 10000) {
              content = content.substring(0, 10000) + '... (content truncated)';
            }
          }
          
          // Get URL
          const url = window.location.href || '';
          
          return JSON.stringify({
            title: title,
            url: url,
            content: content.trim()
          });
        })();
      ''';

      final result = await widget.webViewController!.evaluateJavascript(source: script);
      
      if (result != null) {
        // Parse the JSON result
        final jsonString = result.toString().replaceAll(RegExp(r'^"|"$'), '').replaceAll('\\"', '"').replaceAll('\\n', '\n');
        return jsonString;
      }
    } catch (e) {
      print('Error extracting page content: $e');
    }
    
    return null;
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _isLoading) return;

    if (_aiClient == null) {
      await _initializeAIClient();
      if (_aiClient == null) {
        return;
      }
    }

    final userMessage = _messageController.text;
    _messageController.clear();

    setState(() {
      _messages.add({
        'text': userMessage,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _isLoading = true;
      _currentStreamingText = '';
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      // Extract page content for context
      String? pageContext;
      if (widget.webViewController != null && widget.currentUrl.isNotEmpty) {
        final pageContent = await _extractPageContent();
        if (pageContent != null && pageContent.isNotEmpty) {
          pageContext = pageContent;
        }
      }

      // Prepare messages for API
      final conversationMessages = _messages
          .where((m) => !m.containsKey('isError'))
          .map((m) => {
                'role': m['isUser'] == true ? 'user' : 'assistant',
                'content': m['text'] as String,
              })
          .toList();

      // Stream the response
      final stream = _aiClient!.streamChatCompletion(
        messages: conversationMessages,
        additionalContext: pageContext,
      );

      _streamSubscription?.cancel();
      _streamSubscription = stream.listen(
        (chunk) {
          if (mounted) {
            setState(() {
              _currentStreamingText = (_currentStreamingText ?? '') + chunk;
            });
            _scrollToBottom();
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _currentStreamingText = null;
              _messages.add({
                'text': 'Error: $error',
                'isUser': false,
                'timestamp': DateTime.now(),
                'isError': true,
              });
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              if (_currentStreamingText != null && _currentStreamingText!.isNotEmpty) {
                _messages.add({
                  'text': _currentStreamingText!,
                  'isUser': false,
                  'timestamp': DateTime.now(),
                });
                _currentStreamingText = null;
              }
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStreamingText = null;
          _messages.add({
            'text': 'Error sending message: $e',
            'isUser': false,
            'timestamp': DateTime.now(),
            'isError': true,
          });
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        AIAssistantHeader(
          currentDomain: widget.currentDomain,
          onClose: () {
            _stopStream();
            widget.onClose();
          },
        ),
        
        // Messages area
        Expanded(
          child: _messages.isEmpty && !_isLoading
              ? AIWelcomeView(currentDomain: widget.currentDomain)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isLoading && _currentStreamingText != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isLoading && _currentStreamingText != null) {
                      // Show streaming message
                      return AIMessageBubble(
                        text: _currentStreamingText!,
                        isUser: false,
                        isStreaming: true,
                      );
                    }

                    final message = _messages[index];
                    final isUser = message['isUser'] as bool;
                    final isError = message['isError'] as bool? ?? false;
                    
                    return AIMessageBubble(
                      text: message['text'] as String,
                      isUser: isUser,
                      isError: isError,
                    );
                  },
                ),
        ),
        
        // Input area
        AIInputArea(
          controller: _messageController,
          focusNode: _focusNode,
          isLoading: _isLoading,
          onSend: _sendMessage,
          onStop: _stopStream,
        ),
      ],
    );
  }
}

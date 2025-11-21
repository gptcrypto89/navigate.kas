import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../common/config.dart';

/// Service for interacting with OpenAI-compatible APIs
class AIClientService {
  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final String systemPrompt;

  AIClientService({
    required this.baseUrl,
    this.apiKey = '', // Optional - not required for local models
    required this.model,
    this.temperature = AppConfig.aiTemperature,
    this.systemPrompt = 'You are a helpful assistant.',
  });

  /// Stream a chat completion response
  Stream<String> streamChatCompletion({
    required List<Map<String, String>> messages,
    String? additionalContext,
  }) async* {
    try {
      // Prepare messages with system prompt and context
      final allMessages = <Map<String, dynamic>>[];
      
      // Add system message with context if provided
      String fullSystemPrompt = systemPrompt;
      if (additionalContext != null && additionalContext.isNotEmpty) {
        // Limit context size to prevent token limit issues or excessive data processing
        final truncatedContext = additionalContext.length > AppConfig.aiMaxContextLength 
            ? additionalContext.substring(0, AppConfig.aiMaxContextLength) + '\n...[truncated]' 
            : additionalContext;
        fullSystemPrompt = '$systemPrompt\n\nContext from current page:\n$truncatedContext';
      }
      
      allMessages.add({
        'role': 'system',
        'content': fullSystemPrompt,
      });
      
      // Add conversation messages
      allMessages.addAll(messages.map((msg) => {
        'role': msg['role'],
        'content': msg['content'],
      }));

      // Build request
      final url = Uri.parse('$baseUrl/v1/chat/completions');
      
      final requestBody = {
        'model': model,
        'messages': allMessages,
        'temperature': temperature,
        'stream': true,
      };

      final request = http.Request('POST', url);
      request.headers.addAll({
        'Content-Type': 'application/json',
      });
      // Only add Authorization header if API key is provided
      if (apiKey.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $apiKey';
      }
      request.body = jsonEncode(requestBody);

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: AppConfig.aiStreamTimeoutSeconds),
      );

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw Exception('API Error ${streamedResponse.statusCode}: $errorBody');
      }

      // Stream the response
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        // Parse Server-Sent Events (SSE) format
        final lines = chunk.split('\n');
        
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            
            if (data == '[DONE]') {
              return;
            }
            
            try {
              final jsonData = json.decode(data) as Map<String, dynamic>;
              final choices = jsonData['choices'] as List<dynamic>?;
              
              if (choices != null && choices.isNotEmpty) {
                final delta = choices[0]['delta'] as Map<String, dynamic>?;
                final content = delta?['content'] as String?;
                
                if (content != null && content.isNotEmpty) {
                  yield content;
                }
              }
            } catch (e) {
              // Skip invalid JSON chunks
              continue;
            }
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to stream chat completion: $e');
    }
  }

  /// Test the connection to the API
  Future<bool> testConnection() async {
    try {
      final url = Uri.parse('$baseUrl/v1/models');
      
      final headers = <String, String>{};
      // Only add Authorization header if API key is provided
      if (apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }
      
      final response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: AppConfig.aiTestTimeoutSeconds));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}


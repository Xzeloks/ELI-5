import 'dart:async';
import 'dart:convert';
import 'package:eli5/models/chat_message.dart'; // Import ChatMessage model
import 'package:http/http.dart' as http;

class OpenAIService {

  Future<String> fetchSimplifiedText(String inputText, String apiKey, {bool isQuestion = false}) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    // Determine the prompt based on whether it's a question or text to simplify
    final systemMessage = isQuestion
        ? 'You are a helpful assistant that answers questions simply and clearly, like explaining to a 5-year-old.'
        : 'You are a helpful assistant that simplifies complex text like explaining to a 5-year-old.';
    final userMessageContent = isQuestion
        ? 'Answer the following question like I\'m 5 years old. Provide a clear and simple explanation.\n\nQuestion: $inputText'
        : 'Explain the following text like I\'m 5 years old. Provide a detailed explanation, covering the main points thoroughly, but keep the language simple.\n\n$inputText';

    final body = jsonEncode({
      'model': 'gpt-3.5-turbo',
      'messages': [
        {
          'role': 'system',
          'content': systemMessage
        },
        {
          'role': 'user',
          'content': userMessageContent
        }
      ],
      'max_tokens': 500, // Keep reasonable limit for target length
      'temperature': 0.7, // Adjust creativity (0.0 to 2.0)
    });

    try {
      final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 30)); // Increased timeout slightly

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          final content = data['choices'][0]['message']?['content']?.trim();
          if (content != null && content.isNotEmpty) {
            return content;
          } else {
            throw Exception('Failed to extract simplified text/answer from API response.');
          }
        } else {
          throw Exception('Invalid response format from API.');
        }
      } else {
        String errorMessage = 'Failed to get response from OpenAI. Status code: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            errorMessage += '\nDetails: ${errorData['error']['message']}';
          }
        } catch (_) {
          errorMessage += '\nResponse body: ${response.body}';
        }
        throw Exception(errorMessage);
      }
    } on TimeoutException catch (_) {
        throw Exception('The request to OpenAI timed out. Please try again.');
    } catch (e) {
      throw Exception('An error occurred communicating with OpenAI: ${e.toString()}');
    }
  }

  // New method for chat completions
  Future<String> getChatResponse(
    List<ChatMessage> fullHistory, 
    String apiKey,
    {String? effectiveLastUserMessageContent} // New optional parameter
  ) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    // Define a system message for the chat context
    final systemMessage = {
      'role': 'system',
      'content': 'You are ELI5 Bot, an expert at explaining complex topics simply. When a user provides text or asks a question, explain it like they are 5 years old. Maintain this persona throughout the conversation.'
    };

    // Convert List<ChatMessage> to the format OpenAI API expects
    List<Map<String, String>> apiMessages = [];
    for (int i = 0; i < fullHistory.length; i++) {
      final msg = fullHistory[i];
      String contentToUse = msg.text;
      // If this is the last message, it's from the user, and we have an override, use it.
      if (effectiveLastUserMessageContent != null && 
          i == fullHistory.length - 1 && 
          msg.sender == ChatMessageSender.user) {
        contentToUse = effectiveLastUserMessageContent;
      }
      apiMessages.add({
        'role': msg.sender == ChatMessageSender.user ? 'user' : 'assistant',
        'content': contentToUse,
      });
    }

    final body = jsonEncode({
      'model': 'gpt-3.5-turbo',
      'messages': [systemMessage, ...apiMessages], // Prepend system message to the history
      'max_tokens': 300, // Adjust as needed for chat responses
      'temperature': 0.7,
    });

    try {
      final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 45)); // Slightly longer timeout for chat

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          final content = data['choices'][0]['message']?['content']?.trim();
          if (content != null && content.isNotEmpty) {
            return content;
          } else {
            throw Exception('Failed to extract chat response from API.');
          }
        } else {
          throw Exception('Invalid response format from API for chat.');
        }
      } else {
        String errorMessage = 'Failed to get chat response from OpenAI. Status code: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            errorMessage += '\nDetails: ${errorData['error']['message']}';
          }
        } catch (_) {
          errorMessage += '\nResponse body: ${response.body}'; // Log raw body if JSON parsing fails
        }
        throw Exception(errorMessage);
      }
    } on TimeoutException catch (_) {
        throw Exception('The chat request to OpenAI timed out. Please try again.');
    } catch (e) {
      throw Exception('An error occurred during the chat request: ${e.toString()}');
    }
  }
} 
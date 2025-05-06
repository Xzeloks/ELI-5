import 'dart:async';
import 'dart:convert';
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
} 
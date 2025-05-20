import 'dart:async';
import 'dart:convert';
import 'package:eli5/models/chat_message.dart'; // Import ChatMessage model
import 'package:eli5/models/simplification_style.dart'; // ADDED import
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Added for .env access

class OpenAIService {
  // Define the Supabase Edge Function URL
  static const String _supabaseFunctionUrl = 'https://dhztoureixsskctbpovk.supabase.co/functions/v1/openai-proxy';

  Future<String> fetchSimplifiedText(String inputText, {bool isQuestion = false}) async { // Removed apiKey parameter
    final url = Uri.parse(_supabaseFunctionUrl);
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseAnonKey == null) {
      throw Exception('SUPABASE_ANON_KEY not found in .env file');
    }

    final headers = {
      'Content-Type': 'application/json',
      'apikey': supabaseAnonKey, // Use Supabase anon key
      // If you have user authentication with Supabase and your function uses it:
      // 'Authorization': 'Bearer YOUR_SUPABASE_USER_JWT', 
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
    {String? effectiveLastUserMessageContent, 
     SimplificationStyle style = SimplificationStyle.eli5} 
  ) async {
    final url = Uri.parse(_supabaseFunctionUrl);
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseAnonKey == null) {
      throw Exception('SUPABASE_ANON_KEY not found in .env file');
    }

    final headers = {
      'Content-Type': 'application/json',
      'apikey': supabaseAnonKey, // Use Supabase anon key
      // If you have user authentication with Supabase and your function uses it:
      // 'Authorization': 'Bearer YOUR_SUPABASE_USER_JWT',
    };

    // Define a system message for the chat context based on the style
    String systemPromptContent;
    switch (style) {
      case SimplificationStyle.eli5:
        systemPromptContent = 'You are ELI5 Bot, an expert at explaining complex topics simply. When a user provides text or asks a question, explain it like they are 5 years old. If the input is unclear or seems unreadable, first try to infer the general topic or question. Then, provide your ELI5 explanation based on that inference, perhaps mentioning you\'ve made an assumption due to the input quality. Maintain this persona throughout the conversation.';
        break;
      case SimplificationStyle.summary:
        systemPromptContent = 'You are a helpful assistant. Provide a comprehensive yet clear summary of the user\'s input or the main points of the conversation. Ensure all key aspects are covered without excessive detail. If the input is unclear or seems unreadable, first try to infer the general topic. Then, provide your summary based on that inference, and you can state that your summary is based on an interpretation of the input.';
        break;
      case SimplificationStyle.expert:
        systemPromptContent = 'You are a knowledgeable expert. Provide a detailed and nuanced explanation in response to the user\'s input. Assume some prior knowledge and use appropriate terminology. If the input is a question, answer it comprehensively from an expert standpoint. If the input is unclear or seems unreadable, first attempt to deduce the underlying subject or query. Then, deliver your expert explanation based on this deduction, and you may note that your response is an inference due to the nature of the input.';
        break;
      default: // Fallback to ELI5
        systemPromptContent = 'You are ELI5 Bot, an expert at explaining complex topics simply. When a user provides text or asks a question, explain it like they are 5 years old. If the input is unclear or seems unreadable, first try to infer the general topic or question. Then, provide your ELI5 explanation based on that inference, perhaps mentioning you\'ve made an assumption due to the input quality. Maintain this persona throughout the conversation.';
    }

    final systemMessage = {
      'role': 'system',
      'content': systemPromptContent,
    };

    // Prepare effective content from user, potentially truncating if too long.
    String userContentForApi = effectiveLastUserMessageContent ?? '';

    // If there was no explicit effectiveLastUserMessageContent, 
    // and history is not empty, use the text of the last actual user message.
    // This case might be rare if effectiveLastUserMessageContent is usually populated.
    if (userContentForApi.isEmpty && fullHistory.isNotEmpty) {
        final lastMessage = fullHistory.last;
        if (lastMessage.sender == ChatMessageSender.user) {
            userContentForApi = lastMessage.text;
        }
    }

    // Determine model and truncation limits based on content length
    String modelName = 'gpt-4o-mini'; // UPDATED: Default to gpt-4o-mini
    // Approx 120k tokens for content (128k total context - system prompt - response tokens)
    // 120,000 tokens * ~3.5 chars/token (being conservative) = 420,000 characters
    int characterLimitForTruncation = 400000; 

    // Threshold to consider switching to a larger model if gpt-4o-mini proves insufficient for extreme cases
    // or if we want to give very large inputs to gpt-4o specifically.
    // For now, gpt-4o-mini has a large context, so this threshold might not be strictly needed for context size alone.
    const int thresholdToConsiderLargerModel = 350000; // Example threshold, can be adjusted
    // Max character length for content portion for gpt-4o (if we decide to use it for larger inputs)
    // Also around 120k tokens for content -> ~420,000 characters
    const int characterLimitForLargerModelContent = 400000; 

    // Optional: Logic to switch to gpt-4o for very large inputs if desired.
    // For now, gpt-4o-mini should handle large contexts well. If you find a need to differentiate:
    /*
    if (userContentForApi.length >= thresholdToConsiderLargerModel) {
      modelName = 'gpt-4o'; // Switch to gpt-4o for very large inputs
      characterLimitForTruncation = characterLimitForLargerModelContent;
      print("[OpenAIService] User content length (${userContentForApi.length} chars) is very high. Attempting to use $modelName. New truncation limit: $characterLimitForTruncation chars.");
    } else {
      print("[OpenAIService] User content length (${userContentForApi.length} chars). Using default $modelName. Truncation limit: $characterLimitForTruncation chars.");
    }
    */
    print("[OpenAIService] Using model: $modelName. User content length: ${userContentForApi.length} chars. Truncation limit: $characterLimitForTruncation chars.");

    if (userContentForApi.length > characterLimitForTruncation) {
      print("[OpenAIService] User content is too long for chosen model $modelName (${userContentForApi.length} chars). Truncating to $characterLimitForTruncation chars.");
      userContentForApi = userContentForApi.substring(0, characterLimitForTruncation);
      // Optionally, append a note that content was truncated, though this adds to the token count.
      // userContentForApi += "\n\n[Note: The input content was too long and has been truncated to fit processing limits.]";
    }

    // Convert List<ChatMessage> to the format OpenAI API expects
    List<Map<String, String>> apiMessages = [];
    for (int i = 0; i < fullHistory.length; i++) {
      final msg = fullHistory[i];
      String contentToUse = msg.text;
      
      // If this is the last message in the provided history AND it's a user message,
      // its content should be replaced with our processed (and potentially truncated) userContentForApi.
      if (i == fullHistory.length - 1 && msg.sender == ChatMessageSender.user) {
        contentToUse = userContentForApi;
      }
      apiMessages.add({
        'role': msg.sender == ChatMessageSender.user ? 'user' : 'assistant',
        'content': contentToUse,
      });
    }

    // Ensure there's at least one user message if effectiveLastUserMessageContent was given
    // and fullHistory was empty or didn't end with a user message to be replaced.
    // This typically happens if the initial message to the bot is a URL or OCR result.
    if (apiMessages.isEmpty || apiMessages.last['role'] != 'user') {
        if (effectiveLastUserMessageContent != null) { // We must have had an override
             apiMessages.add({
                'role': 'user',
                'content': userContentForApi, // Use the (potentially truncated) content
            });
        }
    }

    final body = jsonEncode({
      'model': modelName, // USE THE DYNAMICALLY SELECTED MODEL NAME
      'messages': [systemMessage, ...apiMessages], // Prepend system message to the history
      'max_tokens': 1024, // INCREASED max_tokens for response
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
import 'dart:async';
import 'dart:convert';
import 'package:eli5/models/chat_message.dart'; // Import ChatMessage model
import 'package:eli5/models/simplification_style.dart'; // ADDED import
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Added for .env access

class ExplanationResult {
  final String explanation;
  final List<String> relatedConcepts;

  ExplanationResult({required this.explanation, required this.relatedConcepts});

  factory ExplanationResult.fromJson(Map<String, dynamic> json) {
    return ExplanationResult(
      explanation: json['explanation'] as String,
      relatedConcepts: (json['related_concepts'] as List<dynamic>).cast<String>(),
    );
  }
}

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
  Future<ExplanationResult> getChatResponse(
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
      'apikey': supabaseAnonKey,
    };

    // Define the tool structure
    final formatExplanationTool = {
      "type": "function",
      "function": {
        "name": "format_explanation_with_concepts",
        "description": "Formats the explanation and provides a list of related concepts for further exploration, according to the requested style (ELI5, summary, or expert).",
        "parameters": {
          "type": "object",
          "properties": {
            "explanation": {
              "type": "string",
              "description": "The explanation of the topic, tailored to the requested style."
            },
            "related_concepts": {
              "type": "array",
              "items": { "type": "string" },
              "description": "A list of 2-3 keywords or short phrases related to the explanation, suitable for further queries and also in line with the requested style. If no specific related concepts are evident, provide an empty list."
            }
          },
          "required": ["explanation", "related_concepts"]
        }
      }
    };

    String systemPromptContent;
    switch (style) {
      case SimplificationStyle.eli5:
        systemPromptContent = '''You are ELI5 Bot, an expert at explaining complex topics simply and in a friendly, conversational manner.
When a user provides text or asks a question, explain it like they are 5 years old.
Try to vary your sentence structure and avoid using lists for every explanation, unless a list is the most natural way to answer (e.g., for specific steps).
If the input is unclear or seems unreadable, first try to infer the general topic or question. Then, provide your ELI5 explanation based on that inference, perhaps mentioning you've made an assumption due to the input quality.
If the user's query seems exceptionally complex, you can start your explanation with something like: 'That's a big topic! Here's a super simple starting point to get you going...'.
Your primary method for responding is to use the 'format_explanation_with_concepts' tool. Provide your explanation in the 'explanation' field and 2-3 related concepts in the 'related_concepts' field.
If you absolutely cannot use the tool, you MUST format your entire response as follows:
1. Provide the main explanation text.
2. On the VERY LAST LINE of your response, include the exact text 'RELATED_CONCEPTS_SEPARATOR:' followed by a comma-separated list of 2-3 related concepts (or leave it blank after the separator if no concepts are relevant). Do not add any text after this separator line.
Example of fallback format:
This is the main explanation.
It can be multiple paragraphs.
RELATED_CONCEPTS_SEPARATOR: first concept, second idea, third topic
Maintain your friendly and simple persona throughout the conversation.''';
        break;
      case SimplificationStyle.summary:
        systemPromptContent = '''You are a helpful assistant. Provide a comprehensive yet clear summary of the user's input or the main points of the conversation.
Ensure all key aspects are covered without excessive detail.
If the input is unclear or seems unreadable, first try to infer the general topic. Then, provide your summary based on that inference, and you can state that your summary is based on an interpretation of the input.
Your primary method for responding is to use the 'format_explanation_with_concepts' tool. Provide your summary in the 'explanation' field and suggest 2-3 related short concepts or keywords based on the summary in the 'related_concepts' field.
If you absolutely cannot use the tool, you MUST format your entire response as follows:
1. Provide the main summary text.
2. On the VERY LAST LINE of your response, include the exact text 'RELATED_CONCEPTS_SEPARATOR:' followed by a comma-separated list of 2-3 related concepts (or leave it blank after the separator if no concepts are relevant). Do not add any text after this separator line.
Example of fallback format:
This is the main summary.
RELATED_CONCEPTS_SEPARATOR: key takeaway 1, main point 2, associated idea 3''';
        break;
      case SimplificationStyle.expert:
        systemPromptContent = '''You are a knowledgeable expert. Provide a detailed and nuanced explanation in response to the user's input.
Assume some prior knowledge and use appropriate terminology. If the input is a question, answer it comprehensively from an expert standpoint.
If the input is unclear or seems unreadable, first attempt to deduce the underlying subject or query. Then, deliver your expert explanation based on this deduction, and you may note that your response is an inference due to the nature of the input.
Your primary method for responding is to use the 'format_explanation_with_concepts' tool. Provide your expert explanation in the 'explanation' field and suggest 2-3 related academic or technical concepts/keywords in the 'related_concepts' field.
If you absolutely cannot use the tool, you MUST format your entire response as follows:
1. Provide the main expert explanation text.
2. On the VERY LAST LINE of your response, include the exact text 'RELATED_CONCEPTS_SEPARATOR:' followed by a comma-separated list of 2-3 related concepts (or leave it blank after the separator if no concepts are relevant). Do not add any text after this separator line.
Example of fallback format:
This is the expert explanation.
RELATED_CONCEPTS_SEPARATOR: technical term A, academic field B, advanced topic C''';
        break;
      default: 
        systemPromptContent = '''You are ELI5 Bot, an expert at explaining complex topics simply and in a friendly, conversational manner.
When a user provides text or asks a question, explain it like they are 5 years old.
Your primary method for responding is to use the 'format_explanation_with_concepts' tool. Provide your explanation in the 'explanation' field and 2-3 related concepts in the 'related_concepts' field.
If you absolutely cannot use the tool, you MUST format your entire response as follows:
1. Provide the main explanation text.
2. On the VERY LAST LINE of your response, include the exact text 'RELATED_CONCEPTS_SEPARATOR:' followed by a comma-separated list of 2-3 related concepts (or leave it blank after the separator if no concepts are relevant). Do not add any text after this separator line.
Maintain your friendly and simple persona throughout the conversation.'''; // Fallback, ensure tool usage and specific fallback
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
      'model': modelName,
      'messages': [systemMessage, ...apiMessages],
      'tools': [formatExplanationTool],
      'tool_choice': {"type": "function", "function": {"name": "format_explanation_with_concepts"}},
      'max_tokens': 1024, 
      'temperature': 0.7,
    });

    try {
      final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 60)); // Increased timeout for potentially more complex processing

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // print('[OpenAIService Raw Response]: ${response.body}'); // For debugging

        if (data['choices'] != null && data['choices'].isNotEmpty) {
          final message = data['choices'][0]['message'];
          if (message['tool_calls'] != null && message['tool_calls'].isNotEmpty) {
            final toolCall = message['tool_calls'][0];
            if (toolCall['type'] == 'function' && toolCall['function']['name'] == 'format_explanation_with_concepts') {
              final argumentsJson = toolCall['function']['arguments'];
              try {
                final arguments = jsonDecode(argumentsJson);
                return ExplanationResult.fromJson(arguments);
              } catch (e) {
                throw Exception('Failed to parse tool call arguments: $e. Arguments JSON: $argumentsJson');
              }
            } else {
              throw Exception('Expected tool call to format_explanation_with_concepts, but received different tool or type.');
            }
          } else if (message['content'] != null) {
            // Fallback or unexpected response: Model didn't use the tool and returned content directly.
            String rawContent = message['content'].trim();
            print("[OpenAIService DEBUG Raw Content for ${style.name} when tool not used]: $rawContent"); 
            
            print('[OpenAIService Warning]: Model did not use the specified tool. Returned content directly for style ${style.name}.');
            
            List<String> parsedConcepts = [];
            String explanationText = rawContent;

            // NEW Fallback: Look for explicit separator line
            String separator = "RELATED_CONCEPTS_SEPARATOR:";
            int separatorIndex = rawContent.lastIndexOf(separator);

            if (separatorIndex != -1) {
              explanationText = rawContent.substring(0, separatorIndex).trim();
              String conceptsLine = rawContent.substring(separatorIndex + separator.length).trim();
              if (conceptsLine.isNotEmpty) {
                parsedConcepts = conceptsLine.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
                // Further cleanup: if a concept ends with a period, remove it.
                parsedConcepts = parsedConcepts.map((c) => c.endsWith('.') ? c.substring(0, c.length -1).trim() : c).toList();
              }
            } else {
              // Original fallback (less likely to be hit now, but kept as a last resort)
              String conceptsHeadingMarker = "Related Concepts";
              int headingIndex = rawContent.toLowerCase().lastIndexOf(conceptsHeadingMarker.toLowerCase());
              if (headingIndex != -1) {
                explanationText = rawContent.substring(0, headingIndex).trim();
                String conceptsBlock = rawContent.substring(headingIndex + conceptsHeadingMarker.length).trim();
                List<String> lines = conceptsBlock.split('\n');
                for (String line in lines) {
                  String trimmedLine = line.trim();
                  if (trimmedLine.startsWith('•') || trimmedLine.startsWith('-')) { // Check for bullet or hyphen
                    String concept = trimmedLine.substring(1).trim(); 
                    if (concept.endsWith('.')) {
                      concept = concept.substring(0, concept.length - 1).trim();
                    }
                    if (concept.isNotEmpty) {
                      parsedConcepts.add(concept);
                    }
                  }
                }
              }
            }
            
            print('[OpenAIService Fallback Parsing]: Explanation: "$explanationText", Parsed Concepts: $parsedConcepts');
            return ExplanationResult(explanation: explanationText, relatedConcepts: parsedConcepts);
          }
           else {
            throw Exception('Failed to extract chat response or tool call from API.');
          }
        } else {
          throw Exception('Invalid response format from API for chat (no choices).');
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
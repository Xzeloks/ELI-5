import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eli5/models/chat_message.dart';
import 'package:eli5/services/openai_service.dart'; // Import OpenAIService
import 'package:eli5/services/content_fetcher_service.dart'; // Import ContentFetcherService
import 'package:eli5/services/chat_db_service.dart'; // Import ChatDbService
import 'package:supabase_flutter/supabase_flutter.dart'; // For Supabase.instance.client.auth.currentUser
import 'dart:math'; // For generating unique IDs for now

// Provider for the ChatNotifier state
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    ref.read(openAIServiceProvider),
    ref.read(contentFetcherServiceProvider),
    ref.read(chatDbServiceProvider), // Pass ChatDbService instance
  );
});

// Provider for OpenAIService (so it can be easily mocked or replaced)
final openAIServiceProvider = Provider<OpenAIService>((ref) => OpenAIService());

// Provider for ContentFetcherService
final contentFetcherServiceProvider = Provider<ContentFetcherService>((ref) => ContentFetcherService());

// Provider for ChatDbService
final chatDbServiceProvider = Provider<ChatDbService>((ref) => ChatDbService());

// Provider to fetch the list of user's chat sessions
final chatSessionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    // If user is not logged in, return an empty list or throw an error
    // AuthGate should prevent this state, but good to be defensive.
    return []; 
  }
  final chatDbService = ref.read(chatDbServiceProvider);
  return chatDbService.loadUserChatSessions(userId);
});

// State class to hold both messages and loading status
class ChatState {
  final List<ChatMessage> messages;
  final bool isAiResponding;
  final String? errorMessage;
  final String? currentSessionId; // Added to store current session ID

  ChatState({
    this.messages = const [],
    this.isAiResponding = false,
    this.errorMessage,
    this.currentSessionId,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isAiResponding,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? currentSessionId, // For updating session ID
    bool clearCurrentSessionId = false, // For clearing session ID (e.g., new chat)
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isAiResponding: isAiResponding ?? this.isAiResponding,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      currentSessionId: clearCurrentSessionId ? null : currentSessionId ?? this.currentSessionId,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final OpenAIService _openAIService;
  final ContentFetcherService _contentFetcherService;
  final ChatDbService _chatDbService; // Add ChatDbService instance

  ChatNotifier(this._openAIService, this._contentFetcherService, this._chatDbService) : super(ChatState());

  Future<void> sendMessageAndGetResponse(String rawInputText, String apiKey) async {
    if (rawInputText.isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      // Handle error: user not logged in, cannot save chat
      // This case should ideally be prevented by AuthGate
      state = state.copyWith(isAiResponding: false, errorMessage: "User not authenticated.");
      // Optionally add a message to the chat list indicating this error
      final errorMsg = ChatMessage(id: "error_auth", text: "Error: You must be logged in to chat.", sender: ChatMessageSender.ai, timestamp: DateTime.now());
      state = state.copyWith(messages: [...state.messages, errorMsg]);
      return;
    }

    // Add user's raw message immediately to the UI
    final userMessage = ChatMessage(
      id: Random().nextDouble().toString(), 
      text: rawInputText,
      sender: ChatMessageSender.user,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, userMessage], isAiResponding: true, clearErrorMessage: true);
    
    // currentSessionId from state is nullable
    String? existingSessionId = state.currentSessionId; 
    String activeSessionId; // This will hold the non-nullable session ID for the current operation

    try {
      // Ensure a session exists, create if not
      activeSessionId = await _chatDbService.ensureChatSession(
        userId,
        existingSessionId: existingSessionId,
        initialMessageContent: existingSessionId == null ? rawInputText : null, // Pass content for title only for new sessions
      );
      // Update state with the (potentially new) session ID
      state = state.copyWith(currentSessionId: activeSessionId);

      // Save user message to DB
      await _chatDbService.saveChatMessage(userMessage, activeSessionId, userId);

      // --- Content Fetching and Preprocessing --- 
      String contentForAI = rawInputText;
      if (_contentFetcherService.isYouTubeUrl(rawInputText)) {
        final transcript = await _contentFetcherService.fetchYouTubeTranscript(rawInputText);
        contentForAI = "The user shared this YouTube video: $rawInputText\n\nPlease ELI5 the following transcript:\n\n$transcript";
      } else if (_contentFetcherService.isValidUrl(rawInputText)) {
        final webContent = await _contentFetcherService.fetchAndParseUrl(rawInputText);
        contentForAI = "The user shared this webpage: $rawInputText\n\nPlease ELI5 the following content from the webpage:\n\n$webContent";
      }
      // For plain text or questions, contentForAI remains rawInputText, 
      // the system prompt in OpenAIService will guide ELI5.

      // --- Call OpenAI Service --- 
      // Pass the full history from state, and the potentially processed contentForAI as the override
      final aiResponseText = await _openAIService.getChatResponse(
        state.messages, // This now includes the user's raw message (e.g. the URL itself)
        apiKey,
        effectiveLastUserMessageContent: contentForAI 
      );

      final aiMessage = ChatMessage(
        id: Random().nextDouble().toString(),
        text: aiResponseText,
        sender: ChatMessageSender.ai,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, aiMessage], isAiResponding: false);
      // Save AI message to DB
      await _chatDbService.saveChatMessage(aiMessage, activeSessionId, userId);

    } catch (e) {
      final errorMessageText = "Error: ${e.toString().replaceFirst('Exception: ', '')}";
      final errorAiMessage = ChatMessage(
        id: Random().nextDouble().toString(),
        text: errorMessageText,
        sender: ChatMessageSender.ai, 
        timestamp: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, errorAiMessage], isAiResponding: false, errorMessage: errorMessageText);
      // Optionally, save this error message to DB as an AI message if desired
    }
  }

  // Method to load messages for a specific chat session
  Future<void> loadSession(String sessionId) async {
    // Indicate loading state for messages (optional, could use a separate flag)
    state = state.copyWith(messages: [], currentSessionId: sessionId, isAiResponding: true, clearErrorMessage: true);
    try {
      final messagesData = await _chatDbService.loadChatMessages(sessionId);
      
      // Convert the Map list from DB to List<ChatMessage>
      final loadedMessages = messagesData.map((msgData) {
        // Basic validation/casting
        final id = msgData['id'] as String? ?? Random().nextDouble().toString(); // Use DB id or fallback
        final content = msgData['content'] as String? ?? '';
        final senderString = msgData['sender'] as String? ?? 'ai';
        final timestampString = msgData['timestamp'] as String?;
        
        return ChatMessage(
          id: id,
          text: content,
          sender: senderString == 'user' ? ChatMessageSender.user : ChatMessageSender.ai,
          timestamp: timestampString != null ? DateTime.parse(timestampString) : DateTime.now(),
        );
      }).toList();

      state = state.copyWith(messages: loadedMessages, isAiResponding: false);

    } catch (e) {
      final errorMessageText = "Error loading session: ${e.toString().replaceFirst('Exception: ', '')}";
       final errorAiMessage = ChatMessage(
        id: Random().nextDouble().toString(),
        text: errorMessageText,
        sender: ChatMessageSender.ai, 
        timestamp: DateTime.now(),
      );
      state = state.copyWith(messages: [errorAiMessage], isAiResponding: false, errorMessage: errorMessageText);
    }
  }

  // Method to start a new chat (clears current session and messages)
  void startNewChatSession() {
    state = state.copyWith(
      messages: [], 
      currentSessionId: null, 
      clearCurrentSessionId: true, // Ensure it's actually cleared
      errorMessage: null,
      clearErrorMessage: true,
      isAiResponding: false
    );
  }

  // In the future, you might add methods here like:
  // - void fetchInitialMessages() // To load history from Supabase
  // - void clearChat()
} 
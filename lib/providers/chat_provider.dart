import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eli5/models/chat_message.dart';
import 'package:eli5/models/simplification_style.dart'; // ADDED import
import 'package:eli5/services/openai_service.dart'; // Import OpenAIService
import 'package:eli5/services/content_fetcher_service.dart'; // Import ContentFetcherService
import 'package:eli5/services/chat_db_service.dart'; // Import ChatDbService
import 'package:supabase_flutter/supabase_flutter.dart'; // For Supabase.instance.client.auth.currentUser
import 'dart:math'; // For generating unique IDs for now
import 'package:eli5/providers/history_list_providers.dart'; // Import history providers
import 'package:eli5/main.dart'; // Import for authUserStreamProvider

// Provider for the ChatNotifier state
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    ref,
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
  // Watch the user stream provider
  final authUserAsyncValue = ref.watch(authUserStreamProvider); // Defined in main.dart

  return authUserAsyncValue.when(
    data: (user) async { // User object is available
      print("[chatSessionsProvider] Executing with user: ${user?.id}");
      if (user == null) {
    print("[chatSessionsProvider] User not authenticated, returning empty list.");
    return [];
  }
      final userId = user.id;
  final chatDbService = ref.read(chatDbServiceProvider);
  final allSessions = await chatDbService.loadUserChatSessions(userId);
      print("[chatSessionsProvider] Fetched ${allSessions.length} sessions from DB for user $userId before filtering.");

  // Watch search query and filter type
  final searchQuery = ref.watch(historySearchQueryProvider).toLowerCase();
  final filterType = ref.watch(historyFilterProvider);

  List<Map<String, dynamic>> filteredSessions = allSessions;

  // Apply search query filter
  if (searchQuery.isNotEmpty) {
    filteredSessions = filteredSessions.where((session) {
      final title = (session['title'] as String? ?? '').toLowerCase();
      return title.contains(searchQuery);
    }).toList();
  }

  // Apply type filter
  if (filterType != HistoryFilterType.all) {
    filteredSessions = filteredSessions.where((session) {
      final title = (session['title'] as String? ?? '').toLowerCase();
      // Get the starred status, defaulting to false if null (though it shouldn't be null now)
      final isStarred = session['is_starred'] as bool? ?? false;

      switch (filterType) {
        case HistoryFilterType.image:
          return title.startsWith('scanned:') || title.startsWith('image:');
        case HistoryFilterType.link:
          return title.startsWith('url:') || title.startsWith('link:');
        case HistoryFilterType.text:
          // Text is anything not explicitly image or link (and not starred, eventually)
          // We might want to adjust this later if starred items should also be filterable by type
          return !(title.startsWith('scanned:') || title.startsWith('image:') ||
                   title.startsWith('url:') || title.startsWith('link:'));
        case HistoryFilterType.starred:
          // Now filter based on the actual is_starred field
          return isStarred;
        default: // HistoryFilterType.all is handled by the outer check
          return true; 
      }
    }).toList();
  }
      print("[chatSessionsProvider] Returning ${filteredSessions.length} sessions for user $userId after filtering.");
  return filteredSessions;
    },
    loading: () {
      print("[chatSessionsProvider] Auth user stream loading, returning empty list temporarily.");
      return []; // Or handle loading state appropriately
    },
    error: (err, stack) {
      print("[chatSessionsProvider] Error in auth user stream: $err. Returning empty list.");
      return []; // Or handle error state appropriately
    },
  );
});

// State class to hold both messages and loading status
class ChatState {
  final List<ChatMessage> messages;
  final bool isAiResponding;
  final bool isProcessingImage; // Added for OCR/Image processing state
  final String? errorMessage;
  final String? currentSessionId; // Added to store current session ID
  final SimplificationStyle selectedStyle; // ADDED: For selected simplification style

  ChatState({
    this.messages = const [],
    this.isAiResponding = false,
    this.isProcessingImage = false, // Default to false
    this.errorMessage,
    this.currentSessionId,
    this.selectedStyle = SimplificationStyle.eli5, // ADDED: Default to ELI5
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isAiResponding,
    bool? isProcessingImage, // Added
    String? errorMessage,
    bool clearErrorMessage = false,
    String? currentSessionId, // For updating session ID
    bool clearCurrentSessionId = false, // For clearing session ID (e.g., new chat)
    SimplificationStyle? selectedStyle, // ADDED parameter
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isAiResponding: isAiResponding ?? this.isAiResponding,
      isProcessingImage: isProcessingImage ?? this.isProcessingImage, // Added
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      currentSessionId: clearCurrentSessionId ? null : currentSessionId ?? this.currentSessionId,
      selectedStyle: selectedStyle ?? this.selectedStyle, // ADDED assignment
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref; // Add Ref
  final OpenAIService _openAIService;
  final ContentFetcherService _contentFetcherService;
  final ChatDbService _chatDbService; // Add ChatDbService instance

  ChatNotifier(this._ref, this._openAIService, this._contentFetcherService, this._chatDbService) : super(ChatState());

  // Method to explicitly set the image processing state
  void setProcessingImageState(bool isProcessing) {
    state = state.copyWith(isProcessingImage: isProcessing);
  }

  // New method to add a message directly to the UI for display
  void addDisplayMessage(String text, ChatMessageSender sender) {
    final displayMessage = ChatMessage(
      id: Random().nextDouble().toString(), 
      text: text,
      sender: sender,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, displayMessage]);
    // This message is for immediate UI feedback and is not saved to DB here.
  }

  // ADDED: Method to update the selected simplification style
  void setSelectedStyle(SimplificationStyle style) {
    state = state.copyWith(selectedStyle: style);
  }

  Future<void> sendMessageAndGetResponse(String rawInputText, {bool isFromOcr = false}) async {
    if (rawInputText.isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      state = state.copyWith(isAiResponding: false, errorMessage: "User not authenticated.");
      final errorMsg = ChatMessage(id: "error_auth", text: "Error: You must be logged in to chat.", sender: ChatMessageSender.ai, timestamp: DateTime.now());
      state = state.copyWith(messages: [...state.messages, errorMsg]);
      return;
    }

    InputType determinedInputType = InputType.text; // Default
    if (isFromOcr) {
      determinedInputType = InputType.ocr;
    } else if (_contentFetcherService.isYouTubeUrl(rawInputText) || _contentFetcherService.isValidUrl(rawInputText)) {
      determinedInputType = InputType.url;
    } else if (rawInputText.trim().endsWith('?')) {
      determinedInputType = InputType.question;
    }

    ChatMessage userMessage = ChatMessage(
        id: Random().nextDouble().toString(), 
        text: rawInputText,
        sender: ChatMessageSender.user,
        timestamp: DateTime.now(),
      inputType: determinedInputType, // Assign determined type
      );

    // Add user message to UI immediately only if it wasn't from OCR (which uses addDisplayMessage)
    if (!isFromOcr) {
      state = state.copyWith(messages: [...state.messages, userMessage], isAiResponding: true, clearErrorMessage: true);
    } else {
        state = state.copyWith(isAiResponding: true, clearErrorMessage: true); // Just set loading state
    }
    
    String? existingSessionId = state.currentSessionId; 
    String activeSessionId;
    bool isNewSession = existingSessionId == null; // Track if it's a new session

    try {
      String initialContentForTitle = rawInputText;
      if (existingSessionId == null) {
        const int titleMaxLength = 30;
        String previewText = rawInputText.substring(0, min(rawInputText.length, titleMaxLength));
        if (rawInputText.length > titleMaxLength) { previewText += "..."; }

        switch(determinedInputType) {
          case InputType.ocr: initialContentForTitle = "Scanned: $previewText"; break;
          case InputType.url: initialContentForTitle = "URL: $previewText"; break;
          case InputType.question: initialContentForTitle = "Question: $previewText"; break;
          case InputType.text: initialContentForTitle = "Text: $previewText"; break;
        }
      }

      activeSessionId = await _chatDbService.ensureChatSession(
        userId,
        existingSessionId: existingSessionId,
        initialMessageContent: existingSessionId == null ? initialContentForTitle : null, 
      );
      if (state.currentSessionId != activeSessionId) {
        state = state.copyWith(currentSessionId: activeSessionId);
      }

      // If a new session was created, invalidate the chatSessionsProvider
      if (isNewSession) {
        _ref.invalidate(chatSessionsProvider);
      }

      // Save the user message (with its inputType) to DB
      // print("CHAT_PROVIDER: Attempting to save USER message..."); // DEBUG
      await _chatDbService.saveChatMessage(userMessage, activeSessionId, userId);
      // print("CHAT_PROVIDER: USER message save call completed."); // DEBUG

      String contentForAI = rawInputText;
      if (determinedInputType == InputType.url) {
         if (_contentFetcherService.isYouTubeUrl(rawInputText)) {
        final transcript = await _contentFetcherService.fetchYouTubeTranscript(rawInputText);
        contentForAI = "The user shared this YouTube video: $rawInputText\n\nPlease ELI5 the following transcript:\n\n$transcript";
         } else {
        final webContent = await _contentFetcherService.fetchAndParseUrl(rawInputText);
        contentForAI = "The user shared this webpage: $rawInputText\n\nPlease ELI5 the following content from the webpage:\n\n$webContent";
         }
      }
      // If isFromOcr is true, contentForAI is already the extracted text.
      // The system prompt in OpenAIService will guide the selected style.

      // DEBUG: Print length of contentForAI if it was a URL, to monitor for very long inputs
      if (determinedInputType == InputType.url) {
        print("[ChatProvider] Length of contentForAI (URL content) before sending to OpenAI: ${contentForAI.length} characters.");
      }

      final aiResponseText = await _openAIService.getChatResponse(
        state.messages, 
        effectiveLastUserMessageContent: contentForAI,
        style: state.selectedStyle, // UNCOMMENTED: Pass the selected style
      );

      final aiMessage = ChatMessage(
        id: Random().nextDouble().toString(),
        text: aiResponseText,
        sender: ChatMessageSender.ai,
        timestamp: DateTime.now(),
        isPlaceholderSummary: isFromOcr, // Only AI response to OCR needs placeholder
        inputType: determinedInputType, // AI message inherits inputType from user message
      );
      // Add AI message to state immediately *before* saving
      state = state.copyWith(messages: [...state.messages, aiMessage], isAiResponding: false);

      // Save AI message
      // print("CHAT_PROVIDER: Attempting to save AI message..."); // DEBUG
      await _chatDbService.saveChatMessage(aiMessage, activeSessionId, userId);
      // print("CHAT_PROVIDER: AI message save call completed."); // DEBUG

    } catch (e) {
      // print("CHAT_PROVIDER: ERROR in sendMessageAndGetResponse: $e"); // DEBUG Error
      final errorMessageText = "Error: ${e.toString().replaceFirst('Exception: ', '')}";
      final errorAiMessage = ChatMessage(
        id: Random().nextDouble().toString(),
        text: errorMessageText,
        sender: ChatMessageSender.ai, 
        timestamp: DateTime.now(),
      );
      // Ensure error message is added to state even if AI save fails
      // Check if the error message is already the last one to avoid duplicates
      if (state.messages.isEmpty || state.messages.last.id != errorAiMessage.id) {
      state = state.copyWith(messages: [...state.messages, errorAiMessage], isAiResponding: false, errorMessage: errorMessageText);
      } else {
         // Already have the error message, just ensure loading state is false
          state = state.copyWith(isAiResponding: false, errorMessage: errorMessageText);
      }
    }
  }

  Future<void> loadSession(String sessionId) async {
    state = state.copyWith(currentSessionId: sessionId, messages: [], isAiResponding: true, clearErrorMessage: true);
    try {
      final messagesData = await _chatDbService.loadChatMessages(sessionId); // Returns List<Map<String, dynamic>>
      
      List<ChatMessage> loadedChatMessages = [];
      for (int i = 0; i < messagesData.length; i++) {
        final msgData = messagesData[i];
        final id = msgData['id'] as String? ?? Random().nextDouble().toString();
        final content = msgData['content'] as String? ?? '';
        final senderString = msgData['sender'] as String? ?? 'ai';
        final timestampString = msgData['timestamp'] as String?;
        // final isPlaceholder = msgData['is_placeholder_summary'] as bool? ?? false; // Not directly used in ChatMessage constructor from this data
        final inputTypeString = msgData['input_type'] as String?;
        final sender = senderString == 'user' ? ChatMessageSender.user : ChatMessageSender.ai;
        final timestamp = timestampString != null ? DateTime.parse(timestampString) : DateTime.now();
        final inputType = ChatMessage.inputTypeFromString(inputTypeString);
        
        String? displayOverrideValue; 

        // Set Display Override Logic ONLY for the first USER message 
        if (i == 0 && sender == ChatMessageSender.user) {
           if (inputType == InputType.ocr) {
              displayOverrideValue = "Input from Image"; 
           } else if (inputType == InputType.url) {
              try {
                Uri uri = Uri.parse(content);
                 displayOverrideValue = "Input from Link: ${uri.host}";
              } catch (_) {
                displayOverrideValue = "Input from Link";
              }
           } else if (content.length > 150 && inputType == InputType.text) {
              displayOverrideValue = "Original Text Input";
           }
        }

        loadedChatMessages.add(ChatMessage(
          id: id,
          text: content,
          sender: sender,
          timestamp: timestamp,
          // isPlaceholderSummary: isPlaceholder, // Not directly used here, defaults in model
          inputType: inputType,
          displayOverride: displayOverrideValue, 
        ));
      }

      state = state.copyWith(messages: loadedChatMessages, isAiResponding: false);

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

  void clearCurrentSessionId() {
    state = state.copyWith(
      clearCurrentSessionId: true, // Uses the specific flag in copyWith
      messages: [], // Clear messages for the new session
      isAiResponding: false, // Reset AI responding state
      clearErrorMessage: true // Clear any previous error messages
    );
    // No need to call _chatDbService.startNewSession() here as
    // sendMessageAndGetResponse will handle starting a new session if currentSessionId is null.
  }

  Future<void> deleteSession(String sessionId) async {
    // Implementation of deleteSession method
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
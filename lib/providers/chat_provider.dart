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
  final bool isProcessingInput; // CHANGED: Was isProcessingImage
  final String? errorMessage;
  final String? currentSessionId; // Added to store current session ID
  final SimplificationStyle selectedStyle; // ADDED: For selected simplification style

  ChatState({
    this.messages = const [],
    this.isAiResponding = false,
    this.isProcessingInput = false, // CHANGED: Was isProcessingImage, default to false
    this.errorMessage,
    this.currentSessionId,
    this.selectedStyle = SimplificationStyle.eli5, // ADDED: Default to ELI5
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isAiResponding,
    bool? isProcessingInput, // CHANGED: Was isProcessingImage
    String? errorMessage,
    bool clearErrorMessage = false,
    String? currentSessionId, // For updating session ID
    bool clearCurrentSessionId = false, // For clearing session ID (e.g., new chat)
    SimplificationStyle? selectedStyle, // ADDED parameter
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isAiResponding: isAiResponding ?? this.isAiResponding,
      isProcessingInput: isProcessingInput ?? this.isProcessingInput, // CHANGED: Was isProcessingImage
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

  // Method to explicitly set the input processing state
  void setProcessingInputState(bool isProcessing) { // CHANGED: Was setProcessingImageState
    state = state.copyWith(isProcessingInput: isProcessing); // CHANGED: Was isProcessingImage
  }

  // New method to add a message directly to the UI for display
  void addDisplayMessage(String text, ChatMessageSender sender, {InputType inputType = InputType.text}) { // ADDED inputType parameter
    final displayMessage = ChatMessage(
      id: Random().nextDouble().toString(), 
      text: text,
      sender: sender,
      timestamp: DateTime.now(),
      inputType: inputType, // ADDED: Use passed inputType
    );
    state = state.copyWith(messages: [...state.messages, displayMessage]);
    // This message is for immediate UI feedback and is not saved to DB here.
  }

  // ADDED: Method to update the selected simplification style
  void setSelectedStyle(SimplificationStyle style) {
    state = state.copyWith(selectedStyle: style);
  }

  Future<void> sendMessageAndGetResponse(String text, {InputType inputType = InputType.text}) async { // CHANGED: Replaced boolean flags with InputType
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      state = state.copyWith(errorMessage: "User not authenticated. Please log in.");
      return;
    }

    String effectiveMessageContent = text;
    String? userMessageDisplayOverride;
    String placeholderPrefix = "";

    // Determine placeholder prefix and display override based on inputType
    switch (inputType) {
      case InputType.ocr:
      case InputType.image: // Consolidate image and ocr for display override
        placeholderPrefix = "Scanned: ";
        inputType = InputType.ocr; // Standardize to ocr if it was image for this path
        break;
      case InputType.url:
        placeholderPrefix = "URL: ";
        break;
      case InputType.pdf:
        placeholderPrefix = "PDF: ";
        break;
      case InputType.file:
        placeholderPrefix = "File: ";
        break;
      case InputType.text:
      case InputType.question: // Default, no prefix or special handling here for override
      default:
        placeholderPrefix = "";
        break;
    }

    if (placeholderPrefix.isNotEmpty) {
      userMessageDisplayOverride = "$placeholderPrefix${text.substring(0, min(text.length, 50))}${text.length > 50 ? '...' : ''}";
    }

    final userMessage = ChatMessage(
      text: effectiveMessageContent, // Store full text for API
      displayOverride: userMessageDisplayOverride, // Display override for UI
      sender: ChatMessageSender.user,
      timestamp: DateTime.now(),
      inputType: inputType, // Use the determined/passed inputType
    );

    state = state.copyWith(messages: [...state.messages, userMessage], isAiResponding: true, isProcessingInput: false, errorMessage: null, clearErrorMessage: true); // Ensure isProcessingInput is false now
    final currentSessionId = await _chatDbService.ensureChatSession(userId, existingSessionId: state.currentSessionId, initialMessageContent: effectiveMessageContent, inputType: inputType);
    state = state.copyWith(currentSessionId: currentSessionId); // Update session ID in state
    await _chatDbService.saveChatMessage(userMessage, currentSessionId, userId); // Save user message

    // Prepare history for API, ensuring it's a list of ChatMessage objects
    List<ChatMessage> historyForApi = List<ChatMessage>.from(state.messages);

    String? contentToExplain = effectiveMessageContent; // Default to user's text

    // If it's a URL, fetch its content before sending to OpenAI
    if (inputType == InputType.url) { // CHANGED: Check inputType
      try {
        // Add a temporary "Fetching content..." message for the AI response slot
        final tempFetchingMessage = ChatMessage(
          text: "Fetching content from URL...",
          sender: ChatMessageSender.ai,
          timestamp: DateTime.now(),
          displayOverride: "Fetching content from URL...",
          isPlaceholderSummary: true, 
        );
        state = state.copyWith(messages: [...state.messages, tempFetchingMessage], isAiResponding: true);
        
        contentToExplain = await _contentFetcherService.fetchAndParseUrl(text);
        effectiveMessageContent = contentToExplain ?? "Could not fetch content from URL."; // Update effective content

        // Remove the temporary "Fetching content..." message
        state = state.copyWith(
          messages: state.messages.where((msg) => msg.id != tempFetchingMessage.id).toList(),
        );

        if (contentToExplain == null) {
          final errorMessage = ChatMessage(
            text: "Sorry, I couldn't fetch content from that URL. Please try another one.",
            sender: ChatMessageSender.ai,
            timestamp: DateTime.now(),
          );
          state = state.copyWith(messages: [...state.messages, errorMessage], isAiResponding: false);
          await _chatDbService.saveChatMessage(errorMessage, currentSessionId, userId); // Save error message
          return;
        }
      } catch (e) {
        final errorMessage = ChatMessage(
          text: "Error fetching URL content: ${e.toString()}",
          sender: ChatMessageSender.ai,
          timestamp: DateTime.now(),
        );
        state = state.copyWith(messages: [...state.messages, errorMessage], isAiResponding: false);
        await _chatDbService.saveChatMessage(errorMessage, currentSessionId, userId); // Save error message
        return;
      }
    }

    try {
      // Use the effective content (original text or fetched from URL) for the AI
      final ExplanationResult explanationResult = await _openAIService.getChatResponse(
        historyForApi, 
        effectiveLastUserMessageContent: contentToExplain, // Send the content to be explained
        style: state.selectedStyle 
      );

      // Create the AI message with the same inputType as the user's message
      final aiMessage = ChatMessage(
        text: explanationResult.explanation,
        sender: ChatMessageSender.ai,
        timestamp: DateTime.now(),
        relatedConcepts: explanationResult.relatedConcepts,
        inputType: userMessage.inputType, // Mirror user's input type
      );
      state = state.copyWith(messages: [...state.messages, aiMessage], isAiResponding: false, isProcessingInput: false);
      await _chatDbService.saveChatMessage(aiMessage, currentSessionId, userId); // Save AI message
    } catch (e) {
      final errorMessage = ChatMessage(
        text: "Sorry, I couldn't get a response: ${e.toString()}",
        sender: ChatMessageSender.ai,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, errorMessage], isAiResponding: false, errorMessage: e.toString());
      await _chatDbService.saveChatMessage(errorMessage, currentSessionId, userId); // Save error message
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

  Future<void> recordExplanationFeedback(String messageId, int rating) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print("Cannot record feedback: User not authenticated.");
      // Optionally, update state with an error message for the UI if needed
      // state = state.copyWith(errorMessage: "You must be logged in to rate explanations.");
      return;
    }
    try {
      await _chatDbService.saveExplanationFeedback(messageId, userId, rating);
      print("Feedback recorded for message $messageId: rating $rating");

      // Update the userRating for the specific message in the state
      final updatedMessages = state.messages.map((msg) {
        if (msg.id == messageId) {
          // Create a new ChatMessage instance with the updated rating
          // This is important for immutability and to trigger UI updates.
          return ChatMessage(
            id: msg.id,
            text: msg.text,
            sender: msg.sender,
            timestamp: msg.timestamp,
            isPlaceholderSummary: msg.isPlaceholderSummary,
            displayOverride: msg.displayOverride,
            inputType: msg.inputType,
            userRating: msg.userRating == rating ? null : rating, // Toggle: if same rating, clear, else set new rating
          );
        }
        return msg;
      }).toList();

      // DEBUG: Confirm the rating is updated in the new message list
      try {
        final msgToLog = updatedMessages.firstWhere((m) => m.id == messageId);
        print("[ChatNotifier] Message ${msgToLog.id} userRating after update: ${msgToLog.userRating}");
      } catch (e) {
        print("[ChatNotifier] Debug: Message with id $messageId not found in updatedMessages for logging.");
      }

      state = state.copyWith(messages: updatedMessages);

      // Optionally, update the UI to reflect that feedback has been given for this message
      // This might involve adding a property to ChatMessage model and updating state
    } catch (e) {
      print("Error recording feedback: $e");
      // Optionally, update state with an error message
      // state = state.copyWith(errorMessage: "Failed to record feedback: ${e.toString()}");
    }
  }

  Future<void> recordExplanationReport(String messageId, String category, String? comment) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print("Cannot record report: User not authenticated.");
      // Optionally, update state with an error message for the UI if needed
      return;
    }
    try {
      await _chatDbService.saveExplanationReport(messageId, userId, category, comment);
      print("Report recorded for message $messageId: category '$category'");
      // Optionally, update UI to indicate message has been reported (e.g., disable report button or show confirmation)
      // For now, we mostly rely on a Snackbar or dialog closing to give feedback.
    } catch (e) {
      print("Error recording report: $e");
      // Optionally, update state with an error message
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
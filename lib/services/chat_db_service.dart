import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eli5/models/chat_message.dart';
import 'dart:math'; // For min function if used for title

final supabase = Supabase.instance.client;

class ChatDbService {
  // Ensures a chat session exists. If existingSessionId is provided and valid, returns it.
  // Otherwise, creates a new session for the given userId and returns its ID.
  Future<String> ensureChatSession(
    String userId, {
    String? existingSessionId, 
    String? initialMessageContent,
    InputType inputType = InputType.text,
    String? fileName,
  }) async {
    if (existingSessionId != null) {
      // Optionally, verify if the session ID exists and belongs to the user if needed
      // For now, we assume if an ID is passed, it's valid for the current context.
      return existingSessionId;
    }

    // Create a new session
    String title = "New Chat";
    if (initialMessageContent != null && initialMessageContent.isNotEmpty) {
      String baseContent = initialMessageContent.substring(0, min(initialMessageContent.length, 50));
      if (initialMessageContent.length > 50) baseContent += "...";

      switch (inputType) {
        case InputType.ocr:
        case InputType.image:
          title = "Scanned: $baseContent";
          break;
        case InputType.url:
           try {
            Uri uri = Uri.parse(initialMessageContent); // Use full content for URI parsing
            title = "URL: ${uri.host}";
          } catch (_) {
            title = "URL: $baseContent"; // Fallback if URI parsing fails
          }
          break;
        case InputType.pdf:
          title = "PDF: ${fileName ?? baseContent}";
          break;
        case InputType.file: // .txt files
          title = "File: ${fileName ?? baseContent}";
          break;
        case InputType.text:
        case InputType.question:
        default:
          title = baseContent;
          break;
      }
    }

    try {
      final response = await supabase
          .from('chat_sessions')
          .insert({
            'user_id': userId, 
            'title': title,
            'initial_input_type': inputType.name,
          })
          .select('id') // Select the id of the newly inserted row
          .single();    // Expect a single row back
      
      return response['id']; // The ID of the new session
    } catch (e) {
      // print("Error creating chat session: $e"); // For debugging
      throw Exception("Failed to create or ensure chat session: ${e.toString()}");
    }
  }

  // Saves a ChatMessage to the database.
  Future<void> saveChatMessage(ChatMessage message, String sessionId, String userId) async {
    try {
      await supabase
          .from('chat_messages')
          .insert(message.toJsonForDb(sessionId, userId));
    } catch (e) {
      // print("Error saving chat message: $e"); // For debugging
      throw Exception("Failed to save chat message: ${e.toString()}");
    }
  }

  // Loads all chat sessions for a given user, ordered by the most recently updated.
  Future<List<Map<String, dynamic>>> loadUserChatSessions(String userId) async {
    try {
      final response = await supabase
          .from('chat_sessions')
          .select('id, title, created_at, updated_at, is_starred, initial_input_type')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
      
      // The response is List<Map<String, dynamic>> directly if successful
      return response;
    } catch (e) {
      // print("Error loading chat sessions: $e"); // For debugging
      throw Exception("Failed to load chat sessions: ${e.toString()}");
    }
  }

  // Loads all messages for a given session ID, ordered by timestamp.
  Future<List<Map<String, dynamic>>> loadChatMessages(String sessionId) async {
    try {
      final response = await supabase
          .from('chat_messages')
          // Select all the fields needed by ChatMessage model
          .select('id, content, sender, timestamp, is_placeholder_summary, input_type, related_concepts')
          .eq('session_id', sessionId)
          .order('timestamp', ascending: true); 
      
      return response;
    } catch (e) {
      // print("Error loading chat messages for session $sessionId: $e");
      throw Exception("Failed to load chat messages: ${e.toString()}");
    }
  }

  // Deletes a chat session and its associated messages (due to CASCADE)
  Future<void> deleteChatSession(String sessionId) async {
    try {
      await supabase
          .from('chat_sessions')
          .delete()
          .eq('id', sessionId);
    } catch (e) {
      // print("Error deleting chat session $sessionId: $e"); // For debugging
      throw Exception("Failed to delete chat session: ${e.toString()}");
    }
  }

  // Deletes multiple chat sessions and their associated messages.
  Future<void> deleteChatSessions(List<String> sessionIds) async {
    if (sessionIds.isEmpty) {
      return; // Nothing to delete
    }
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception("User not authenticated to delete sessions.");
    }

    try {
      // First, delete associated messages to ensure data integrity if CASCADE isn't fully relied upon for batch
      // Ensure that users can only delete messages from sessions they own indirectly by filtering sessions by user_id next.
      // A more robust way would be to join or use an RLS policy that enforces this for messages too.
      // For now, we rely on the session deletion check.
      await supabase
          .from('chat_messages')
          .delete()
          .inFilter('session_id', sessionIds);

      // Then, delete the sessions themselves, ensuring they belong to the current user.
      // Note: The .eq('user_id', userId) here is crucial for security.
      await supabase
          .from('chat_sessions')
          .delete()
          .inFilter('id', sessionIds)
          .eq('user_id', userId); // Crucial: Only delete sessions belonging to the user

    } catch (e) {
      // print("Error deleting chat sessions: $e"); // For debugging
      throw Exception("Failed to delete chat sessions: ${e.toString()}");
    }
  }

  // Renames a chat session
  Future<void> renameChatSession(String sessionId, String newTitle) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception("User not authenticated to rename session.");
    }
    try {
      await supabase
          .from('chat_sessions')
          .update({'title': newTitle})
          .eq('id', sessionId)
          .eq('user_id', userId); // Ensure user can only rename their own sessions
    } catch (e) {
      // print("Error renaming chat session $sessionId: $e"); // For debugging
      throw Exception("Failed to rename chat session: ${e.toString()}");
    }
  }

  // Updates the starred status of a chat session
  Future<void> updateStarredStatus(String sessionId, bool isStarred) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception("User not authenticated to update starred status.");
    }
    try {
      await supabase
          .from('chat_sessions')
          .update({'is_starred': isStarred})
          .eq('id', sessionId)
          .eq('user_id', userId); // Ensure user can only update their own sessions
    } catch (e) {
      // print("Error updating starred status for session $sessionId: $e"); // For debugging
      throw Exception("Failed to update starred status: ${e.toString()}");
    }
  }

  // Method to update starred status for multiple sessions
  Future<void> updateMultipleSessionsStarredStatus(List<String> sessionIds, bool newStarredState) async {
    if (sessionIds.isEmpty) {
      return; // Nothing to update
    }
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception("User not authenticated to update starred status for multiple sessions.");
    }

    try {
      await supabase
          .from('chat_sessions')
          .update({'is_starred': newStarredState})
          .inFilter('id', sessionIds)
          .eq('user_id', userId); // Crucial: Only update sessions belonging to the user
    } catch (e) {
      // print("Error updating starred status for multiple sessions: $e"); // For debugging
      throw Exception("Failed to update starred status for multiple sessions: ${e.toString()}");
    }
  }

  // Saves feedback for an explanation
  Future<void> saveExplanationFeedback(String messageId, String userId, int rating) async {
    if (userId.isEmpty) {
      throw Exception("User not authenticated to save feedback.");
    }
    try {
      // Upsert the rating. If a report exists, it will be preserved.
      // If no entry exists, a new one is created with the rating.
      // If an entry exists, its rating is updated.
      await supabase.from('explanation_feedback').upsert(
        {
          'message_id': messageId,
          'user_id': userId,
          'rating': rating,
          // 'created_at' will be set on insert, and preserved on update by default with upsert
          // unless explicitly part of the upserted data for change.
        },
        onConflict: 'message_id, user_id', // Specify conflict target for Supabase
      );
    } catch (e) {
      // print("Error saving explanation feedback: $e");
      throw Exception("Failed to save explanation feedback: ${e.toString()}");
    }
  }

  // Saves or updates a report for an explanation
  Future<void> saveExplanationReport(String messageId, String userId, String category, String? comment) async {
    if (userId.isEmpty) {
      throw Exception("User not authenticated to save report.");
    }
    try {
      // Prepare the data for upserting the report details.
      // We want to set or update the report_category and report_comment.
      // If a rating already exists, it should be preserved if not explicitly changed here.
      // If no rating exists, it should remain null unless this interaction also sets it.
      // The `created_at` timestamp should ideally be set on the first interaction (rating or report)
      // and preserved on subsequent updates to that feedback entry.

      // First, fetch existing rating and timestamp if any, to preserve them.
      final existingEntry = await supabase
          .from('explanation_feedback')
          .select('rating, created_at')
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .maybeSingle();

      final Map<String, dynamic> dataToUpsert = {
        'message_id': messageId,
        'user_id': userId,
        'report_category': category,
        'report_comment': comment,
      };

      if (existingEntry != null) {
        // If entry exists, preserve its original rating unless this upsert is meant to change it (it's not here).
        if (existingEntry['rating'] != null) {
          dataToUpsert['rating'] = existingEntry['rating'];
        }
        // Preserve original creation timestamp.
        if (existingEntry['created_at'] != null) {
         dataToUpsert['created_at'] = existingEntry['created_at'];
        } else {
          // If for some reason created_at was null but entry existed, set it now.
          dataToUpsert['created_at'] = DateTime.now().toIso8601String();
        }
      } else {
        // New entry, set created_at. Rating will be null unless explicitly added.
        dataToUpsert['created_at'] = DateTime.now().toIso8601String();
      }
      
      await supabase.from('explanation_feedback').upsert(
        dataToUpsert,
        onConflict: 'message_id, user_id',
      );

    } catch (e) {
      // print("Error saving explanation report: $e");
      throw Exception("Failed to save explanation report: ${e.toString()}");
    }
  }

  // --- Methods for loading chat history will be added later ---
  // Future<List<ChatMessage>> loadChatMessages(String sessionId) async { ... }
} 
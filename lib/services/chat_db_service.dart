import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eli5/models/chat_message.dart';
import 'dart:math'; // For min function if used for title

final supabase = Supabase.instance.client;

class ChatDbService {
  // Ensures a chat session exists. If existingSessionId is provided and valid, returns it.
  // Otherwise, creates a new session for the given userId and returns its ID.
  Future<String> ensureChatSession(String userId, {String? existingSessionId, String? initialMessageContent}) async {
    if (existingSessionId != null) {
      // Optionally, verify if the session ID exists and belongs to the user if needed
      // For now, we assume if an ID is passed, it's valid for the current context.
      return existingSessionId;
    }

    // Create a new session
    String title = "New Chat";
    if (initialMessageContent != null && initialMessageContent.isNotEmpty) {
      title = initialMessageContent.substring(0, min(initialMessageContent.length, 50));
      if (initialMessageContent.length > 50) title += "...";
    }

    try {
      final response = await supabase
          .from('chat_sessions')
          .insert({'user_id': userId, 'title': title})
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
          .select('id, title, created_at, updated_at') // Select desired fields
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
          .select('id, content, sender, timestamp') // Select necessary fields
          .eq('session_id', sessionId)
          .order('timestamp', ascending: true); // Order by time, oldest first
      
      // Response is List<Map<String, dynamic>>
      return response;
    } catch (e) {
      // print("Error loading chat messages for session $sessionId: $e"); // For debugging
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

  // --- Methods for loading chat history will be added later ---
  // Future<List<ChatMessage>> loadChatMessages(String sessionId) async { ... }
} 
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import '../models/history_entry.dart';

class HistoryService {
  static const String _historyKey = 'simplification_history';
  static const int _maxHistorySize = 50; // Limit history size

  // Get all history entries
  Future<List<HistoryEntry>> getHistoryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_historyKey);

    if (historyJson == null) {
      return []; // No history saved yet
    }

    try {
      final List<dynamic> decodedList = jsonDecode(historyJson) as List;
      final List<HistoryEntry> entries = decodedList
          .map((item) => HistoryEntry.fromJson(item as Map<String, dynamic>))
          .toList();
      // Return in reverse chronological order (newest first)
      return entries.reversed.toList();
    } catch (e) {
      debugPrint('Error decoding history: $e');
      // If decoding fails, clear corrupted data
      await clearHistory(); 
      return [];
    }
  }

  // Add a new entry to the history
  Future<void> addHistoryEntry(HistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_historyKey);
    List<dynamic> decodedList = [];

    if (historyJson != null) {
      try {
        decodedList = jsonDecode(historyJson) as List;
      } catch (e) {
        debugPrint('Error decoding existing history before adding: $e');
        // Clear corrupted data if decoding fails
        decodedList = []; 
      }
    }

    // Convert existing dynamic list items to HistoryEntry for sorting/limiting
    List<HistoryEntry> currentEntries = decodedList
        .map((item) => HistoryEntry.fromJson(item as Map<String, dynamic>))
        .toList();

    // Add the new entry
    currentEntries.add(entry);

    // Sort by timestamp (oldest first) to easily remove oldest if over limit
    currentEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Limit the history size
    if (currentEntries.length > _maxHistorySize) {
      currentEntries = currentEntries.sublist(currentEntries.length - _maxHistorySize);
    }

    // Convert back to list of maps for JSON encoding
    final List<Map<String, dynamic>> listToSave = 
        currentEntries.map((e) => e.toJson()).toList();

    // Save the updated list
    await prefs.setString(_historyKey, jsonEncode(listToSave));
  }

  // Clear all history (useful for debugging or user action)
  Future<void> clearHistory() async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove(_historyKey);
     debugPrint('History cleared.');
  }
} 
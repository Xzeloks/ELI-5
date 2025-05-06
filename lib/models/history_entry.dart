// import 'dart:convert'; // REMOVED - Unused

enum InputType { text, url, video, question }

class HistoryEntry {
  final String originalInput;
  final String simplifiedOutput;
  final DateTime timestamp;
  final InputType inputType;
  // Using timestamp as a simple unique ID for now
  String get id => timestamp.toIso8601String();

  HistoryEntry({
    required this.originalInput,
    required this.simplifiedOutput,
    required this.timestamp,
    required this.inputType,
  });

  // Convert a HistoryEntry into a Map for JSON encoding
  Map<String, dynamic> toJson() => {
        'originalInput': originalInput,
        'simplifiedOutput': simplifiedOutput,
        'timestamp': timestamp.toIso8601String(),
        'inputType': inputType.toString(), // Store enum as string
      };

  // Create a HistoryEntry from a Map (decoded JSON)
  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      originalInput: json['originalInput'] as String,
      simplifiedOutput: json['simplifiedOutput'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      // Convert string back to enum
      inputType: InputType.values.firstWhere(
          (e) => e.toString() == json['inputType'],
          orElse: () => InputType.text), // Default fallback
    );
  }
} 
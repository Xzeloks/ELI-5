import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../models/history_entry.dart';
import 'package:eli5/utils/snackbar_helper.dart';
// Consider adding intl package for better date formatting if needed

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();
  late Future<List<HistoryEntry>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = _historyService.getHistoryEntries();
    });
  }

  Future<void> _clearHistory() async {
    // Optional: Add confirmation dialog
    // Store ScaffoldMessenger before await
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Clear'),
              content: const Text('Are you sure you want to clear all history?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('Clear'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ?? false; // Default to false if dialog dismissed

    if (confirm && mounted) {
      await _historyService.clearHistory();
      _loadHistory(); // Refresh the list
      // Use the stored ScaffoldMessenger inside the mounted check
      showStyledSnackBar(context, message: 'History cleared.');
    }
  }

  IconData _getIconForType(InputType type) {
      switch (type) {
        case InputType.text:
          return Icons.text_fields;
        case InputType.url:
          return Icons.link;
        case InputType.video:
          return Icons.video_library;
        case InputType.question:
          return Icons.question_answer;
        // default: // REMOVED - Unreachable
        //   return Icons.notes;
      }
  }

  // Function to format date nicely (replace with intl package for better localization)
  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0 && dt.day == now.day) {
      // Today: return time
      return 'Today, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && dt.day == now.day - 1)) {
        // Yesterday
        return 'Yesterday, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      // Older: return date
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear History',
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: FutureBuilder<List<HistoryEntry>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading history: ${snapshot.error}'));
          }

          final List<HistoryEntry> entries = snapshot.data ?? [];

          if (entries.isEmpty) {
            return const Center(child: Text('History is empty.'));
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                leading: Icon(_getIconForType(entry.inputType)),
                title: Text(
                  entry.originalInput,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _formatTimestamp(entry.timestamp),
                ),
                onTap: () {
                  // Optional: Implement navigation to a detail view
                  // Or reuse the main screen with this data?
                  debugPrint('Tapped history item: ${entry.id}');
                  // Example: show details in a dialog
                   showDialog(
                     context: context,
                     builder: (context) => AlertDialog(
                       title: const Text('History Details'),
                       content: SingleChildScrollView(
                         child: ListBody(
                           children: <Widget>[
                             Text('Type: ${entry.inputType.toString().split('.').last}'),
                             const SizedBox(height: 8),
                             Text('Timestamp: ${_formatTimestamp(entry.timestamp)}'),
                             const Divider(height: 20),
                             const Text('Original Input:', style: TextStyle(fontWeight: FontWeight.bold)),
                             SelectableText(entry.originalInput),
                             const Divider(height: 20),
                             const Text('Simplified Output:', style: TextStyle(fontWeight: FontWeight.bold)),
                             SelectableText(entry.simplifiedOutput),
                           ],
                         ),
                       ),
                       actions: <Widget>[
                         TextButton(
                           child: const Text('Close'),
                           onPressed: () => Navigator.of(context).pop(),
                         ),
                       ],
                     ),
                   );
                },
              );
            },
          );
        },
      ),
    );
  }
} 
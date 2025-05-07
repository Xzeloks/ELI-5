import 'package:eli5/providers/chat_provider.dart';
import 'package:eli5/services/chat_db_service.dart'; // Import ChatDbService
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting

class ChatSessionsDrawer extends ConsumerWidget {
  const ChatSessionsDrawer({super.key});

  // Helper function to show delete confirmation dialog
  Future<bool?> _showDeleteConfirmationDialog(BuildContext context, String sessionTitle) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Chat Session?'),
          content: Text('Are you sure you want to delete the session "$sessionTitle"? This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // Return false
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(true); // Return true
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsyncValue = ref.watch(chatSessionsProvider);
    final currentSessionId = ref.watch(chatProvider.select((state) => state.currentSessionId)); // Get current session ID

    return Drawer(
      child: Column(
        children: [
          AppBar(
            title: const Text('Chat History'),
            automaticallyImplyLeading: false, // Removes back button from drawer appbar
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh History',
                onPressed: () {
                  ref.invalidate(chatSessionsProvider);
                },
              )
            ],
          ),
          Expanded(
            child: sessionsAsyncValue.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  return const Center(child: Text('No chat history yet.'));
                }
                return ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final sessionId = session['id'] as String;
                    final sessionTitle = session['title'] as String? ?? 'Chat Session';
                    final updatedAt = session['updated_at'] != null 
                                      ? DateTime.parse(session['updated_at'] as String)
                                      : null;
                    
                    final bool isSelected = sessionId == currentSessionId; // Check if this is the active session

                    return ListTile(
                      leading: Icon(isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline),
                      title: Text(
                        sessionTitle, 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      ),
                      subtitle: updatedAt != null 
                                  ? Text(DateFormat('MMM d, yyyy hh:mm a').format(updatedAt.toLocal()))
                                  : const Text('No updates yet'),
                      selected: isSelected, // Use the selected property
                      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(76), // Changed from withOpacity(0.3)
                      onTap: () {
                        if (!isSelected) { // Only load if it's not already selected
                           ref.read(chatProvider.notifier).loadSession(sessionId);
                        }
                        Navigator.pop(context); // Close the drawer
                      },
                      trailing: IconButton( // Add delete button
                        icon: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.8)),
                        tooltip: 'Delete Session',
                        onPressed: () async {
                          final confirmed = await _showDeleteConfirmationDialog(context, sessionTitle);
                          if (confirmed == true) {
                            try {
                              // Access ChatDbService via provider
                              await ref.read(chatDbServiceProvider).deleteChatSession(sessionId);
                              // If the deleted session was the active one, start a new chat
                              if (isSelected) {
                                ref.read(chatProvider.notifier).startNewChatSession();
                              }
                              // Refresh the list
                              ref.invalidate(chatSessionsProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Session "$sessionTitle" deleted.')),
                                );
                              }
                            } catch (e) {
                               if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to delete session: ${e.toString()}'), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading sessions: ${err.toString()}')),
            ),
          ),
        ],
      ),
    );
  }
} 
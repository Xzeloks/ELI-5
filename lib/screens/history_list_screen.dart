import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// import 'package:flutter_spinkit/flutter_spinkit.dart'; // No longer needed for main loading
import 'package:eli5/providers/chat_provider.dart';
// import 'package:eli5/services/chat_db_service.dart'; // Needed for delete - Apparently Unused?
import 'package:eli5/screens/app_shell.dart'; // Import for appShellSelectedIndexProvider
import 'package:flutter_feather_icons/flutter_feather_icons.dart'; // Import Feather Icons
import 'package:shimmer/shimmer.dart'; // Import Shimmer
import 'package:grouped_list/grouped_list.dart'; // Import grouped_list
import 'package:eli5/main.dart'; // Import AppColors
// import 'package:eli5/main.dart'; // AppColors might be needed for styling

// New Imports
import 'package:eli5/providers/history_list_providers.dart';
import 'package:eli5/widgets/history/_search_bar.dart';
import 'package:eli5/widgets/history/_filter_row.dart';
import 'package:eli5/widgets/history/_session_tile.dart'; // Uncommented
import 'package:eli5/widgets/history/_multi_select_app_bar.dart'; // Import the new app bar

class HistoryListScreen extends ConsumerWidget {
  const HistoryListScreen({super.key});

  // Helper function to show delete confirmation dialog
  Future<bool?> _showDeleteConfirmationDialog(BuildContext context, String sessionTitle) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) { // Use a different context name for clarity
        return AlertDialog(
          title: const Text('Delete Chat Session?'),
          content: Text('Are you sure you want to delete the session "$sessionTitle"? This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); 
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); 
              },
            ),
          ],
        );
      },
    );
  }

  // Method to handle the deletion process with Undo
  void _handleDeleteSession(BuildContext context, WidgetRef ref, String sessionId, String sessionTitle) async {
    // 1. Optimistically update the UI by setting the pending delete ID
    ref.read(sessionPendingDeleteIdProvider.notifier).state = sessionId;

    // 2. Clear existing SnackBars (optional but good practice)
    ScaffoldMessenger.of(context).clearSnackBars();

    // 3. Show SnackBar with Undo action
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text(
          'Chat deleted.', 
          style: TextStyle(color: Colors.white), // Set text color to white
        ), 
        backgroundColor: AppColors.inputFillDark, 
        behavior: SnackBarBehavior.floating, 
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), // Add margin
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), // Rounded corners
        duration: const Duration(seconds: 4), 
        action: SnackBarAction(
          label: 'UNDO', // Changed label
          textColor: Theme.of(context).colorScheme.primary, // Keep primary color for visibility
          onPressed: () {
            scaffoldMessenger.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
          },
        ),
      ),
    ).closed.then((reason) async {
      // 4. Check if the SnackBar was closed because Undo was pressed or it timed out
      if (reason == SnackBarClosedReason.action) {
        // UNDO was pressed: Clear the pending delete ID, item reappears, DON'T delete from DB
        ref.read(sessionPendingDeleteIdProvider.notifier).state = null;
        // No database deletion call here
      } else {
        // SnackBar timed out or was dismissed otherwise - proceed with actual deletion
        try {
          await ref.read(chatDbServiceProvider).deleteChatSession(sessionId);
          // If the deleted session was the active one in chatProvider, clear it
          if (ref.read(chatProvider).currentSessionId == sessionId) {
            ref.read(chatProvider.notifier).startNewChatSession();
          }
          // Clear pending delete ID AFTER successful delete and BEFORE invalidating main provider
          ref.read(sessionPendingDeleteIdProvider.notifier).state = null;
          ref.invalidate(chatSessionsProvider); // Invalidate AFTER successful delete
        } catch (e) {
          // Handle potential errors during the actual deletion
          // If deletion failed, we should also clear the pending ID so the item reappears
          ref.read(sessionPendingDeleteIdProvider.notifier).state = null;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete session: ${e.toString()}'), backgroundColor: Colors.redAccent),
            );
          }
        }
      }
    });

    // Note: We don't invalidate chatSessionsProvider immediately for optimistic update.
    // The list visually updates due to sessionPendingDeleteIdProvider.
  }

  // Helper to get a comparable group key (DateTime representing the group)
  DateTime _getGroupKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(dt.year, dt.month, dt.day);

    if (dateOnly.isAtSameMomentAs(today)) {
      return today; // Group key for Today
    } else if (dateOnly.isAtSameMomentAs(yesterday)) {
      return yesterday; // Group key for Yesterday
    } else {
      // Group by the first day of the month for older items
      return DateTime(dt.year, dt.month, 1);
    }
  }

  // Helper to get the display name for a group key
  String _getGroupName(DateTime groupKey) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (groupKey.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (groupKey.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      // Format as Month Year for older items
      return DateFormat('MMMM yyyy').format(groupKey);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print("[HistoryListScreen] Build method called.");
    final sessionsAsyncValue = ref.watch(chatSessionsProvider);
    final theme = Theme.of(context); // Get theme here for shimmer
    final singlePendingDeleteId = ref.watch(sessionPendingDeleteIdProvider); // Renamed for clarity
    final batchPendingDeleteIds = ref.watch(batchSessionsPendingDeleteProvider); // Watch new provider
    print("[HistoryListScreen] Current batchPendingDeleteIds length: ${batchPendingDeleteIds.length}");
    final isMultiSelectActive = ref.watch(isHistoryMultiSelectActiveProvider); // Watch multi-select state

    return SafeArea(
      top: true, // Ensure SafeArea respects top padding requirement
      bottom: false, // Prevent SafeArea from adding bottom padding
      child: Column(
        children: [
          // Add SizedBox for top padding
          const SizedBox(height: 16.0),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0, // Align to the top during transition
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: isMultiSelectActive
                ? MultiSelectAppBar(key: const ValueKey('multiSelectAppBar'))
                : Column(
                    key: const ValueKey('searchAndFilterBar'), // Add key for AnimatedSwitcher
                    children: const [
                      SearchBarWidget(), 
                      FilterRowWidget(), 
                    ],
                  ),
          ),
          Expanded(
            // Wrap the .when() result with AnimatedSwitcher
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300), // Adjust duration as needed
              // Default transition is FadeTransition, which is usually good
              // transitionBuilder: (Widget child, Animation<double> animation) {
              //   return FadeTransition(opacity: animation, child: child);
              // },
              child: sessionsAsyncValue.when(
                // Add loading state handler
                loading: () => Center(
                  key: const ValueKey('history_loading'), 
                  child: CircularProgressIndicator()
                ),
                // Add error state handler
                error: (error, stackTrace) => Center(
                  key: const ValueKey('history_error'),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error loading history: ${error.toString()}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(chatSessionsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                // Existing data handler
                data: (filteredSessions) {
                  print("[HistoryListScreen] sessionsAsyncValue.when(data: ...): Received ${filteredSessions.length} sessions from provider.");
                  List<Map<String, dynamic>> displayedSessions = filteredSessions;
                  // Filter out single pending delete
                  if (singlePendingDeleteId != null) {
                    displayedSessions = displayedSessions.where((session) => session['id'] != singlePendingDeleteId).toList();
                  }
                  // Filter out batch pending deletes
                  if (batchPendingDeleteIds.isNotEmpty) {
                    print("[HistoryListScreen] Applying batchPendingDeleteIds filter. Count: ${batchPendingDeleteIds.length}");
                    displayedSessions = displayedSessions.where((session) => !batchPendingDeleteIds.contains(session['id'])).toList();
                  }
                  print("[HistoryListScreen] displayedSessions length after all filters: ${displayedSessions.length}");

                  if (displayedSessions.isEmpty) {
                    // Use a specific key for the empty state
                    return Center(
                      key: const ValueKey('history_empty'), 
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          "No chat sessions yet.",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  // Use a specific key for the list state
                  return GroupedListView<Map<String, dynamic>, DateTime>(
                    key: const ValueKey('history_grouped_list'), 
                    elements: displayedSessions,
                    groupBy: (session) => _getGroupKey(DateTime.parse(session['updated_at'] as String).toLocal()),
                    groupComparator: (group1, group2) => group2.compareTo(group1), // Sort groups descending (Today first)
                    itemComparator: (item1, item2) => 
                        DateTime.parse(item2['updated_at'] as String).compareTo(DateTime.parse(item1['updated_at'] as String)), // Sort items within groups descending (most recent first)
                    order: GroupedListOrder.ASC, // Groups are ordered by comparator, items by theirs
                    padding: const EdgeInsets.only(bottom: 90.0), // Padding for the bottom navbar
                    groupSeparatorBuilder: (DateTime groupKey) { // Changed from String groupName to DateTime groupKey
                      final String groupName = _getGroupName(groupKey); // Get display name from key
                      return Material( // Wrap with Material for elevation and background
                        elevation: 1.0, // Add a slight elevation for shadow
                        color: Theme.of(context).scaffoldBackgroundColor, // Match scaffold background
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          color: Colors.transparent, // Container is transparent to show Material color
                          child: Row(
                            children: <Widget>[
                              Expanded(child: Divider(color: AppColors.dividerDark, thickness: 0.8)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Text(
                                  groupName,
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: AppColors.textMediumEmphasisDark,
                                        fontWeight: FontWeight.bold, // Make text bolder
                                      ),
                                ),
                              ),
                              Expanded(child: Divider(color: AppColors.dividerDark, thickness: 0.8)),
                            ],
                          ),
                        ),
                      );
                    },
                    itemBuilder: (context, session) {
                      final sessionId = session['id'] as String; 
                      final sessionTitle = session['title'] as String? ?? 'Chat Session'; 
                      
                      return SessionTileWidget(
                        key: ValueKey(sessionId),
                        sessionData: session, 
                        dense: false,
                        onDeleteRequested: () {
                          _handleDeleteSession(context, ref, sessionId, sessionTitle);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
} 
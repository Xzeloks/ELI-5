import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eli5/providers/history_list_providers.dart';
import 'package:eli5/providers/chat_provider.dart'; // Import for chatDbServiceProvider and chatSessionsProvider
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:eli5/main.dart'; // For AppColors

class MultiSelectAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const MultiSelectAppBar({super.key});

  @override
  ConsumerState<MultiSelectAppBar> createState() => _MultiSelectAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _MultiSelectAppBarState extends ConsumerState<MultiSelectAppBar> {
  @override
  Widget build(BuildContext context) {
    final ProviderContainer container = ProviderScope.containerOf(context);
    final selectedIds = ref.watch(selectedSessionIdsProvider);
    final int selectedCount = selectedIds.length;
    final theme = Theme.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    return Material(
      elevation: 1.0, // Subtle elevation
      color: AppColors.inputFillDark, // Consistent with other top/bottom bars
      child: Container(
        height: widget.preferredSize.height,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: [
                IconButton(
                  icon: const Icon(FeatherIcons.x),
                  color: theme.iconTheme.color,
                  tooltip: 'Clear selection',
                  onPressed: () {
                    if (!mounted) return; // Check mounted
                    ref.read(selectedSessionIdsProvider.notifier).state = [];
                    ref.read(isHistoryMultiSelectActiveProvider.notifier).state = false;
                  },
                ),
                const SizedBox(width: 12),
                Text(
                  '$selectedCount selected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.textTheme.titleMedium?.color?.withOpacity(0.9)
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(FeatherIcons.star),
                  color: theme.iconTheme.color,
                  tooltip: 'Star/Unstar selected',
                  onPressed: selectedCount > 0 ? () async {
                    final currentSelectedIds = List<String>.from(container.read(selectedSessionIdsProvider));
                    if (currentSelectedIds.isEmpty) return;

                    // Get session data to determine current starred state
                    final sessionsAsyncValue = container.read(chatSessionsProvider);
                    List<Map<String, dynamic>> allSessions = [];
                    sessionsAsyncValue.whenData((value) => allSessions = value);

                    if (allSessions.isEmpty && sessionsAsyncValue is! AsyncLoading) {
                         // This might happen if chatSessionsProvider hasn't loaded or is empty.
                         // Or if there was an error loading sessions initially.
                        print("[MultiSelectAppBar] Star: Could not get session data to determine starred state.");
                        ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Could not determine current starred state. Please try again.')),
                        );
                        return;
                    }
                    if (sessionsAsyncValue is AsyncLoading) {
                        print("[MultiSelectAppBar] Star: Session data is still loading. Please wait.");
                        ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Session data is loading. Please wait and try again.')),
                        );
                        return;
                    }

                    final selectedSessionsData = allSessions.where((s) => currentSelectedIds.contains(s['id'])).toList();
                    
                    if (selectedSessionsData.length != currentSelectedIds.length && allSessions.isNotEmpty) {
                        // This case might occur if chatSessionsProvider is stale or some selected IDs are not in the current list.
                        // It's a bit of an edge case but good to be aware of.
                        print("[MultiSelectAppBar] Star: Mismatch between selected IDs and found session data.");
                        ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Error identifying selected sessions. Please try again.')),
                        );
                        return;
                    }

                    // Determine target starred state: if any selected is not starred, then star all. Else, unstar all.
                    bool newStarredState = false; // Default to unstarring
                    if (selectedSessionsData.any((s) => (s['is_starred'] as bool? ?? false) == false)) {
                        newStarredState = true; // If any are unstarred, the action is to star them.
                    }

                    try {
                      await container.read(chatDbServiceProvider).updateMultipleSessionsStarredStatus(currentSelectedIds, newStarredState);
                      
                      // Clear visual selection and exit multi-select mode
                      container.read(selectedSessionIdsProvider.notifier).state = [];
                      container.read(isHistoryMultiSelectActiveProvider.notifier).state = false;

                      // Invalidate chatSessionsProvider to refresh the list
                      container.invalidate(chatSessionsProvider);

                      scaffoldMessenger.clearSnackBars();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            '${currentSelectedIds.length} session(s) ${newStarredState ? "starred" : "unstarred"}.',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: AppColors.inputFillDark,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    } catch (e) {
                      print("[MultiSelectAppBar] Star: Error updating starred status: ${e.toString()}");
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating starred status: ${e.toString()}'), backgroundColor: Colors.redAccent),
                    );
                    }
                  } : null, // Disable if nothing selected
                ),
                // TODO: Implement actual batch delete logic
                IconButton(
                  icon: const Icon(FeatherIcons.trash2),
                  color: theme.iconTheme.color,
                  tooltip: 'Delete selected',
                  onPressed: selectedCount > 0 ? () async {
                    if (!mounted) return; // Check mounted at start of async operation
                    final currentSelectedIds = List<String>.from(ref.read(selectedSessionIdsProvider));
                    if (currentSelectedIds.isEmpty) return;

                    final bool? confirmed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: Text('Delete ${currentSelectedIds.length} Session(s)?'),
                          content: const Text('Are you sure you want to delete the selected chat session(s)? This cannot be undone initially. You will have a chance to undo.'),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete'),
                              onPressed: () => Navigator.of(dialogContext).pop(true),
                            ),
                          ],
                        );
                      },
                    );

                    if (!mounted) return; // Check mounted after await

                    if (confirmed == true) {
                      // 1. Set batch pending delete IDs (optimistic UI update)
                      ref.read(batchSessionsPendingDeleteProvider.notifier).state = currentSelectedIds;

                      // 2. Clear visual selection and exit multi-select mode
                      ref.read(selectedSessionIdsProvider.notifier).state = [];
                      ref.read(isHistoryMultiSelectActiveProvider.notifier).state = false;
                      
                      // 3. Show SnackBar with Undo
                      scaffoldMessenger.clearSnackBars(); // Clear any existing snackbars
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            '${currentSelectedIds.length} session(s) deleted.',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: AppColors.inputFillDark,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          duration: const Duration(seconds: 4), // Same as single delete undo
                          action: SnackBarAction(
                            label: 'UNDO',
                            textColor: theme.colorScheme.primary,
                            onPressed: () {
                              print("[MultiSelectAppBar] UNDO action pressed.");

                              final List<String> currentPendingIds = container.read(batchSessionsPendingDeleteProvider);
                              print("[MultiSelectAppBar] UNDO: Current batchSessionsPendingDeleteProvider length: ${currentPendingIds.length}");
                              
                              container.read(batchSessionsPendingDeleteProvider.notifier).state = [];
                              final List<String> newPendingIds = container.read(batchSessionsPendingDeleteProvider);
                              print("[MultiSelectAppBar] UNDO: batchSessionsPendingDeleteProvider cleared. New length: ${newPendingIds.length}");
                              
                              print("[MultiSelectAppBar] UNDO: Invalidating chatSessionsProvider...");
                              container.invalidate(chatSessionsProvider);
                              print("[MultiSelectAppBar] UNDO: chatSessionsProvider invalidated.");
                              
                              scaffoldMessenger.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
                            },
                          ),
                        ),
                      ).closed.then((reason) async {
                        if (!mounted) return; // Check mounted before async logic in .then()

                        if (reason != SnackBarClosedReason.action) {
                          // IMPORTANT: Read the current state of batchSessionsPendingDeleteProvider NOW.
                          // These are the IDs to actually delete if UNDO was not pressed.
                          final List<String> actualIdsToDeleteNow = ref.read(batchSessionsPendingDeleteProvider);

                          if (actualIdsToDeleteNow.isNotEmpty) { 
                             try {
                                await ref.read(chatDbServiceProvider).deleteChatSessions(actualIdsToDeleteNow);
                                if (!mounted) return; // Check after await
                                ref.invalidate(chatSessionsProvider); 
                             } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error deleting sessions: ${e.toString()}'), backgroundColor: Colors.redAccent),
                                );
                                // On error, items remain in batchSessionsPendingDeleteProvider, visually hidden.
                                // Consider clearing them here to make them reappear if that's desired UX on failure.
                             } finally {
                                // After deletion attempt (success or fail), if it wasn't undone (i.e., we are in this block),
                                // clear these specific IDs from the pending list.
                                if (!mounted) return;
                                ref.read(batchSessionsPendingDeleteProvider.notifier).update((currentPendingIds) {
                                  // Filter out the IDs that were processed in this deletion attempt.
                                  return currentPendingIds.where((id) => !actualIdsToDeleteNow.contains(id)).toList();
                                });
                             }
                          }
                        }
                        // If reason WAS SnackBarClosedReason.action, UNDO was pressed.
                        // The onPressed of UNDO already cleared batchSessionsPendingDeleteProvider. So nothing more to do here.
                      });
                    }
                  } : null, // Disable if nothing selected
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 
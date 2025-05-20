import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eli5/providers/history_list_providers.dart';
import 'package:eli5/providers/chat_provider.dart'; // Import for chatDbServiceProvider and chatSessionsProvider
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:eli5/main.dart'; // For AppColors
import 'package:eli5/utils/snackbar_helper.dart'; // ADDED

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
                        showStyledSnackBar(context, message: 'Could not determine current starred state. Please try again.');
                        return;
                    }
                    if (sessionsAsyncValue is AsyncLoading) {
                        print("[MultiSelectAppBar] Star: Session data is still loading. Please wait.");
                        showStyledSnackBar(context, message: 'Session data is loading. Please wait and try again.');
                        return;
                    }

                    final selectedSessionsData = allSessions.where((s) => currentSelectedIds.contains(s['id'])).toList();
                    
                    if (selectedSessionsData.length != currentSelectedIds.length && allSessions.isNotEmpty) {
                        // This case might occur if chatSessionsProvider is stale or some selected IDs are not in the current list.
                        // It's a bit of an edge case but good to be aware of.
                        print("[MultiSelectAppBar] Star: Mismatch between selected IDs and found session data.");
                        showStyledSnackBar(context, message: 'Error identifying selected sessions. Please try again.');
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
                      showStyledSnackBar(context, message: '${currentSelectedIds.length} session(s) ${newStarredState ? "starred" : "unstarred"}.');
                    } catch (e) {
                      print("[MultiSelectAppBar] Star: Error updating starred status: ${e.toString()}");
                    showStyledSnackBar(context, message: 'Error updating starred status: ${e.toString()}', isError: true);
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
                      showStyledSnackBar(
                        context,
                        message: '${currentSelectedIds.length} session(s) deleted.',
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(
                          label: 'UNDO',
                          textColor: AppColors.kopyaPurple, // Using AppColor for consistency
                          onPressed: () {
                            print("[MultiSelectAppBar] UNDO action pressed.");
                            container.read(batchSessionsPendingDeleteProvider.notifier).state = [];
                            container.invalidate(chatSessionsProvider);
                          },
                        ),
                      ).then((reason) async { // NOW we can use .then() on the returned Future
                        if (!mounted) return; 

                        if (reason != SnackBarClosedReason.action) {
                          final List<String> actualIdsToDeleteNow = ref.read(batchSessionsPendingDeleteProvider);
                          if (actualIdsToDeleteNow.isNotEmpty) { 
                             try {
                                await ref.read(chatDbServiceProvider).deleteChatSessions(actualIdsToDeleteNow);
                                if (!mounted) return; 
                                ref.invalidate(chatSessionsProvider); 
                             } catch (e) {
                                if (!mounted) return;
                                showStyledSnackBar(context, message: 'Error deleting sessions: ${e.toString()}', isError: true);
                             } finally {
                                if (!mounted) return;
                                ref.read(batchSessionsPendingDeleteProvider.notifier).update((currentPendingIds) {
                                  return currentPendingIds.where((id) => !actualIdsToDeleteNow.contains(id)).toList();
                                });
                             }
                          }
                        }
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
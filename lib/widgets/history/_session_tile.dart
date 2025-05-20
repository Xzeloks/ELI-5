// Placeholder for _SessionTile widget
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:eli5/providers/chat_provider.dart';
import 'package:eli5/providers/history_list_providers.dart'; // For potential future use (e.g. starred status)
import 'package:eli5/screens/chat_screen.dart'; // Import ChatScreen for direct navigation
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:eli5/services/chat_db_service.dart'; // Import ChatDbService
import 'package:eli5/main.dart'; // Corrected Import for AppColors
import 'package:eli5/utils/snackbar_helper.dart'; // ADDED

class SessionTileWidget extends ConsumerWidget {
  final Map<String, dynamic> sessionData;
  final bool dense;
  final VoidCallback onDeleteRequested;

  const SessionTileWidget({
    super.key, 
    required this.sessionData, 
    this.dense = false,
    required this.onDeleteRequested,
  });

  // Helper to determine leading icon based on session title
  IconData _getLeadingIconData(String title, bool isActive) {
    if (isActive) return FeatherIcons.checkCircle;
    title = title.toLowerCase();
    if (title.startsWith('scanned:') || title.startsWith('image:')) return FeatherIcons.image;
    if (title.startsWith('url:') || title.startsWith('link:')) return FeatherIcons.link;
    return FeatherIcons.fileText;
  }

  // Function to show the rename dialog
  Future<String?> _showRenameDialog(BuildContext context, String currentTitle) {
    final TextEditingController controller = TextEditingController(text: currentTitle);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Session'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter new session title',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title cannot be empty';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(null), // Return null on cancel
            ),
            TextButton(
              child: const Text('Rename'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(controller.text.trim()); // Return new title
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentChatSessionId = ref.watch(chatProvider.select((state) => state.currentSessionId));

    // Multi-select states
    final isMultiSelectActive = ref.watch(isHistoryMultiSelectActiveProvider);
    final selectedIds = ref.watch(selectedSessionIdsProvider);

    final sessionId = sessionData['id'] as String;
    final sessionTitle = sessionData['title'] as String? ?? 'Chat Session';
    final updatedAt = sessionData['updated_at'] != null
        ? DateTime.parse(sessionData['updated_at'] as String).toLocal()
        : DateTime.now().toLocal();
    final bool isActiveChatSession = currentChatSessionId == sessionId; // Is this the session currently open in ChatScreen?
    final bool isStarred = sessionData['is_starred'] as bool? ?? false;

    final bool isThisTileSelected = selectedIds.contains(sessionId);

    IconData leadingIconData;
    Color leadingIconFgColor;
    Color leadingIconBgColor;

    if (isMultiSelectActive && isThisTileSelected) {
      leadingIconData = FeatherIcons.checkCircle;
      leadingIconFgColor = theme.colorScheme.primary;
      leadingIconBgColor = theme.colorScheme.primary.withOpacity(0.12);
    } else {
      leadingIconData = _getLeadingIconData(sessionTitle, isActiveChatSession);
      leadingIconFgColor = isActiveChatSession ? theme.colorScheme.primary : theme.iconTheme.color ?? theme.colorScheme.onSurfaceVariant;
      leadingIconBgColor = leadingIconFgColor.withOpacity(0.12);
    }

    String formattedDate = DateFormat('MMM d · hh:mm a').format(updatedAt);
    String subtitleText = formattedDate;

    Color cardBackgroundColor = isThisTileSelected && isMultiSelectActive
        ? theme.colorScheme.primary.withOpacity(0.15) // Highlight color for selected items
        : AppColors.inputFillDark;

    final List<BoxShadow> tileBoxShadow = [
      BoxShadow(
        color: AppColors.kopyaPurple.withOpacity(0.20),
        blurRadius: 6.0,
        spreadRadius: 0.0,
        offset: const Offset(0, 3),
      ),
    ];

    Widget tileContent = ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 6 : 10),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: leadingIconBgColor,
        child: Icon(leadingIconData, color: leadingIconFgColor, size: 20),
      ),
      title: Text(
        sessionTitle,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isActiveChatSession && !isMultiSelectActive // Only apply primary color if it's the active chat AND not in multi-select
              ? theme.colorScheme.primary 
              : theme.textTheme.titleMedium?.color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitleText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textMediumEmphasisDark,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isMultiSelectActive 
          ? null // No trailing icon in multi-select mode
          : IconButton( // ADDED: Star IconButton
              icon: Icon(
                isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                color: isStarred ? Colors.amber[700] : theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: isStarred ? 'Unstar session' : 'Star session',
              padding: EdgeInsets.zero, // Reduce padding for a tighter fit if needed
              constraints: const BoxConstraints(), // Reduce constraints for a tighter fit if needed
              onPressed: () async {
                final currentlyStarred = isStarred; // Capture current state before async call
                try {
                  await ref.read(chatDbServiceProvider).updateStarredStatus(sessionId, !currentlyStarred);
                  ref.invalidate(chatSessionsProvider);
                } catch (e) {
                  if (context.mounted) {
                    showStyledSnackBar(context, message: 'Error updating star status: ${e.toString()}', isError: true);
                  }
                }
              },
            ),
      onTap: () {
        if (isMultiSelectActive) {
          final currentSelectedIds = List<String>.from(selectedIds);
          if (isThisTileSelected) {
            currentSelectedIds.remove(sessionId);
          } else {
            currentSelectedIds.add(sessionId);
          }
          ref.read(selectedSessionIdsProvider.notifier).state = currentSelectedIds;

          if (currentSelectedIds.isEmpty) {
            ref.read(isHistoryMultiSelectActiveProvider.notifier).state = false;
          }
        } else {
          // New tap action: navigate to a new ChatScreen instance
          // The ChatScreen will call loadSession internally if sessionId is provided.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(sessionId: sessionId),
            ),
          );
        }
      },
      onLongPress: isMultiSelectActive ? null : () { // Only allow long press if not already in multi-select mode to initiate
        ref.read(isHistoryMultiSelectActiveProvider.notifier).state = true;
        final currentSelectedIds = List<String>.from(selectedIds);
        if (!currentSelectedIds.contains(sessionId)) { // Select if not already (e.g. if mode was activated by another tile)
          currentSelectedIds.add(sessionId);
          ref.read(selectedSessionIdsProvider.notifier).state = currentSelectedIds;
        }
      },
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 4 : 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: tileBoxShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedContainer( 
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16), // Keep borderRadius for the border
              border: isActiveChatSession && !isMultiSelectActive && !isThisTileSelected 
                  ? Border.all(color: theme.colorScheme.primary.withOpacity(0.5), width: 1.5)
                  : null,
            ),
            child: isMultiSelectActive
                ? tileContent 
                : Slidable(
                    key: ValueKey(sessionId), 
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      extentRatio: dense ? 0.70 : 0.75, 
                      children: [
                        SlidableAction(
                          onPressed: (context) async {
                            final newTitle = await _showRenameDialog(context, sessionTitle);
                            if (newTitle != null && newTitle != sessionTitle) {
                              try {
                                await ref.read(chatDbServiceProvider).renameChatSession(sessionId, newTitle);
                                ref.invalidate(chatSessionsProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  showStyledSnackBar(context, message: 'Error renaming session: ${e.toString()}', isError: true);
                                }
                              }
                            }
                          },
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          icon: FeatherIcons.edit2,
                          label: 'Rename',
                          borderRadius: BorderRadius.circular(16),
                          padding: EdgeInsets.zero,
                        ),
                        SlidableAction(
                          onPressed: (context) async {
                            final bool currentlyStarred = isStarred;
                            try {
                              await ref.read(chatDbServiceProvider).updateStarredStatus(sessionId, !currentlyStarred);
                              ref.invalidate(chatSessionsProvider);
                            } catch (e) {
                              if (context.mounted) {
                                showStyledSnackBar(context, message: 'Error updating star status: ${e.toString()}', isError: true);
                              }
                            }
                          },
                          backgroundColor: Colors.orangeAccent, // Keep this color
                          foregroundColor: Colors.white,
                          icon: isStarred ? Icons.star_rounded : Icons.star_border_rounded, // Reverted to correct icons
                          label: isStarred ? 'Unstar' : 'Star',
                          borderRadius: BorderRadius.circular(16),
                          padding: EdgeInsets.zero,
                        ),
                        SlidableAction(
                          onPressed: (context) => onDeleteRequested(), 
                          backgroundColor: Colors.red[700]!,
                          foregroundColor: Colors.white,
                          icon: FeatherIcons.trash2,
                          label: 'Delete',
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                        ),
                      ],
                    ),
                    child: tileContent, 
                  ),
        ),
      ),
    );
  }
} 
import 'package:eli5/providers/chat_provider.dart';
import 'package:eli5/widgets/chat_message_bubble.dart';
import 'package:eli5/models/chat_message.dart'; // Import ChatMessage and ChatMessageSender
import 'package:eli5/models/simplification_style.dart'; // ADDED import
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; // Added image_picker import
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Import for OCR
import 'package:intl/intl.dart'; // Import the intl package for date formatting
import 'package:flutter_spinkit/flutter_spinkit.dart'; // Import SpinKit
import 'package:eli5/main.dart'; // For AppColors
import 'package:flutter_feather_icons/flutter_feather_icons.dart'; // Import Feather Icons
import 'package:eli5/screens/app_shell.dart'; // For appShellSelectedIndexProvider
import 'package:supabase_flutter/supabase_flutter.dart'; // Added missing Supabase import
import 'dart:ui'; // Import for ImageFilter
import 'package:eli5/widgets/history/_session_tile.dart'; // ADDED import for SessionTileWidget
import 'package:eli5/providers/history_list_providers.dart'; // ADDED for sessionPendingDeleteIdProvider
import 'package:eli5/services/chat_db_service.dart'; // Ensure ChatDbService is imported
import 'package:eli5/utils/snackbar_helper.dart'; // ADDED
// import 'dart:math'; // For min function - already in chat_provider if needed there, or ensure it's imported if used directly here

// Helper to identify the special "processing image" message
const String _processingImagePlaceholder = 'Processing image for simplification...';

// Convert to ConsumerStatefulWidget
class ChatScreen extends ConsumerStatefulWidget {
  final String? sessionId; // Added sessionId parameter

  const ChatScreen({super.key, this.sessionId}); // Updated constructor

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

// Create State class
class _ChatScreenState extends ConsumerState<ChatScreen> {
  
  // Define Controller
  late TextEditingController _messageController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();

    // If a specific session ID is provided to this screen instance, load it.
    if (widget.sessionId != null) {
      // Ensure that the widget is mounted and providers are available.
      // Using addPostFrameCallback to ensure build is complete and ref is safe to read.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Check if the widget is still in the tree
          print("[ChatScreen] initState: Loading session with ID: ${widget.sessionId}");
          ref.read(chatProvider.notifier).loadSession(widget.sessionId!);
        }
      });
    } else {
      // This is the "main" ChatScreen instance (e.g., for new chats from nav bar)
      // Ensure it reflects the current state of chatProvider (new or existing via provider's currentSessionId)
      // If chatProvider's currentSessionId is null, it implies a new chat.
      // If it's not null, it implies a session was already loaded into the provider,
      // perhaps by a previous action or if it's the default screen.
      // No explicit action needed here as the screen will build based on chatProvider's state.
      print("[ChatScreen] initState: No specific sessionId provided. Will reflect chatProvider state.");
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Method to show style explanations dialog
  Future<void> _showStyleExplanationsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Simplification Styles'),
          content: SingleChildScrollView(
            child: ListBody(
              children: SimplificationStyle.values.map((style) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        displayStringForSimplificationStyle(style),
                        style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4.0),
                      Text(explanationForSimplificationStyle(style)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Got it!'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Helper method to build the style selector
  Widget _buildStyleSelector(BuildContext context, WidgetRef ref) {
    final selectedStyle = ref.watch(chatProvider.select((cs) => cs.selectedStyle));
    final chatNotifier = ref.read(chatProvider.notifier);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space
        children: [
          // This Row contains the ChoiceChips
          Row(
            mainAxisSize: MainAxisSize.min, // Crucial for keeping chips compact
            children: SimplificationStyle.values.map((style) {
              final bool isSelected = selectedStyle == style;
              return Padding(
                // Add spacing to the right of each chip, except the last one
                padding: EdgeInsets.only(right: style != SimplificationStyle.values.last ? 4.0 : 0.0),
                child: ChoiceChip(
                  label: Text(displayStringForSimplificationStyle(style)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      chatNotifier.setSelectedStyle(style);
                    }
                  },
                  backgroundColor: isSelected ? theme.colorScheme.primary.withOpacity(0.15) : theme.chipTheme.backgroundColor,
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? theme.colorScheme.onPrimary : theme.chipTheme.labelStyle?.color,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withOpacity(0.5),
                      width: 1.0,
                    ),
                  ),
                  elevation: isSelected ? 2.0 : 0.0,
                  pressElevation: 4.0,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: Icon(FeatherIcons.info, color: theme.iconTheme.color?.withOpacity(0.7)),
            tooltip: 'About simplification styles',
            padding: EdgeInsets.zero, // Minimal padding for the icon button
            constraints: const BoxConstraints(),
            onPressed: () {
              _showStyleExplanationsDialog(context);
            },
          ),
        ],
      ),
    );
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCompare = DateTime(date.year, date.month, date.day);

    if (dateToCompare == today) {
      return 'Today';
    } else if (dateToCompare == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Widget _buildChatMessageItem(BuildContext context, ChatMessage message) {
    final String displayText = message.displayOverride ?? message.text;

    // Check if this is the special processing message
    if (displayText == _processingImagePlaceholder && message.sender == ChatMessageSender.user) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitRing( // Or another SpinKit indicator
              color: Theme.of(context).colorScheme.primary,
              size: 16.0,
              lineWidth: 1.5,
            ),
            const SizedBox(width: 10),
            Text(
              _processingImagePlaceholder,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
              ),
            ),
          ],
        ),
      );
    }

    // Normal chat message bubble
    return ChatMessageBubble(message: message);
  }

  Widget _buildDateSeparator(BuildContext context, String dateText) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: theme.dividerColor.withOpacity(0.5), thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              dateText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: theme.dividerColor.withOpacity(0.5), thickness: 0.5)),
        ],
      ),
    );
  }

  Widget _buildChatInputBar(
    BuildContext context,
    WidgetRef ref,
    TextEditingController controller,
    bool isAiResponding,
    bool isProcessingImage,
    VoidCallback onSendPressed,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0), // Standard padding
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0), // Padding for internal elements like the camera icon
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor ?? AppColors.inputFillDark, // CHANGED: Use opaque color
          borderRadius: BorderRadius.circular(32.0),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 3,
              color: Colors.black.withAlpha((255 * 0.08).round()),
            ),
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.5),
              blurRadius: 12.0,  // CHANGED: Doubled blurRadius
              spreadRadius: 0.0,
              offset: Offset.zero,
            )
          ],
        ),
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero, // ADDED: Remove default padding
              icon: Icon(
                FeatherIcons.camera,
                color: theme.iconTheme.color != null 
                       ? theme.iconTheme.color!.withAlpha((255 * 0.8).round()) 
                       : AppColors.textMediumEmphasisDark.withAlpha((255 * 0.8).round()),
              ),
              tooltip: 'Pick image for OCR',
              onPressed: isAiResponding || isProcessingImage
                  ? null
                  : () async {
                      _pickAndProcessImage(context, ref);
                    },
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isAiResponding && !isProcessingImage,
                decoration: InputDecoration(
                  hintText: "Ask ELI5 anything! Type, paste a URL, or use an image for AI-powered simplification.", // CHANGED: Emphasize AI
                  filled: true, // Ensure filled is true for background color to take effect if not globally set
                  fillColor: Colors.transparent, // Make TextField's own fill transparent
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                ),
                onSubmitted: isAiResponding || isProcessingImage ? null : (_) => onSendPressed(),
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
              ),
            ),
            Material(
                color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(24.0), // CHANGED: Adjusted for a more circular button feel within the bar
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: isAiResponding || isProcessingImage ? null : onSendPressed,
                  splashColor: theme.colorScheme.onPrimary.withAlpha((255 * 0.2).round()),
                  highlightColor: theme.colorScheme.onPrimary.withAlpha((255 * 0.1).round()),
                  child: Padding(
                  padding: const EdgeInsets.all(10.0), // Kept inner padding for tap area and icon spacing
                    child: Icon(
                      FeatherIcons.arrowUp,
                      color: theme.colorScheme.onPrimary,
                      size: 22.0, 
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingIndicators(BuildContext context, bool isAiResponding, bool isProcessingImage) {
    if (isProcessingImage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitRing(
              color: Theme.of(context).colorScheme.primary,
              size: 20.0,
              lineWidth: 2.0,
            ),
            const SizedBox(width: 8),
            const Text("Scanning image..."),
          ],
        ),
      );
    }
    if (isAiResponding && !isProcessingImage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitThreeBounce(
              color: Theme.of(context).colorScheme.primary,
              size: 20.0,
            ),
            const SizedBox(width: 8),
            const Text("ELI5 Bot is thinking..."),
          ],
        ),
        );
      }
    return const SizedBox.shrink();
  }

  // --- New Helper for Empty State Greeting ---
  Widget _buildGreeting(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    // Attempt to get display name from user_metadata, fallback to email
    final String displayName = user?.userMetadata?['display_name'] ?? user?.email ?? 'User';
    // Simple name extraction (fallback if no display_name)
    final String firstName = displayName.contains('@') ? displayName.split('@')[0] : displayName.split(' ')[0];
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0), // Spacing below greeting
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.headlineMedium, // Base style
          children: <TextSpan>[
            TextSpan(
              text: 'Hello, ',
              style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
            ),
            TextSpan(
              text: firstName,
              style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold, 
                    color: theme.colorScheme.primary
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Extracted Image Picker Logic ---
  Future<void> _pickAndProcessImage(BuildContext context, WidgetRef ref) async {
     final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
              child: Wrap(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(FeatherIcons.image),
                    title: const Text('Gallery'),
                    onTap: () { Navigator.pop(context, ImageSource.gallery); },
                  ),
                  ListTile(
                    leading: const Icon(FeatherIcons.camera),
                    title: const Text('Camera'),
                    onTap: () { Navigator.pop(context, ImageSource.camera); },
                  ),
                ],
              ),
            );
        },
      );

      if (source == null) {
        if (!context.mounted) return;
        return;
      }

      final ImagePicker picker = ImagePicker();
      ref.read(chatProvider.notifier).setProcessingImageState(true);
      try {
        final XFile? image = await picker.pickImage(source: source);
        if (!context.mounted) {
          ref.read(chatProvider.notifier).setProcessingImageState(false);
          return;
        }

        if (image != null) {
          final inputImage = InputImage.fromFilePath(image.path);
          final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
          final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
          await textRecognizer.close();
          final String extractedText = recognizedText.text;

          ref.read(chatProvider.notifier).setProcessingImageState(false);

          if (!context.mounted) { return; } 

          if (extractedText.isNotEmpty) {
            ref.read(chatProvider.notifier).addDisplayMessage(_processingImagePlaceholder, ChatMessageSender.user);
            ref.read(chatProvider.notifier).sendMessageAndGetResponse(extractedText, isFromOcr: true);
          } else {
            if(context.mounted) { showStyledSnackBar(context, message: 'No text found in image.'); }
          }
        } else {
          ref.read(chatProvider.notifier).setProcessingImageState(false);
          if (!context.mounted) { return; }
          if(context.mounted) { showStyledSnackBar(context, message: 'No image selected.'); }
        }
      } catch (e) {
        ref.read(chatProvider.notifier).setProcessingImageState(false);
        if (!context.mounted) { return; }
        if(context.mounted) { showStyledSnackBar(context, message: 'Error processing image: $e', isError: true); }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access ref via the state class
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final isAiResponding = ref.watch(chatProvider.select((cs) => cs.isAiResponding));
    final isProcessingImage = ref.watch(chatProvider.select((cs) => cs.isProcessingImage));
    final allSessionsAsyncValue = ref.watch(chatSessionsProvider);

    // Use the state's controller
    final messageController = _messageController; 

    void sendMessage() {
      if (messageController.text.isNotEmpty) {
        ref.read(chatProvider.notifier).sendMessageAndGetResponse(messageController.text);
        messageController.clear();
      }
    }

    // Pass the state's controller to the input bar builder
    final chatInputBarWidget = _buildChatInputBar(context, ref, messageController, isAiResponding, isProcessingImage, sendMessage);
    final processingIndicatorsWidget = _buildProcessingIndicators(context, isAiResponding, isProcessingImage);
    final styleSelectorWidget = _buildStyleSelector(context, ref); // ADDED: Create the style selector widget

    // Scroll to bottom when messages change and we are not already at the bottom
    // (or close to it) to avoid jumping while user is scrolling up.
    // Consider using a more robust way if issues arise.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    final pageContent = Column(
      children: [
        // Add SizedBox for top padding
        // If this is a pushed screen, AppBar provides padding. Otherwise, manual padding.
        if (widget.sessionId == null) const SizedBox(height: 16.0),
        if (messages.isEmpty && !isAiResponding && !isProcessingImage && widget.sessionId == null) ...[ // Show greeting only for main new chat screen
           Expanded(
             child: Column( 
               children: [
                 Expanded(
                   child: ListView( 
                    padding: const EdgeInsets.all(16.0),
                     children: [
                       _buildGreeting(context, ref),
                       Text("Ready to simplify something complex?", style: Theme.of(context).textTheme.bodyLarge?.copyWith( color: Theme.of(context).colorScheme.onSurfaceVariant, ) ),
                       const SizedBox(height: 16),
                       styleSelectorWidget,
                       chatInputBarWidget,
                       const SizedBox(height: 24),
                       Text("Recent Chats", style: Theme.of(context).textTheme.titleMedium?.copyWith( color: Theme.of(context).colorScheme.onBackground.withAlpha((255 * 0.85).round()), fontWeight: FontWeight.w600,), textAlign: TextAlign.center, ),
                       const SizedBox(height: 8),
                       _buildRecentChatsList(context, allSessionsAsyncValue, ref),
                     ],
                   ),
          ),
        ],
      ),
                   ),
                ] else ...[
                   Expanded( child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                       final currentMessage = messages[messages.length - 1 - index];
                       Widget messageWidget = _buildChatMessageItem(context, currentMessage);
                       bool showDateSeparator = false;
                       if (index == messages.length - 1) {
                         showDateSeparator = true;
                       } else {
                         final previousMessageInTime = messages[messages.length - 1 - (index + 1)];
                         if (!_isSameDay(previousMessageInTime.timestamp, currentMessage.timestamp)) {
                            showDateSeparator = true;
                         }
                       }
                       if (showDateSeparator) {
                         // Display message first, then separator above it (due to reverse list)
                         return Column(
                           mainAxisSize: MainAxisSize.min,
                children: [
                             messageWidget,
                             _buildDateSeparator(context, _formatDateSeparator(currentMessage.timestamp)),
                           ],
                         );
                       } else {
                         return messageWidget;
                       }
                     },
                   ) ),
                   processingIndicatorsWidget, 
                   styleSelectorWidget, // ADDED: Style selector when messages are present
                   chatInputBarWidget, 
                ],
                // Add SizedBox for bottom padding to avoid overlap with CurvedNavigationBar
                // This padding is only needed if there's no Scaffold providing it (i.e. not a pushed route)
                if (widget.sessionId == null) const SizedBox(height: 75.0), // 65 for navbar + 10 for spacing
              ],
            );

    // If sessionId is provided, this screen was pushed, so wrap with a Scaffold and AppBar
    if (widget.sessionId != null) {
      // Try to get a title for the AppBar
      String appBarTitle = "Chat"; // Default title
      // We can't easily get the session title here without another async call or passing it.
      // For now, a generic title is fine. Or, we could watch the chatProvider's messages
      // and try to derive a title if messages are loaded and widget.sessionId matches currentSessionId.
      // A simpler approach is to pass the title if available when navigating.
      // For now, keeping it simple.

      return Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          // backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Match theme
          elevation: 1.0, // Subtle elevation
        ),
        body: SafeArea( // Ensure content within pushed screen respects safe areas
          child: Material(
             type: MaterialType.transparency, // Or specific color if needed
             child: pageContent,
          )
        ),
      );
    }

    // Otherwise, this is one of the main PageView screens, return content directly
    // It's already wrapped in SafeArea and Material in AppShell or its direct build method.
    // The outer SafeArea in the original code was `bottom: false`.
    // The new SafeArea above is for the pushed route.
    // The existing `Material` and `Stack` are part of `pageContent` now, so just return `pageContent`.
    // However, the original structure had `SafeArea(bottom: false, child: Material(...child: Stack(...child: Column...)))`
    // Let's replicate that for the non-pushed case.
    return SafeArea(
      bottom: false,
      child: Material(
        type: MaterialType.transparency,
        child: Stack( // Assuming Stack was intentional for potential future overlays
          children: [pageContent],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // --- Modify _buildRecentChatsList --- 
  Widget _buildRecentChatsList(BuildContext context, AsyncValue<List<Map<String, dynamic>>> sessionsAsyncValue, WidgetRef ref) {
    final theme = Theme.of(context);
    final pendingDeleteId = ref.watch(sessionPendingDeleteIdProvider); // Watch the provider

    return sessionsAsyncValue.when(
      data: (allSessions) {
        // Filter out the session pending delete
        final sessionsToDisplay = allSessions
            .where((session) => session['id'] != pendingDeleteId)
            .toList();

        if (sessionsToDisplay.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Center(child: Text("No recent chats yet.")), // Simple text if no sessions
          );
        }
        final recentSessions = sessionsToDisplay.take(3).toList();
        
        // Use SessionTileWidget with Dividers
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentSessions.length,
          itemBuilder: (context, index) {
            final session = recentSessions[index];
            final sessionId = session['id'] as String;
            final sessionTitle = session['title'] as String? ?? 'Chat Session';
            // Note: isActiveSession and other specific display logic is handled within SessionTileWidget

            return SessionTileWidget(
              key: ValueKey('recent_$sessionId'), // Ensure unique key for recent items
              sessionData: session,
              dense: true, // Make tiles more compact for this preview list
              onDeleteRequested: () { 
                // Call the correct delete handler
                _handleSimpleDeleteRecentSession(context, ref, sessionId, sessionTitle);
              },
              // onTap (navigation) is handled internally by SessionTileWidget based on multi-select state
              // but we need to ensure it navigates correctly to ChatScreen, which was already fixed in SessionTileWidget.
              );
          },
           separatorBuilder: (context, index) { // CHANGED to SizedBox for spacing
            return const SizedBox(height: 16.0); // INCREASED height from 12.0 to 16.0
           },
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())), // Keep simple loader
      error: (err, stack) => Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error loading recent chats: ${err.toString()}"))),
    );
  }

  // RE-INSERTING _handleSimpleDeleteRecentSession with UNDO logic
  // --- Handler for simple delete (for recent chats list) with UNDO ---
  void _handleSimpleDeleteRecentSession(BuildContext context, WidgetRef ref, String sessionId, String sessionTitle) async {
    // 1. Optimistically update the UI by setting the pending delete ID
    ref.read(sessionPendingDeleteIdProvider.notifier).state = sessionId;

    // 2. Clear existing SnackBars - showStyledSnackBar handles this.
    // ScaffoldMessenger.of(context).clearSnackBars(); 

    // 3. Show SnackBar with Undo action
    // final scaffoldMessenger = ScaffoldMessenger.of(context); // Not needed if using helper
    // scaffoldMessenger.showSnackBar(
    //   SnackBar(
    //     content: const Text(
    //       'Chat deleted.', 
    //       style: TextStyle(color: Colors.white), // Consistent style
    //     ), 
    //     backgroundColor: AppColors.inputFillDark, // Consistent style
    //     behavior: SnackBarBehavior.floating, 
    //     margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
    //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
    //     duration: const Duration(seconds: 4), 
    //     action: SnackBarAction(
    //       label: 'UNDO',
    //       textColor: Theme.of(context).colorScheme.primary,
    //       onPressed: () {
    //         // HideCurrentSnackBar is called by the framework when action is pressed.
    //         // We just need to ensure the state is reverted.
    //       },
    //     ),
    //   ),
    // ).closed.then((reason) async {
    showStyledSnackBar(
      context,
      message: 'Chat deleted.',
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'UNDO',
        textColor: AppColors.kopyaPurple, // Use AppColor for consistency
        onPressed: () {
          // Action for UNDO: Clear pending delete ID
          ref.read(sessionPendingDeleteIdProvider.notifier).state = null;
          // SnackBar is hidden automatically by SnackBarAction
        },
      ),
    ).then((reason) async {
      if (!context.mounted) return; // Check mounted before proceeding

      // 4. Check if the SnackBar was closed because Undo was pressed or it timed out
      if (reason == SnackBarClosedReason.action) {
        // UNDO was pressed: Clear the pending delete ID, item reappears
        // The action's onPressed already did this.
        // ref.read(sessionPendingDeleteIdProvider.notifier).state = null;
      } else {
        // SnackBar timed out or was dismissed otherwise - proceed with actual deletion
        try {
          await ref.read(chatDbServiceProvider).deleteChatSession(sessionId);
          if (ref.read(chatProvider).currentSessionId == sessionId) {
            ref.read(chatProvider.notifier).startNewChatSession();
          }
          ref.read(sessionPendingDeleteIdProvider.notifier).state = null; // Clear after DB op
          ref.invalidate(chatSessionsProvider); // Refresh lists after actual delete
        } catch (e) {
          ref.read(sessionPendingDeleteIdProvider.notifier).state = null; // Revert UI on error
          if (context.mounted) {
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(content: Text('Failed to delete session: $e'), backgroundColor: Colors.redAccent),
            // );
            showStyledSnackBar(context, message: 'Failed to delete session: $e', isError: true);
          }
        }
      }
    });
  }
} 
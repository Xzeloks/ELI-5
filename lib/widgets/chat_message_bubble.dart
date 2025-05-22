import 'package:eli5/models/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:share_plus/share_plus.dart'; // Added for Share functionality
import 'package:eli5/widgets/modern_chat_bubble.dart'; // Import the new bubble
import 'package:eli5/main.dart'; // Import AppColors
import 'package:eli5/utils/snackbar_helper.dart'; // Added for styled SnackBar
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added for Riverpod
import 'package:eli5/services/openai_tts_service.dart'; // Added for OpenAiTtsService
import 'package:eli5/providers/chat_provider.dart'; // Added for chatProvider
import 'package:flutter_markdown/flutter_markdown.dart'; // ADDED for Markdown in chips

class ChatMessageBubble extends ConsumerWidget { // Changed to ConsumerWidget
  final ChatMessage message;
  final Function(String messageId)? onThumbUp;
  final Function(String messageId)? onThumbDown;
  final Function(String messageId)? onReport;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onThumbUp,
    this.onThumbDown,
    this.onReport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Added WidgetRef ref
    final bool isUserMessage = message.sender == ChatMessageSender.user;
    final String displayText = message.displayOverride ?? message.text;
    final String timeString = DateFormat('hh:mm a').format(message.timestamp.toLocal());

    final senderColor = AppColors.kopyaPurple;
    final receiverColor = AppColors.inputFillDark;
    final senderTextColor = AppColors.textOnPrimaryDark;
    final receiverTextColor = AppColors.textHighEmphasisDark;
    final theme = Theme.of(context);

    Widget modernChatBubble = ModernChatBubble(
      message: displayText,
      isSender: isUserMessage,
      time: timeString,
      senderColor: senderColor,
      receiverColor: receiverColor,
      textColor: isUserMessage ? senderTextColor : receiverTextColor,
      timeColor: isUserMessage ? senderTextColor.withOpacity(0.7) : receiverTextColor.withOpacity(0.7),
      isAIMessage: !isUserMessage,
    );

    if (isUserMessage) {
      return modernChatBubble;
    }

    // For AI messages, print relatedConcepts before building the column
    if (!isUserMessage) {
      print("[ChatMessageBubble] AI Message ID: ${message.id}, Related Concepts: ${message.relatedConcepts}");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        modernChatBubble,
        _buildFeedbackButtonsRow(context, theme, message, onThumbUp, onThumbDown, onReport, ref, displayText),
        if (message.relatedConcepts != null && message.relatedConcepts!.isNotEmpty)
          _buildRelatedConcepts(context, ref, message.relatedConcepts!),
      ],
    );
  }

  Widget _buildFeedbackButtonsRow(
    BuildContext context,
    ThemeData theme,
    ChatMessage message,
    Function(String messageId)? onThumbUp,
    Function(String messageId)? onThumbDown,
    Function(String messageId)? onReport,
    WidgetRef ref, // Added WidgetRef
    String textToSpeak // Added text to speak
  ) {
    final Color iconColor = AppColors.textHighEmphasisDark.withOpacity(0.7);
    final Color selectedIconColor = theme.colorScheme.primary;

    final ttsStateData = ref.watch(openAiTtsServiceProvider);
    final bool isLoadingThisMessage = ttsStateData.playerState == OpenAiTtsPlayerState.loading && ttsStateData.currentMessageId == message.id;
    final bool isPlayingThisMessage = ttsStateData.playerState == OpenAiTtsPlayerState.playing && ttsStateData.currentMessageId == message.id;
    final bool isPausedForThisMessage = ttsStateData.playerState == OpenAiTtsPlayerState.paused && ttsStateData.currentMessageId == message.id;

    IconData ttsIconData = Icons.volume_up_outlined;
    VoidCallback? ttsOnPressed = () => ref.read(openAiTtsServiceProvider.notifier).speak(textToSpeak, message.id);
    String ttsTooltip = "Narrate text";

    if (isLoadingThisMessage) {
      ttsIconData = Icons.hourglass_empty_outlined; // Or a CircularProgressIndicator can be used
      ttsOnPressed = null; // Disable while loading
      ttsTooltip = "Loading narration...";
    } else if (isPlayingThisMessage) {
      ttsIconData = Icons.pause_circle_outlined; // Option to pause
      ttsOnPressed = () => ref.read(openAiTtsServiceProvider.notifier).pause();
      ttsTooltip = "Pause narration";
    } else if (isPausedForThisMessage) {
      ttsIconData = Icons.play_circle_outlined; // Option to resume
      ttsOnPressed = () => ref.read(openAiTtsServiceProvider.notifier).resume();
      ttsTooltip = "Resume narration";
    } else if (ttsStateData.playerState == OpenAiTtsPlayerState.playing || ttsStateData.playerState == OpenAiTtsPlayerState.paused) {
      // Another message is playing/paused, show stop icon for this one to allow interruption
      ttsIconData = Icons.stop_circle_outlined; 
      ttsOnPressed = () => ref.read(openAiTtsServiceProvider.notifier).speak(textToSpeak, message.id); // This will stop current and play new
      ttsTooltip = "Stop current & narrate this";
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20.0, top: 2.0, right: 8.0, bottom: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.copy_outlined,
              size: 18,
              color: iconColor,
            ),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message.text));
              showStyledSnackBar(context, message: 'Copied to clipboard');
            },
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            constraints: const BoxConstraints(),
            splashRadius: 18,
            tooltip: "Copy text",
          ),
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              size: 18,
              color: iconColor,
            ),
            onPressed: () {
              Share.share(
                message.text,
                subject: 'Explained by ELI5 App' // Optional: subject for email sharing
              );
            },
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            constraints: const BoxConstraints(),
            splashRadius: 18,
            tooltip: "Share explanation",
          ),
          IconButton(
            icon: Icon(
              ttsIconData,
              size: 18,
              color: (isPlayingThisMessage || isPausedForThisMessage) ? selectedIconColor : iconColor,
            ),
            onPressed: ttsOnPressed,
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            constraints: const BoxConstraints(),
            splashRadius: 18,
            tooltip: ttsTooltip,
          ),
          if (onThumbUp != null)
            AnimatedFeedbackButton(
              iconOutlined: Icons.thumb_up_alt_outlined,
              iconFilled: Icons.thumb_up_alt,
              isSelected: message.userRating == 1,
              iconColor: iconColor,
              selectedIconColor: selectedIconColor,
              onPressed: () => onThumbUp(message.id),
              tooltip: "Helpful",
            ),
          if (onThumbDown != null)
            AnimatedFeedbackButton(
              iconOutlined: Icons.thumb_down_alt_outlined,
              iconFilled: Icons.thumb_down_alt,
              isSelected: message.userRating == -1,
              iconColor: iconColor,
              selectedIconColor: selectedIconColor,
              onPressed: () => onThumbDown(message.id),
              tooltip: "Not helpful",
            ),
          if (onReport != null)
            IconButton(
              icon: Icon(
                Icons.flag_outlined,
                size: 18,
                color: iconColor,
              ),
              onPressed: () => onReport(message.id),
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              constraints: const BoxConstraints(),
              splashRadius: 18,
              tooltip: "Report explanation",
            ),
        ],
      ),
    );
  }

  Widget _buildRelatedConcepts(BuildContext context, WidgetRef ref, List<String> concepts) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, right: 8.0, top: 4.0, bottom: 4.0),
      child: Wrap(
        spacing: 8.0, // Horizontal spacing between chips
        runSpacing: 4.0, // Vertical spacing between lines of chips
        children: concepts.map((concept) {
          return GestureDetector(
            onTap: () {
              ref.read(chatProvider.notifier).sendMessageAndGetResponse(concept);
            },
            child: Chip(
              label: MarkdownBody(
                data: concept,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: TextStyle(
                    color: AppColors.textMediumEmphasisDark,
                    fontSize: 13,
                  ),
                  pPadding: EdgeInsets.zero,
                ),
              ),
              backgroundColor: AppColors.inputFillDark.withOpacity(0.8), // Slightly different from bubble for distinction
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0), // Adjusted padding for MarkdownBody
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: AppColors.kopyaPurple.withOpacity(0.5)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// --- AnimatedFeedbackButton Widget ---
class AnimatedFeedbackButton extends StatefulWidget {
  final IconData iconOutlined;
  final IconData iconFilled;
  final bool isSelected;
  final Color iconColor;
  final Color selectedIconColor;
  final VoidCallback onPressed;
  final String tooltip;
  final double iconSize;

  const AnimatedFeedbackButton({
    super.key,
    required this.iconOutlined,
    required this.iconFilled,
    required this.isSelected,
    required this.iconColor,
    required this.selectedIconColor,
    required this.onPressed,
    required this.tooltip,
    this.iconSize = 18.0,
  });

  @override
  _AnimatedFeedbackButtonState createState() => _AnimatedFeedbackButtonState();
}

class _AnimatedFeedbackButtonState extends State<AnimatedFeedbackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedFeedbackButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _animationController.forward().then((_) => _animationController.reverse());
      } else {
        // Optional: Add a reverse animation if deselected, though often not needed
        // _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: Icon(
          widget.isSelected ? widget.iconFilled : widget.iconOutlined,
          size: widget.iconSize,
          color: widget.isSelected ? widget.selectedIconColor : widget.iconColor,
        ),
        onPressed: () {
          widget.onPressed(); // This will trigger the state change and didUpdateWidget
        },
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        constraints: const BoxConstraints(),
        splashRadius: widget.iconSize + 4, // Slightly larger than icon
        tooltip: widget.tooltip,
      ),
    );
  }
} 
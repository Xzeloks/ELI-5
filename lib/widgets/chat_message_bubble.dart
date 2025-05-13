import 'package:eli5/models/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:eli5/widgets/modern_chat_bubble.dart'; // Import the new bubble
import 'package:eli5/main.dart'; // Import AppColors

class ChatMessageBubble extends StatelessWidget { // Changed to StatelessWidget
  final ChatMessage message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isUserMessage = message.sender == ChatMessageSender.user;
    // final theme = Theme.of(context); // Keep theme for other potential uses

    // Use displayOverride if available, otherwise use the full text.
    final String displayText = message.displayOverride ?? message.text;
    final String timeString = DateFormat('hh:mm a').format(message.timestamp.toLocal());

    final senderColor = AppColors.kopyaPurple;
    final receiverColor = AppColors.inputFillDark;

    // Text colors for the new bubble colors
    // For kopyaPurple (sender), white text is good (onPrimary from your theme).
    // For darkSurface (receiver), high emphasis text from your theme should work.
    final senderTextColor = AppColors.textOnPrimaryDark; // Matches your theme's onPrimary
    final receiverTextColor = AppColors.textHighEmphasisDark; // Good contrast on darkSurface

    return ModernChatBubble(
      message: displayText,
      isSender: isUserMessage,
      time: timeString,
      senderColor: senderColor,
      receiverColor: receiverColor,
      textColor: isUserMessage ? senderTextColor : receiverTextColor,
      timeColor: isUserMessage ? senderTextColor.withOpacity(0.7) : receiverTextColor.withOpacity(0.7),
      // maxWidthFactor: 0.8, // Adjust if needed
    );
  }
} 
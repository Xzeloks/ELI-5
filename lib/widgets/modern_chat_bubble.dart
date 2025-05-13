import 'package:flutter/material.dart';

// Custom Clipper for the chat bubble tail
class BubbleTailClipper extends CustomClipper<Path> {
  final bool isSender;

  BubbleTailClipper({required this.isSender});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (isSender) {
      // Tail for sender (right side)
      path.moveTo(0, size.height - 10); // Start of tail
      path.lineTo(size.width - 10, size.height - 10); // Bottom edge before curve
      path.quadraticBezierTo(size.width, size.height - 10, size.width, size.height - 20); // Curve to tail point
      path.lineTo(size.width, 0); // Move to top-right to ensure the tail is cut off correctly
      path.lineTo(0,0); // Back to start - effectively cutting out the tail shape from a rect
    } else {
      // Tail for receiver (left side)
      path.moveTo(size.width, size.height - 10); // Start of tail (from right)
      path.lineTo(10, size.height - 10); // Bottom edge before curve
      path.quadraticBezierTo(0, size.height - 10, 0, size.height - 20); // Curve to tail point
      path.lineTo(0,0); // Move to top-left
      path.lineTo(size.width, 0); // Back to start
    }
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class ModernChatBubble extends StatelessWidget {
  final String message;
  final bool isSender;
  final String? time; // Optional timestamp
  final Color? senderColor;
  final Color? receiverColor;
  final Color? textColor;
  final Color? timeColor;
  final TextStyle? messageStyle;
  final TextStyle? timeStyle;
  final double maxWidthFactor; // Factor of screen width for max bubble width

  const ModernChatBubble({
    super.key,
    required this.message,
    required this.isSender,
    this.time,
    this.senderColor,
    this.receiverColor,
    this.textColor,
    this.timeColor,
    this.messageStyle,
    this.timeStyle,
    this.maxWidthFactor = 0.75, // Bubble will take max 75% of screen width
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isSender
        ? (senderColor ?? theme.colorScheme.primary)
        : (receiverColor ?? theme.colorScheme.secondaryContainer);
    final messageFinalStyle = messageStyle ??
        TextStyle(
          color: textColor ?? (isSender ? Colors.white : theme.colorScheme.onSecondaryContainer),
          fontSize: 16,
        );
    final timeFinalStyle = timeStyle ??
        TextStyle(
          color: timeColor ?? (isSender ? Colors.white70 : theme.colorScheme.onSecondaryContainer.withOpacity(0.7)),
          fontSize: 11,
        );

    // Define different border radius for sender and receiver
    final BorderRadius bubbleRadius = isSender
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(4), // Sharper corner near tail
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4), // Sharper corner near tail
            bottomLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );

    // Tail properties
    const double tailWidth = 12.0;
    const double tailHeight = 10.0;

    Widget bubbleContent = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * maxWidthFactor),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: bubbleRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Important for Column to wrap content
        children: [
          Text(
            message,
            style: messageFinalStyle,
            textAlign: TextAlign.left, // Text inside bubble should be left aligned
          ),
          if (time != null && time!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              time!,
              style: timeFinalStyle,
            ),
          ],
        ],
      ),
    );

    // Create the tail shape
    Widget tail = ClipPath(
      clipper: BubbleTailClipper(isSender: isSender),
      child: Container(
        width: tailWidth,
        height: tailHeight,
        color: bubbleColor, // Tail color should match bubble color
      ),
    );

    return Padding(
      // Add some margin around the bubble
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end, // Align bubble and tail to bottom
        children: [
          if (!isSender) ...[
            tail,
            const SizedBox(width: 0), // No space between tail and bubble
          ],
          Flexible(child: bubbleContent), // Flexible allows bubble to shrink if text is short
          if (isSender) ...[
            const SizedBox(width: 0), // No space between bubble and tail
            tail,
          ],
        ],
      ),
    );
  }
} 
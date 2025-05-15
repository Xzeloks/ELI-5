import 'package:flutter/material.dart';
import 'package:eli5/main.dart'; // Import main.dart to access AppColors

class AppSnackbar {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove any existing snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.inputFillDark, // Use consistent background
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.inputFillDark, // Use consistent background
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.inputFillDark, // Use consistent background
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
    );
  }

  // New method for Undoable Actions
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndoableAction(
    BuildContext context, 
    String message, 
    { // Use named parameter for onUndo for clarity
      required VoidCallback onUndo,
      String undoLabel = 'UNDO',
      Duration duration = const Duration(seconds: 4),
    }
  ) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.inputFillDark, // Use consistent background
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        duration: duration,
        action: SnackBarAction(
          label: undoLabel,
          textColor: Theme.of(context).colorScheme.primary, // Consistent with history screen
          onPressed: () {
            // Important: The SnackBar must be dismissed by its own action for .closed.then to get SnackBarClosedReason.action
            ScaffoldMessenger.of(context).hideCurrentSnackBar(reason: SnackBarClosedReason.action);
            onUndo(); // Execute the provided undo logic
          },
        ),
      ),
    );
  }
} 
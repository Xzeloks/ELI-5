import 'package:flutter/material.dart';
import 'package:eli5/main.dart'; // For AppColors

// Returns the SnackBarClosedReason future
Future<SnackBarClosedReason> showStyledSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: isError ? Colors.redAccent : AppColors.inputFillDark,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isError ? Colors.red.shade700 : AppColors.kopyaPurple,
          width: 1.0,
        ),
      ),
      duration: duration,
      action: action,
    ),
  ).closed;
} 
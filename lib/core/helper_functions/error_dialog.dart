import 'package:flutter/material.dart';

/// Shows a friendly error dialog with a single OK button. Never a stack trace.
void showErrorDialog(BuildContext context, String message) {
  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Error'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

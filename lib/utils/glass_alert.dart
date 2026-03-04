import 'package:flutter/material.dart';
import 'package:sme_buddy/utils/glass_dialog.dart';

class GlassAlert {
  static Future<void> show(BuildContext context, {
    required String title,
    required String message,
    String buttonText = "OK",
    Color buttonColor = Colors.cyanAccent,
    VoidCallback? onPressed,
  }) {
    return GlassDialog.show(
      context, 
      title: title,
      child: Text(
        message, 
        style: const TextStyle(fontSize: 16, color: Colors.white70),
        textAlign: TextAlign.center,
      ),
      actions: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (onPressed != null) onPressed();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor.withValues(alpha: 0.8),
              foregroundColor: buttonColor == Colors.white ? Colors.black : Colors.black,
            ),
            child: Text(buttonText),
          ),
        ),
      ],
    );
  }

  static Future<bool> confirm(BuildContext context, {
    required String title,
    required String message,
    String confirmText = "CONFIRM",
    String cancelText = "CANCEL",
    Color confirmColor = Colors.red,
  }) async {
    final result = await GlassDialog.show<bool>(
      context, 
      title: title,
      child: Text(
        message, 
        style: const TextStyle(fontSize: 16, color: Colors.white70),
        textAlign: TextAlign.center,
      ),
      actions: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText, style: const TextStyle(color: Colors.grey)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor.withValues(alpha: 0.8),
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ),
      ],
    );
    return result ?? false;
  }
}

import 'package:flutter/material.dart';

class UpgradeDialog extends StatelessWidget {
  final String title;
  final String message;

  const UpgradeDialog({
    super.key, 
    required this.title,
    required this.message
  });

  static Future<void> show(BuildContext context, {String reason = "Trial Expired"}) async {
    await showDialog(
      context: context, 
      barrierDismissible: true,
      builder: (_) => UpgradeDialog(
        title: reason,
        message: "Subscription settings and account status are managed via the Synthora website.",
      )
    );
  }

  @override
  Widget build(BuildContext context) {
     return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock_clock, color: Colors.orange),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(message, style: const TextStyle(fontSize: 14)),
             const SizedBox(height: 16),
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: Colors.grey.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(8),
                 border: Border.all(color: Colors.grey.withValues(alpha: 0.3))
               ),
               child: const Column(
                 children: [
                   Text("Visit website:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                   SizedBox(height: 4),
                   Text("yourdomain.com", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                 ],
               ),
             ),
             const SizedBox(height: 8),
             const Text(
               "Note available on web only to keep subscription prices lower.",
               style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
             ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
     );
  }
}

import 'package:flutter/material.dart';
import 'package:sme_buddy/features/subscription/plans_screen.dart';

class UpgradeDialog extends StatelessWidget {
  final String title;
  final String message;

  const UpgradeDialog({
    super.key, 
    required this.title,
    required this.message,
  });

  static Future<void> show(BuildContext context, {String reason = "Subscription Required"}) async {
    await showDialog(
      context: context, 
      barrierDismissible: true,
      builder: (_) => UpgradeDialog(
        title: reason,
        message: "Unlock unlimited products, employee roles, GRN management, and advanced analytics with POS Podda Pro.",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.stars, color: Color(0xFF6366F1), size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(fontSize: 14, height: 1.4)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.payment, size: 20, color: Color(0xFF6366F1)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Plans start from Rs. 2,325 / month via Payments.lk (Cards & LANKAQR supported)",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("NOT NOW", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen()));
          },
          child: const Text("VIEW PLANS & UPGRADE", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sme_buddy/utils/glass_card.dart';

// Helper for Glassy Dialogs
class GlassDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final double width;

  const GlassDialog({
    super.key, 
    required this.child, 
    this.title, 
    this.actions,
    this.width = 400,
  });

  static Future<T?> show<T>(BuildContext context, {
    required Widget child, 
    String? title,
    List<Widget>? actions
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => GlassDialog(title: title, actions: actions, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: GlassCard(
        width: width,
        borderRadius: 24,
        padding: const EdgeInsets.all(0), 
        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE8ECEF),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF282E3A) : const Color(0xFFCBD5E1))),
                ),
                child: Text(
                  title!.toUpperCase(), 
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 1.5, 
                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: child,
            ),

            if (actions != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161920) : const Color(0xFFDFE4EA),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

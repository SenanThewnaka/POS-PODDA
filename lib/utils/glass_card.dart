import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final Color? color;
  final double borderRadius;
  final BoxBorder? border;

  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 20.0,
    this.border,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // DEEP GLASS (Slate/Zinc Refinement)
    final defaultColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.92);
    final cardColor = color ?? defaultColor;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: borderColor, width: 1.0),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: const Color(0xFF334155).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(-3, -3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 12,
                  offset: const Offset(4, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.95),
                  blurRadius: 10,
                  offset: const Offset(-4, -4),
                ),
                BoxShadow(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(4, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            // Blur Layer - Web performance optimization
            if (!kIsWeb)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(color: Colors.transparent),
                ),
              ),
            // Content Layer
            Padding(
              padding: padding ?? const EdgeInsets.all(16.0),
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap != null || onLongPress != null) {
      return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: content,
      );
    }

    return content;
  }
}

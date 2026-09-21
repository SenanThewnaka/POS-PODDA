import 'package:flutter/material.dart';

enum NeumorphicElevation {
  flat,      // Level 0
  subtle,    // Level 1: depth ~2
  standard,  // Level 2: depth ~4
  pronounced,// Level 3: depth ~6
  concave,   // Inset / pressed / sunken
}

/// Reusable Neumorphic container providing tactile dual-shadow elevation
/// for both Light (Soft Clay) and Dark (Deep Slate) themes.
class NeumorphicCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final NeumorphicElevation elevation;
  final Color? color;
  final VoidCallback? onTap;
  final Border? border;
  final double? width;
  final double? height;
  final ShapeBorder? customShape;

  const NeumorphicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
    this.elevation = NeumorphicElevation.standard,
    this.color,
    this.onTap,
    this.border,
    this.width,
    this.height,
    this.customShape,
  });

  @override
  State<NeumorphicCard> createState() => _NeumorphicCardState();
}

class _NeumorphicCardState extends State<NeumorphicCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConcave = widget.elevation == NeumorphicElevation.concave || _isPressed;

    // Default base colors
    final Color surfaceColor = widget.color ??
        (isDark
            ? (isConcave ? const Color(0xFF0F172A) : const Color(0xFF1E293B))
            : (isConcave ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)));

    // Shadow configuration
    List<BoxShadow> shadows = [];
    if (widget.elevation != NeumorphicElevation.flat) {
      if (isConcave) {
        // Sunken / Inset effect
        shadows = isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: const Color(0xFF334155).withValues(alpha: 0.2),
                  offset: const Offset(-2, -2),
                  blurRadius: 4,
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.4),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  offset: const Offset(-2, -2),
                  blurRadius: 4,
                ),
              ];
      } else {
        // Extruded Outset effect
        final double dist = widget.elevation == NeumorphicElevation.pronounced
            ? 6.0
            : (widget.elevation == NeumorphicElevation.subtle ? 2.5 : 4.0);
        final double blur = widget.elevation == NeumorphicElevation.pronounced
            ? 12.0
            : (widget.elevation == NeumorphicElevation.subtle ? 6.0 : 9.0);

        shadows = isDark
            ? [
                // Top-left soft highlight
                BoxShadow(
                  color: const Color(0xFF334155).withValues(alpha: 0.45),
                  offset: Offset(-dist * 0.7, -dist * 0.7),
                  blurRadius: blur,
                ),
                // Bottom-right dark drop shadow
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  offset: Offset(dist, dist),
                  blurRadius: blur,
                ),
              ]
            : [
                // Top-left white light source
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.95),
                  offset: Offset(-dist, -dist),
                  blurRadius: blur,
                ),
                // Bottom-right soft grey shadow
                BoxShadow(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.35),
                  offset: Offset(dist, dist),
                  blurRadius: blur,
                ),
              ];
      }
    }

    final cardContent = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.border ??
            Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.6),
              width: 1,
            ),
        boxShadow: shadows,
      ),
      child: widget.child,
    );

    if (widget.onTap == null) {
      return cardContent;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: cardContent,
      ),
    );
  }
}

/// Tactile Neumorphic Button with realistic sink-in press state
class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool isSelected;
  final double? width;
  final double? height;

  const NeumorphicButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.borderRadius = 12,
    this.isSelected = false,
    this.width,
    this.height,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = widget.isSelected || _isPressed;

    final baseColor = widget.color ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));

    return GestureDetector(
      onTapDown: widget.onPressed == null ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onPressed == null ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.onPressed == null ? null : () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: widget.width,
        height: widget.height,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: active
                ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.7)),
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    offset: const Offset(1.5, 1.5),
                    blurRadius: 3,
                  ),
                ]
              : (isDark
                  ? [
                      BoxShadow(
                        color: const Color(0xFF334155).withValues(alpha: 0.4),
                        offset: const Offset(-2, -2),
                        blurRadius: 5,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        offset: const Offset(3, 3),
                        blurRadius: 6,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.9),
                        offset: const Offset(-2.5, -2.5),
                        blurRadius: 5,
                      ),
                      BoxShadow(
                        color: const Color(0xFF94A3B8).withValues(alpha: 0.35),
                        offset: const Offset(2.5, 2.5),
                        blurRadius: 5,
                      ),
                    ]),
        ),
        child: widget.child,
      ),
    );
  }
}

import 'package:flutter/material.dart';

class GlassCard extends StatefulWidget {
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
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Pronounced Physical Neumorphism (Warm Ceramic & Deep Charcoal Clay)
    final defaultBaseColor = isDark ? const Color(0xFF1E222B) : const Color(0xFFE8ECEF);
    final cardColor = widget.color ?? defaultBaseColor;
    
    final defaultBorder = isDark
        ? Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.0)
        : Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.0);

    // Tactile physical dual shadows
    final List<BoxShadow> shadows = isDark
        ? [
            // Top-left soft specular light source
            BoxShadow(
              color: const Color(0xFF2C323F).withValues(alpha: _isPressed ? 0.3 : 0.65),
              blurRadius: _isPressed ? 4 : 8,
              offset: _isPressed ? const Offset(-2, -2) : const Offset(-4, -4),
            ),
            // Bottom-right deep ambient drop shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: _isPressed ? 0.5 : 0.75),
              blurRadius: _isPressed ? 5 : 10,
              offset: _isPressed ? const Offset(2, 2) : const Offset(4, 4),
            ),
          ]
        : [
            // Top-left crisp white light source
            BoxShadow(
              color: Colors.white.withValues(alpha: _isPressed ? 0.6 : 0.95),
              blurRadius: _isPressed ? 5 : 10,
              offset: _isPressed ? const Offset(-2, -2) : const Offset(-5, -5),
            ),
            // Bottom-right rich clay shadow
            BoxShadow(
              color: const Color(0xFFA3B1C2).withValues(alpha: _isPressed ? 0.4 : 0.65),
              blurRadius: _isPressed ? 6 : 10,
              offset: _isPressed ? const Offset(2, 2) : const Offset(5, 5),
            ),
          ];

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      padding: widget.padding ?? const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.border ?? defaultBorder,
        boxShadow: shadows,
      ),
      child: widget.child,
    );

    if (widget.onTap != null || widget.onLongPress != null) {
      return GestureDetector(
        onTapDown: (_) {
          if (mounted) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (mounted) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (mounted) setState(() => _isPressed = false);
        },
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: content,
      );
    }

    return content;
  }
}

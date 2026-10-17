import 'package:flutter/material.dart';

/// Pixel-perfect vector representation of the official 4-color Google 'G' logo
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: const GoogleLogoPainter(),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 48.0;

    // Red segment (top)
    final redPath = Path()
      ..moveTo(scale * 24.0, scale * 9.5)
      ..cubicTo(scale * 27.54, scale * 9.5, scale * 30.71, scale * 10.72, scale * 33.21, scale * 13.1)
      ..lineTo(scale * 40.06, scale * 6.25)
      ..cubicTo(scale * 35.9, scale * 2.38, scale * 30.47, 0, scale * 24.0, 0)
      ..cubicTo(scale * 14.62, 0, scale * 6.51, scale * 5.38, scale * 2.56, scale * 13.22)
      ..lineTo(scale * 10.54, scale * 19.41)
      ..cubicTo(scale * 12.43, scale * 13.72, scale * 17.74, scale * 9.5, scale * 24.0, scale * 9.5)
      ..close();
    canvas.drawPath(redPath, Paint()..color = const Color(0xFFEA4335)..isAntiAlias = true);

    // Blue segment (right)
    final bluePath = Path()
      ..moveTo(scale * 46.98, scale * 24.55)
      ..cubicTo(scale * 46.98, scale * 22.98, scale * 46.83, scale * 21.46, scale * 46.6, scale * 20.0)
      ..lineTo(scale * 24.0, scale * 20.0)
      ..lineTo(scale * 24.0, scale * 29.02)
      ..lineTo(scale * 36.94, scale * 29.02)
      ..cubicTo(scale * 36.36, scale * 31.98, scale * 34.68, scale * 34.5, scale * 32.16, scale * 36.2)
      ..lineTo(scale * 39.89, scale * 42.2)
      ..cubicTo(scale * 44.4, scale * 38.02, scale * 46.98, scale * 31.84, scale * 46.98, scale * 24.55)
      ..close();
    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF4285F4)..isAntiAlias = true);

    // Yellow segment (left)
    final yellowPath = Path()
      ..moveTo(scale * 10.53, scale * 28.59)
      ..cubicTo(scale * 10.05, scale * 27.14, scale * 9.77, scale * 25.6, scale * 9.77, scale * 24.0)
      ..cubicTo(scale * 9.77, scale * 22.4, scale * 10.05, scale * 20.86, scale * 10.53, scale * 19.41)
      ..lineTo(scale * 2.56, scale * 13.22)
      ..cubicTo(scale * 0.92, scale * 16.46, 0, scale * 20.12, 0, scale * 24.0)
      ..cubicTo(0, scale * 27.88, scale * 0.92, scale * 31.54, scale * 2.56, scale * 34.78)
      ..lineTo(scale * 10.53, scale * 28.59)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFFBBC05)..isAntiAlias = true);

    // Green segment (bottom)
    final greenPath = Path()
      ..moveTo(scale * 24.0, scale * 48.0)
      ..cubicTo(scale * 30.48, scale * 48.0, scale * 35.93, scale * 45.87, scale * 39.89, scale * 42.19)
      ..lineTo(scale * 32.16, scale * 36.19)
      ..cubicTo(scale * 30.01, scale * 37.64, scale * 27.24, scale * 38.49, scale * 24.0, scale * 38.49)
      ..cubicTo(scale * 17.74, scale * 38.49, scale * 12.43, scale * 34.27, scale * 10.53, scale * 28.59)
      ..lineTo(scale * 2.56, scale * 34.78)
      ..cubicTo(scale * 6.51, scale * 42.62, scale * 14.62, scale * 48.0, scale * 24.0, scale * 48.0)
      ..close();
    canvas.drawPath(greenPath, Paint()..color = const Color(0xFF34A853)..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official styled Google Sign-In button adhering to Google Identity branding
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF3C4043),
          side: BorderSide(
            color: isDark ? Colors.white24 : const Color(0xFFDADCE0),
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isDark ? 0 : 1,
          shadowColor: Colors.black.withValues(alpha: 0.08),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? Colors.white70 : const Color(0xFF4285F4),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GoogleLogo(size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF3C4043),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

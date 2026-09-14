import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// Provider for the current ThemeMode (light, dark, system)
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode');
    if (saved == 'light') state = ThemeMode.light;
    else if (saved == 'dark') state = ThemeMode.dark;
    else state = ThemeMode.system;
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.light) prefs.setString('themeMode', 'light');
    else if (mode == ThemeMode.dark) prefs.setString('themeMode', 'dark');
    else prefs.setString('themeMode', 'system');
  }
}

final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class AppTheme {
  // --- LIGHT THEME (Slate / Crisp Clean) ---
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      surface: Colors.white,
      primary: Color(0xFF4F46E5), // Indigo 600
      onPrimary: Colors.white,
      secondary: Color(0xFF059669), // Emerald 600
      onSecondary: Colors.white,
      tertiary: Color(0xFF0284C7), // Sky 600
      error: Color(0xFFDC2626),
      onSurface: Color(0xFF0F172A),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: const Color(0xFF1E293B),
      displayColor: const Color(0xFF0F172A),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ),
  );

  // --- DARK THEME (Refined Slate / Indigo Glass) ---
  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      surface: Color(0xFF1E293B), // Slate 800
      primary: Color(0xFF6366F1), // Electric Indigo
      onPrimary: Colors.white,
      secondary: Color(0xFF10B981), // Emerald
      onSecondary: Colors.white,
      tertiary: Color(0xFF38BDF8), // Sky
      error: Color(0xFFEF4444),
      onSurface: Color(0xFFF8FAFC), // Slate 50
    ),
    scaffoldBackgroundColor: const Color(0xFF0B0F19), // Deep Slate Canvas
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Color(0xFFF8FAFC),
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      color: const Color(0xFF1E293B).withOpacity(0.85),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: const Color(0xFFE2E8F0),
      displayColor: const Color(0xFFF8FAFC),
    ).copyWith(
      bodyMedium: GoogleFonts.plusJakartaSans(color: const Color(0xFFE2E8F0), fontSize: 14),
      titleMedium: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      headlineSmall: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E293B),
      hintStyle: const TextStyle(color: Color(0xFF64748B)),
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
    dividerTheme: const DividerThemeData(color: Color(0xFF334155), thickness: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1E293B),
      modalBackgroundColor: Color(0xFF1E293B),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF1E293B),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Color(0xFF6366F1),
      selectionColor: Color(0x4D6366F1),
      selectionHandleColor: Color(0xFF6366F1),
    ),
  );
}

/// Neumorphic design system decoration utilities for soft dual-shadow surfaces
class NeumorphicDecoration {
  static BoxDecoration convex({
    required bool isDark,
    double borderRadius = 16,
    Color? color,
    Border? border,
    double depth = 4,
  }) {
    final baseColor = color ?? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
    return BoxDecoration(
      color: baseColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ??
          Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.6),
            width: 1,
          ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: const Color(0xFF334155).withValues(alpha: 0.4),
                offset: Offset(-depth * 0.7, -depth * 0.7),
                blurRadius: depth * 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                offset: Offset(depth, depth),
                blurRadius: depth * 2.2,
              ),
            ]
          : [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.95),
                offset: Offset(-depth, -depth),
                blurRadius: depth * 2,
              ),
              BoxShadow(
                color: const Color(0xFF94A3B8).withValues(alpha: 0.35),
                offset: Offset(depth, depth),
                blurRadius: depth * 2,
              ),
            ],
    );
  }

  static BoxDecoration concave({
    required bool isDark,
    double borderRadius = 16,
    Color? color,
    Border? border,
    double depth = 3,
  }) {
    final baseColor = color ?? (isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0));
    return BoxDecoration(
      color: baseColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ??
          Border.all(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
            width: 1,
          ),
      boxShadow: [
        BoxShadow(
          color: isDark ? Colors.black.withValues(alpha: 0.5) : const Color(0xFF94A3B8).withValues(alpha: 0.4),
          offset: Offset(depth * 0.6, depth * 0.6),
          blurRadius: depth * 1.5,
        ),
      ],
    );
  }
}

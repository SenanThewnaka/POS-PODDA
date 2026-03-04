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
  // --- LIGHT THEME ---
  static final lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.cyan, // BLUE SHIFT
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF0F4F8), // Slightly blue-ish grey
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      iconTheme: IconThemeData(color: Colors.black),
    ),
    cardTheme: CardThemeData(
      elevation: 0, 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    textTheme: GoogleFonts.outfitTextTheme().apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyan, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.cyan, // Primary color
        foregroundColor: Colors.white, // Text color
        elevation: 0,
      ),
    ),
  );

  // --- DARK THEME (Neon Glass - CYBER BLUE) ---
  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.cyan,
      brightness: Brightness.dark,
    ).copyWith(
      background: const Color(0xFF050505), // Deep Black
      surface: const Color(0xFF101015), // Slightly blue tinted black
      onSurface: Colors.white,
      primary: Colors.cyanAccent, // Neon Blue
      secondary: Colors.blueAccent,
      tertiary: Colors.purpleAccent,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF000000), 
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, 
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      iconTheme: IconThemeData(color: Colors.cyanAccent),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.1)),
      ),
      color: const Color(0xFF101520).withValues(alpha: 0.5), // Blue-ish Glass
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: const Color(0xFFE0EFFF), // Cool White
      displayColor: Colors.white,
    ).copyWith(
      bodyMedium: GoogleFonts.outfit(
        color: const Color(0xFFE0EFFF),
        shadows: [const Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 2)],
      ),
      titleMedium: GoogleFonts.outfit(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        shadows: [const Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 2)],
      ),
      headlineSmall: GoogleFonts.outfit(
         color: Colors.white,
         fontWeight: FontWeight.bold,
         shadows: [const Shadow(color: Colors.cyan, offset: Offset(0, 0), blurRadius: 8)], // Glow
       ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.blue.withValues(alpha: 0.05),
      hintStyle: TextStyle(color: Colors.blueGrey.shade200),
      labelStyle: const TextStyle(color: Colors.cyanAccent),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 1),
      ),
      contentPadding: const EdgeInsets.all(20),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.cyanAccent.withValues(alpha: 0.8), 
        foregroundColor: Colors.black, // Low contrast text on neon
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        shadowColor: Colors.cyanAccent.withValues(alpha: 0.5),
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.cyanAccent),
    dividerTheme: DividerThemeData(color: Colors.cyanAccent.withValues(alpha: 0.1)),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: const Color(0xFF050A10).withValues(alpha: 0.9), // Deep Blue Black
      modalBackgroundColor: const Color(0xFF050A10).withValues(alpha: 0.9),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF101520).withValues(alpha: 0.9),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.2))),
      titleTextStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.cyanAccent,
      selectionColor: Colors.cyanAccent,
      selectionHandleColor: Colors.cyanAccent,
    ),
  );
}

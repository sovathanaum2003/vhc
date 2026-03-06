import 'package:flutter/material.dart';

class AppColors {
  // --- 1. THEME STATE MANAGEMENT ---
  // We keep the notifier here to eliminate the need for ThemeManager.dart
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  static void toggleTheme(bool isDark) {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // --- 2. RAW PALETTE (Private) ---
  // Define your hex codes here
  static const Color _darkBlue = Color(0xFF001439);
  static const Color _blue = Color(0xFF2A8CD5);
  static const Color _brightBlue = Color(0xFF9FCCFF);
  static const Color _whiteBlue = Color(0xFFEBF4FF);

  static const Color _darkBg = Color(0xFF050A15);
  static const Color _darkSurface = Color(0xFF121E36);

  static const Color _red = Color(0xFFE70000);
  static const Color _green = Color(0xFF009A00);
  static const Color _orange = Color(0xFFFA8500);

  // --- 3. DYNAMIC COLORS (Public) ---
  // Call these methods with 'context' to get the correct color automatically

  // Backgrounds
  static Color scaffoldBackground(BuildContext context) {
    return _isDark(context) ? _darkBg : _whiteBlue;
  }

  static Color cardBackground(BuildContext context) {
    return _isDark(context) ? _darkSurface : Colors.white;
  }

  static Color inputFillColor(BuildContext context) {
    return _isDark(context) ? _darkSurface : Colors.white;
  }

  // Text & Icons
  static Color primaryText(BuildContext context) {
    return _isDark(context) ? Colors.white : _darkBlue;
  }

  static Color secondaryText(BuildContext context) {
    return _isDark(context) ? Colors.grey[400]! : Colors.grey[500]!;
  }

  static Color iconColor(BuildContext context) {
    return _isDark(context) ? Colors.white : _darkBlue;
  }

  // Buttons & Accents
  static Color primaryButton(BuildContext context) {
    // Light mode uses dark blue button, Dark mode uses lighter blue button for visibility
    return _isDark(context) ? _blue : _darkBlue;
  }

  static Color primaryButtonText(BuildContext context) {
    return Colors.white; // Always white
  }

  static Color accentColor(BuildContext context) {
    return _blue;
  }

  // Status Colors (Usually static, but wrapped for consistency)
  static Color get red => _red;
  static Color get green => _green;
  static Color get orange => _orange;

  // --- Helper ---
  static bool _isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}
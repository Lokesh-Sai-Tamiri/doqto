import 'package:flutter/material.dart';

/// All colors from docs/design.md. Never inline a Color(...) outside this file.
class AppColors {
  AppColors._();

  // --- Primary palette (med-blue) ---
  static const Color medBlue = Color(0xFF1A56DB);
  static const Color medBlueDark = Color(0xFF0F3499);
  static const Color medBlueMid = Color(0xFF5B8FFF);
  static const Color medBlueLight = Color(0xFFEBF3FF);

  // --- Accent (med-teal) ---
  static const Color medTeal = Color(0xFF0ABFAD);
  static const Color medTealLight = Color(0xFFE0FAF7);

  // --- Neutrals ---
  static const Color gray50 = Color(0xFFF8FAFD);
  static const Color gray100 = Color(0xFFEEF2F8);
  static const Color gray200 = Color(0xFFD6DDF0);
  static const Color gray400 = Color(0xFF8A9CC4);
  static const Color gray600 = Color(0xFF4A5E8C);
  static const Color gray800 = Color(0xFF1C2B4A);
  static const Color gray900 = Color(0xFF0D1829);
  static const Color white = Color(0xFFFFFFFF);

  // --- Semantic ---
  static const Color green = Color(0xFF22C55E);
  static const Color greenLight = Color(0xFFDCFCE7);
  static const Color greenDark = Color(0xFF15803D);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberText = Color(0xFF92400E);
  static const Color amberLight = Color(0xFFFEF3C7);
  static const Color red = Color(0xFFEF4444);
  static const Color redLight = Color(0xFFFEF2F2);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleText = Color(0xFF6B21A8);
  static const Color purpleLight = Color(0xFFF3E8FF);
  static const Color tealBadgeText = Color(0xFF0D6B62);

  // --- Role semantics (named after design.md usage, not hex) ---
  static Color get appBg => gray50;
  static Color get surface => white;
  static Color get surfaceTinted => medBlueLight;
  static Color get divider => gray100;
  static Color get border => gray200;
  static Color get textPrimary => gray800;
  static Color get textSecondary => gray600;
  static Color get textMuted => gray400;
  static Color get textDisplay => gray900;
  static Color get primary => medBlue;
  static Color get onPrimary => white;

  // --- Avatar color cycle — index 0..4 ---
  static const List<Color> avatarCycle = [
    medBlue,
    medTeal,
    purple,
    medBlueDark,
    amber,
  ];

  static Color avatarColorFor(int index) => avatarCycle[index % avatarCycle.length];

  // --- Presence dot colors ---
  static const Color presenceOnline = green;
  static const Color presenceAway = amber;
  static const Color presenceOffline = gray400;
}

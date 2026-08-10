import 'package:flutter/material.dart';

/// Elevation tokens from docs/design.md §6.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x141E2A5A), // brand navy @ 8%
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x211E2A5A), // brand navy @ 13%
      blurRadius: 24,
      offset: Offset(0, 4),
    ),
  ];
}

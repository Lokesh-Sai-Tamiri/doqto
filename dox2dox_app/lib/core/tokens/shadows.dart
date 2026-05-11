import 'package:flutter/material.dart';

/// Elevation tokens from docs/design.md §6.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x141A56DB), // rgba(26,86,219,0.08)
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x211A56DB), // rgba(26,86,219,0.13)
      blurRadius: 24,
      offset: Offset(0, 4),
    ),
  ];
}

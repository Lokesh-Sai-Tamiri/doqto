import 'package:flutter/material.dart';

/// Border radius tokens from docs/design.md §5.
class AppRadii {
  AppRadii._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double full = 999;

  static BorderRadius get rXs => BorderRadius.circular(xs);
  static BorderRadius get rSm => BorderRadius.circular(sm);
  static BorderRadius get rMd => BorderRadius.circular(md);
  static BorderRadius get rLg => BorderRadius.circular(lg);
  static BorderRadius get rXl => BorderRadius.circular(xl);
  static BorderRadius get rFull => BorderRadius.circular(full);

  // Chat bubbles — asymmetric (design.md §5)
  static const BorderRadius bubbleReceived = BorderRadius.only(
    topLeft: Radius.circular(xs),
    topRight: Radius.circular(lg),
    bottomRight: Radius.circular(lg),
    bottomLeft: Radius.circular(lg),
  );

  static const BorderRadius bubbleSent = BorderRadius.only(
    topLeft: Radius.circular(lg),
    topRight: Radius.circular(lg),
    bottomRight: Radius.circular(xs),
    bottomLeft: Radius.circular(lg),
  );
}

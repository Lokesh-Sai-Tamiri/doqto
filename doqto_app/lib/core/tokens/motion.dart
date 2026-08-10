import 'package:flutter/widgets.dart';

/// Motion tokens — durations and curves.
///
/// Exit is ALWAYS shorter than enter. Respect reduced motion via
/// [AppMotion.maybe] (returns Duration.zero when animations are disabled).
class AppMotion {
  AppMotion._();

  // --- Durations ---
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);

  /// Entrance transitions (fade/slide in).
  static const Duration enter = base;

  /// Exit transitions — always shorter than [enter].
  static const Duration exit = fast;

  /// Micro-interactions: press scale, tick crossfade, icon swaps.
  static const Duration micro = fast;

  /// Emphasized/hero transitions (sheet open, large reveals).
  static const Duration emphasizedDuration = slow;

  /// How long transient success feedback is held before reverting
  /// (e.g. copy button morphing to a check mark).
  static const Duration confirmHold = Duration(milliseconds: 1500);

  // --- Stagger (list entrances) ---
  /// Per-item delay for staggered list entrances.
  static const Duration staggerInterval = Duration(milliseconds: 35);

  /// Items beyond this index enter without extra delay.
  static const int staggerCap = 8;

  // --- Curves ---
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Entrance curve — decelerate into place.
  static const Curve curveEnter = Curves.easeOutCubic;

  /// Exit curve — accelerate away.
  static const Curve curveExit = Curves.easeIn;

  /// Returns [d], or Duration.zero when the platform requests reduced motion.
  static Duration maybe(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;

  /// True when the platform requests reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

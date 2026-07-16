/// Spacing tokens from docs/design.md §4. Base unit = 4px.
/// Never use raw paddings like `EdgeInsets.all(16)` — use `AppSpacing.lg`.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  // Screen defaults
  static const double screenHorizontal = lg;
  static const double cardPadding = lg;
}

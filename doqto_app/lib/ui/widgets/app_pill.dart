import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';
import '../../core/enums/app_enums.dart';
import '../../core/tokens/colors.dart';
import '../../core/tokens/radii.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';

/// Semantic tone of an [AppPill] — maps to existing token color pairs.
enum PillTone { brand, neutral, success, warn, danger }

/// Small rounded status/label pill (badge). Tokens-only, static (no motion).
///
/// Tone → (background, foreground):
/// - brand   → medBlueLight / medBlueDark
/// - neutral → gray100 / gray600
/// - success → greenLight / greenDark
/// - warn    → amberLight / amberText
/// - danger  → redLight / red
class AppPill extends StatelessWidget {
  final String label;
  final PillTone tone;
  final IconData? icon;
  final double? fontSize;

  const AppPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.fontSize,
  });

  static Color backgroundFor(PillTone tone) => switch (tone) {
        PillTone.brand => AppColors.medBlueLight,
        PillTone.neutral => AppColors.gray100,
        PillTone.success => AppColors.greenLight,
        PillTone.warn => AppColors.amberLight,
        PillTone.danger => AppColors.redLight,
      };

  static Color foregroundFor(PillTone tone) => switch (tone) {
        PillTone.brand => AppColors.medBlueDark,
        PillTone.neutral => AppColors.gray600,
        PillTone.success => AppColors.greenDark,
        PillTone.warn => AppColors.amberText,
        PillTone.danger => AppColors.red,
      };

  @override
  Widget build(BuildContext context) {
    final fg = foregroundFor(tone);
    final style = AppText.badge.copyWith(color: fg, fontSize: fontSize);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: backgroundFor(tone),
        borderRadius: AppRadii.rFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: (fontSize ?? 11) + 2, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: style),
        ],
      ),
    );
  }
}

/// Connection-degree badge ("1st" / "2nd" / "Group") — brand-toned [AppPill].
/// String-based for now; retypes onto ConnectionDegree when that enum lands (M1).
class DegreeBadge extends StatelessWidget {
  final String label;

  const DegreeBadge(this.label, {super.key});

  /// Short wire label for a [ConnectionDegree], or null for [out]/[third]
  /// (nothing worth badging — degrees past 2nd read as "not in network").
  static String? labelFor(ConnectionDegree degree) => switch (degree) {
        ConnectionDegree.first => Strings.netDegreeFirst,
        ConnectionDegree.second => Strings.netDegreeSecond,
        ConnectionDegree.third => null,
        ConnectionDegree.out => null,
      };

  /// Typed convenience: a badge for [degree], or null when there's nothing to
  /// show (so callers can `?? const SizedBox.shrink()`).
  static Widget? forDegree(ConnectionDegree degree) {
    final l = labelFor(degree);
    return l == null ? null : DegreeBadge(l);
  }

  @override
  Widget build(BuildContext context) =>
      AppPill(label: label, tone: PillTone.brand);
}

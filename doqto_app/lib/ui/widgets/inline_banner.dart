import 'package:flutter/material.dart';

import '../../core/tokens/colors.dart';
import '../../core/tokens/motion.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';

/// Semantic tone of an [InlineBanner] — amber / blue / gray / red pairs.
enum BannerTone { warn, info, neutral, danger }

/// Thin full-width strip that animates open/closed (height 26 → 0), the same
/// collapse pattern as the original ConnectivityBanner. Tokens-only; respects
/// reduced motion via [AppMotion.maybe].
class InlineBanner extends StatelessWidget {
  final BannerTone tone;
  final String text;
  final IconData? icon;

  /// Optional leading widget (e.g. a small progress spinner). Wins over [icon].
  final Widget? leading;

  /// Optional trailing action (e.g. a small text button).
  final Widget? action;

  final bool visible;

  const InlineBanner({
    super.key,
    required this.tone,
    required this.text,
    this.icon,
    this.leading,
    this.action,
    this.visible = true,
  });

  static Color backgroundFor(BannerTone tone) => switch (tone) {
        BannerTone.warn => AppColors.amberLight,
        BannerTone.info => AppColors.medBlueLight,
        BannerTone.neutral => AppColors.gray100,
        BannerTone.danger => AppColors.redLight,
      };

  static Color foregroundFor(BannerTone tone) => switch (tone) {
        BannerTone.warn => AppColors.amberText,
        BannerTone.info => AppColors.medBlueDark,
        BannerTone.neutral => AppColors.gray600,
        BannerTone.danger => AppColors.red,
      };

  @override
  Widget build(BuildContext context) {
    final fg = foregroundFor(tone);
    return AnimatedContainer(
      duration: AppMotion.maybe(context, AppMotion.base),
      curve: Curves.easeOut,
      height: visible ? 26 : 0,
      color: backgroundFor(tone),
      child: visible
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.sm),
                ] else if (icon != null) ...[
                  Icon(icon, size: 13, color: fg),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: fg),
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  action!,
                ],
              ],
            )
          : null,
    );
  }
}

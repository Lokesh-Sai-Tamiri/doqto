import 'package:flutter/material.dart';

import '../../core/tokens/colors.dart';
import '../../core/tokens/radii.dart';
import '../../core/tokens/typography.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (AppColors.medBlue, AppColors.white, null),
      AppButtonVariant.secondary => (AppColors.medBlueLight, AppColors.medBlueDark, null),
      AppButtonVariant.ghost => (Colors.transparent, AppColors.textSecondary, AppColors.gray200),
      AppButtonVariant.danger => (AppColors.redLight, AppColors.red, null),
    };

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        if (!loading)
          Text(label, style: AppText.button.copyWith(color: fg)),
      ],
    );

    final button = Material(
      color: bg,
      borderRadius: AppRadii.rFull,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: AppRadii.rFull,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadii.rFull,
            border: border != null ? Border.all(color: border, width: 1.5) : null,
          ),
          constraints: const BoxConstraints(minHeight: 44),
          child: child,
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

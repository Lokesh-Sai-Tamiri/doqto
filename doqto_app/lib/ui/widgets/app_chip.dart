import 'package:flutter/material.dart';

import '../../core/tokens/colors.dart';
import '../../core/tokens/motion.dart';
import '../../core/tokens/radii.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import 'app_pressable.dart';

/// Shared chip: selectable filter chip / deletable input chip / static tag.
///
/// Consolidation target for the four private one-offs (skills_input._SkillChip,
/// create_group inline chips, profile._SkillTag, chat_thread._DateChip) —
/// those retrofits are deferred debt, not done in M0.
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? avatar;

  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onDelete,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.medBlueDark : AppColors.gray600;
    final chip = AnimatedContainer(
      duration: AppMotion.maybe(context, AppMotion.micro),
      curve: AppMotion.standard,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.medBlueLight : AppColors.gray100,
        borderRadius: AppRadii.rFull,
        border: Border.all(
          color: selected ? AppColors.medBlueMid : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatar != null) ...[
            avatar!,
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: AppText.badge.copyWith(color: fg, fontSize: 12)),
          if (onDelete != null) ...[
            const SizedBox(width: AppSpacing.xs),
            AppPressable(
              onTap: onDelete,
              child: Icon(Icons.close_rounded, size: 14, color: fg),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return chip;
    return AppPressable(onTap: onTap, child: chip);
  }
}

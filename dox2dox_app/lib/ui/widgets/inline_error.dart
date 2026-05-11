import 'package:flutter/material.dart';

import '../../core/tokens/colors.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';

/// Reusable inline error row: warning icon + physician-friendly message in red.
/// Returns `SizedBox.shrink()` when [message] is null/empty so callers can
/// render it unconditionally.
class InlineError extends StatelessWidget {
  final String? message;
  const InlineError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.red),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Text(
              text,
              style: AppText.caption.copyWith(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import 'app_pill.dart';
import 'doctor_avatar.dart';
import 'mutuals_line.dart';
import 'primary_button.dart';
import 'section_card.dart';

/// A received message request (M4): avatar + name/headline + optional degree
/// badge and mutuals line + a 2-line message preview + an action row
/// [Delete · Block · Accept]. Composed on [SectionCard]; the parent owns the
/// (optimistic) callbacks. Tapping the card body opens the thread.
class RequestCard extends StatelessWidget {
  final String name;
  final String initials;
  final int avatarColorIndex;
  final String? avatarUrl;
  final String? headline;

  /// Decrypt-on-read is impossible for network content, so the preview is
  /// whatever the list endpoint surfaced (may be empty). Rendered ≤ 2 lines.
  final String? messagePreview;

  /// Degree badge label ("1st"/"2nd") when known — omitted otherwise.
  final String? degreeLabel;

  /// Mutuals line — rendered only when [mutualCount] > 0 or [contextLabel] set.
  final int mutualCount;
  final String? contextLabel;

  /// Hero tag for the avatar (shared-element to the sender's profile).
  final Object? heroTag;

  final VoidCallback onAccept;
  final VoidCallback onDelete;
  final VoidCallback onBlock;
  final VoidCallback? onTap;

  const RequestCard({
    super.key,
    required this.name,
    required this.initials,
    this.avatarColorIndex = 0,
    this.avatarUrl,
    this.headline,
    this.messagePreview,
    this.degreeLabel,
    this.mutualCount = 0,
    this.contextLabel,
    this.heroTag,
    required this.onAccept,
    required this.onDelete,
    required this.onBlock,
    this.onTap,
  });

  static bool _notEmpty(String? s) => s != null && s.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoctorAvatar(
                initials: initials,
                colorIndex: avatarColorIndex,
                imageUrl: avatarUrl,
                size: AvatarSize.lg,
                heroTag: heroTag,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: AppText.subheading,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_notEmpty(degreeLabel)) ...[
                          const SizedBox(width: AppSpacing.sm),
                          DegreeBadge(degreeLabel!),
                        ],
                      ],
                    ),
                    if (_notEmpty(headline)) ...[
                      const SizedBox(height: 2),
                      Text(
                        headline!,
                        style: AppText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (mutualCount > 0 || _notEmpty(contextLabel)) ...[
                      const SizedBox(height: AppSpacing.xs),
                      MutualsLine(
                        mutualCount: mutualCount,
                        contextLabel: contextLabel,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_notEmpty(messagePreview)) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              messagePreview!,
              style: AppText.bodyPrimary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppButton(
                label: Strings.netDelete,
                variant: AppButtonVariant.ghost,
                onPressed: onDelete,
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                label: Strings.netBlock,
                variant: AppButtonVariant.ghost,
                onPressed: onBlock,
              ),
              const Spacer(),
              AppButton(
                label: Strings.netAccept,
                onPressed: onAccept,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

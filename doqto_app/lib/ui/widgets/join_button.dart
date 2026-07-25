import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';
import '../../core/enums/app_enums.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../data/models/group.dart';
import 'primary_button.dart';

/// The group join state machine as a pure widget — its rendered control is a
/// deterministic function of ([joinPolicy], [membershipTag]) so the per-policy
/// matrix is unit-testable without Riverpod:
///
///   member                       → "Open chat"
///   requested                    → "Requested" (tap → withdraw)
///   none/invited + open          → "Join"
///   none/invited + request       → "Request to join"
///   none/invited + invite_only   → no button + caption
class JoinButton extends StatelessWidget {
  final GroupJoinPolicy? joinPolicy;
  final GroupMembershipTag membershipTag;
  final bool busy;
  final bool expand;

  final Future<void> Function()? onJoin;
  final Future<void> Function()? onRequest;
  final Future<void> Function()? onWithdraw;
  final VoidCallback? onOpenChat;

  const JoinButton({
    super.key,
    required this.joinPolicy,
    required this.membershipTag,
    this.busy = false,
    this.expand = false,
    this.onJoin,
    this.onRequest,
    this.onWithdraw,
    this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    if (membershipTag == GroupMembershipTag.member) {
      return AppButton(
        label: Strings.groupsOpenChat,
        icon: Icons.chat_bubble_outline,
        variant: AppButtonVariant.secondary,
        expand: expand,
        onPressed: onOpenChat,
      );
    }

    if (membershipTag == GroupMembershipTag.requested) {
      return AppButton(
        label: Strings.groupRequested,
        icon: Icons.schedule,
        variant: AppButtonVariant.secondary,
        loading: busy,
        expand: expand,
        onPressed: onWithdraw == null ? null : () => onWithdraw!(),
      );
    }

    switch (joinPolicy) {
      case GroupJoinPolicy.open:
        return AppButton(
          label: Strings.groupJoin,
          icon: Icons.group_add_outlined,
          expand: expand,
          loading: busy,
          onPressed: onJoin == null ? null : () => onJoin!(),
        );
      case GroupJoinPolicy.request:
        return AppButton(
          label: Strings.groupRequestToJoin,
          icon: Icons.how_to_reg_outlined,
          expand: expand,
          loading: busy,
          onPressed: onRequest == null ? null : () => onRequest!(),
        );
      case GroupJoinPolicy.inviteOnly:
      case GroupJoinPolicy.unknown:
      case null:
        // No join affordance — invite only (or redacted policy).
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  Strings.groupsInviteOnlyCaption,
                  style: AppText.caption,
                ),
              ),
            ],
          ),
        );
    }
  }
}

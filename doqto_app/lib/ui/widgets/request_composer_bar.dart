import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';
import '../../core/tokens/colors.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import 'connect_button.dart';
import 'inline_banner.dart';
import 'primary_button.dart';

/// The request-tier region above the message composer (M4). Given the tier
/// computed from the conversations/requests LIST (never a detail fetch), it
/// renders the right banners and either the passed-in [composer] or a locked
/// bar:
///   - recipient pending → info banner + [Accept · Delete · Block] + composer
///   - initiator, before first message → one-message hint banner + composer
///   - initiator, message spent / declined → locked bar (composer hidden)
///   - open but not connected (network DM) → dismissible Connect banner + composer
class RequestComposerBar extends StatelessWidget {
  /// True when I received this pending request (I may Accept/Delete/Block and
  /// my reply auto-accepts).
  final bool isRecipientPending;

  /// True when I'm the initiator and haven't spent my one message yet.
  final bool isInitiatorBeforeFirst;

  /// True when the composer must be replaced by a locked bar (request declined,
  /// or my one initiator message is already spent).
  final bool composerLocked;

  /// Distinguishes the two locked copy lines.
  final bool isDeclined;

  /// Show the dismissible "not connected" Connect banner (open network DM).
  final bool showNotConnected;

  final String? otherId;
  final String otherName;
  final bool busy;

  final VoidCallback onAccept;
  final VoidCallback onDelete;
  final ValueChanged<String> onBlock;
  final VoidCallback onDismissNotConnected;

  /// The live composer (text field or recorder) supplied by the screen. Ignored
  /// when [composerLocked].
  final Widget composer;

  const RequestComposerBar({
    super.key,
    required this.isRecipientPending,
    required this.isInitiatorBeforeFirst,
    required this.composerLocked,
    required this.isDeclined,
    required this.showNotConnected,
    required this.otherId,
    required this.otherName,
    required this.busy,
    required this.onAccept,
    required this.onDelete,
    required this.onBlock,
    required this.onDismissNotConnected,
    required this.composer,
  });

  static const Color _infoBg = AppColors.medBlueLight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isRecipientPending) _recipientActionBar(),
        if (isInitiatorBeforeFirst)
          const InlineBanner(
            tone: BannerTone.info,
            icon: Icons.info_outline,
            text: Strings.netRequestFirstHint,
          ),
        if (showNotConnected && otherId != null)
          _notConnectedBanner(otherId!),
        if (composerLocked)
          _lockedBar(isDeclined
              ? Strings.netRequestDeclinedTerminal
              : Strings.netRequestWaiting)
        else
          composer,
      ],
    );
  }

  Widget _recipientActionBar() {
    return Container(
      color: _infoBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const InlineBanner(
            tone: BannerTone.info,
            icon: Icons.mail_outline_rounded,
            text: Strings.netRequestBannerRecipient,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                AppButton(
                  label: Strings.netAccept,
                  onPressed: busy ? null : onAccept,
                ),
                const SizedBox(width: AppSpacing.xs),
                AppButton(
                  label: Strings.netDelete,
                  variant: AppButtonVariant.ghost,
                  onPressed: busy ? null : onDelete,
                ),
                const Spacer(),
                if (otherId != null)
                  AppButton(
                    label: Strings.netBlock,
                    variant: AppButtonVariant.ghost,
                    onPressed: busy ? null : () => onBlock(otherId!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notConnectedBanner(String otherId) {
    final fg = InlineBanner.foregroundFor(BannerTone.info);
    return Container(
      color: _infoBg,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.person_add_alt_1, size: 16, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              Strings.netNotConnectedWith(otherName),
              style: AppText.caption.copyWith(color: fg),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ConnectButton(userId: otherId),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: Strings.cancel,
            icon: Icon(Icons.close, size: 18, color: fg),
            onPressed: onDismissNotConnected,
          ),
        ],
      ),
    );
  }

  Widget _lockedBar(String text) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 18, color: AppColors.gray600),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: AppText.caption.copyWith(color: AppColors.gray600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

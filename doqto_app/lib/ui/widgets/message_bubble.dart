import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/tokens/colors.dart';
import '../../core/tokens/radii.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';

/// Centered pill for in-chat system banners (e.g. disappearing-messages
/// changes). No timestamp, no read ticks.
class SystemMessageBubble extends StatelessWidget {
  final String text;
  const SystemMessageBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Center(
        child: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: AppRadii.rFull,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppText.timestamp.copyWith(color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final DateTime timestamp;
  final String? senderName;
  final int senderColorIndex;
  final bool read;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMine,
    required this.timestamp,
    this.senderName,
    this.senderColorIndex = 0,
    this.read = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = isMine ? AppRadii.bubbleSent : AppRadii.bubbleReceived;
    final bg = isMine ? AppColors.medBlue : AppColors.white;
    final fg = isMine ? AppColors.white : AppColors.textPrimary;
    final timeColor = isMine ? AppColors.white.withValues(alpha: 0.55) : AppColors.textMuted;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: isMine ? null : Border.all(color: AppColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (senderName != null && !isMine)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                senderName!,
                style: AppText.timestamp.copyWith(
                  color: AppColors.avatarColorFor(senderColorIndex),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(text, style: AppText.messageBody.copyWith(color: fg)),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.Hm().format(timestamp),
                  style: AppText.timestamp.copyWith(color: timeColor),
                ),
                if (isMine) ...[
                  const SizedBox(width: 3),
                  Icon(
                    read ? Icons.done_all : Icons.check,
                    size: 15,
                    color: read ? const Color(0xFF7FC8FF) : AppColors.white.withValues(alpha: 0.55),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [bubble],
      ),
    );
  }
}

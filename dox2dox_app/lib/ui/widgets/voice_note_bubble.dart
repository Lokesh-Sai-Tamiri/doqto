import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/tokens/colors.dart';
import '../../core/tokens/radii.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';

class VoiceNoteBubble extends StatelessWidget {
  final int durationSec;
  final String? transcript;
  final bool isMine;
  final VoidCallback? onPlay;

  const VoiceNoteBubble({
    super.key,
    required this.durationSec,
    required this.transcript,
    required this.isMine,
    this.onPlay,
  });

  String _format(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final radius = isMine ? AppRadii.bubbleSent : AppRadii.bubbleReceived;
    final bg = isMine ? AppColors.medBlue : AppColors.white;
    final contrast = isMine ? AppColors.white : AppColors.medBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: isMine ? null : Border.all(color: AppColors.gray100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: onPlay,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: contrast.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.play_arrow_rounded, color: contrast, size: 20),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _Waveform(color: contrast.withValues(alpha: 0.7))),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _format(durationSec),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: contrast.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (transcript != null && transcript!.isNotEmpty) ...[
                Container(height: 1, color: contrast.withValues(alpha: 0.15)),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    transcript!,
                    style: AppText.timestamp.copyWith(
                      fontStyle: FontStyle.italic,
                      color: contrast.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  final Color color;
  const _Waveform({required this.color});

  @override
  Widget build(BuildContext context) {
    const heights = [6.0, 10.0, 14.0, 18.0, 12.0, 8.0, 14.0, 10.0, 6.0, 12.0, 16.0, 10.0];
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          for (final h in heights) ...[
            Container(width: 3, height: h, color: color),
            const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}

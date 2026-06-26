import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/tokens/colors.dart';
import '../../core/tokens/radii.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';

class VoiceNoteBubble extends StatefulWidget {
  final int durationSec;
  final String? transcript;
  final bool isMine;
  final String? audioUrl;
  final Future<String> Function()? getAudioUrl;

  const VoiceNoteBubble({
    super.key,
    required this.durationSec,
    required this.transcript,
    required this.isMine,
    this.audioUrl,
    this.getAudioUrl,
  });

  @override
  State<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<VoiceNoteBubble> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  String? _resolvedUrl;

  Future<void> _togglePlay() async {
    _player ??= AudioPlayer();
    final player = _player!;

    if (_isPlaying) {
      await player.pause();
      setState(() => _isPlaying = false);
      return;
    }

    if (player.processingState == ProcessingState.idle ||
        player.processingState == ProcessingState.completed) {
      setState(() => _isLoading = true);
      try {
        _resolvedUrl ??= widget.audioUrl;
        if (_resolvedUrl == null && widget.getAudioUrl != null) {
          _resolvedUrl = await widget.getAudioUrl!();
        }
        if (_resolvedUrl == null || _resolvedUrl!.isEmpty) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        await player.setUrl(_resolvedUrl!);
      } catch (e) {
        debugPrint('[VoiceNoteBubble] setUrl failed: $e | url: $_resolvedUrl');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
    }

    player.play();
    setState(() => _isPlaying = true);

    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  String _format(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.isMine ? AppRadii.bubbleSent : AppRadii.bubbleReceived;
    final bg = widget.isMine ? AppColors.medBlue : AppColors.white;
    final contrast = widget.isMine ? AppColors.white : AppColors.medBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Align(
        alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: widget.isMine ? null : Border.all(color: AppColors.gray100),
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
                      onTap: _isLoading ? null : _togglePlay,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: contrast.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: _isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(contrast),
                                ),
                              )
                            : Icon(
                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: contrast,
                                size: 22,
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _Waveform(color: contrast.withValues(alpha: 0.7))),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _format(widget.durationSec),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: contrast.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.transcript != null && widget.transcript!.isNotEmpty) ...[
                Container(height: 1, color: contrast.withValues(alpha: 0.15)),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    widget.transcript!,
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

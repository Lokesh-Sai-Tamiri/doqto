import 'package:flutter/material.dart';

import '../../core/tokens/colors.dart';

/// Bare three-dot bouncing animation. Reused in the chat thread (in a bubble)
/// and inline in the chat list row.
class TypingDots extends StatefulWidget {
  final Color color;
  final double size;
  const TypingDots({super.key, this.color = const Color(0xFF8A94A6), this.size = 7});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_c.value + i * 0.2) % 1.0;
          final dy = -(widget.size * 0.55) * (t < 0.5 ? t * 2 : 2 - t * 2);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.size * 0.35),
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// WhatsApp-style three-dot "typing…" bubble shown in the chat thread.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, top: 2, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray100),
        ),
        child: const TypingDots(),
      ),
    );
  }
}

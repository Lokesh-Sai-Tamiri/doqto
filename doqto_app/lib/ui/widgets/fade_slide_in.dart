import 'package:flutter/material.dart';

import '../../core/tokens/motion.dart';

/// One-shot entrance: fades in + slides up 12px on first build.
///
/// Use [FadeSlideIn.staggered] for list entrances — delay is
/// `index * AppMotion.staggerInterval`, capped at [AppMotion.staggerCap]
/// items (later items enter without extra delay).
///
/// Plays once per widget lifecycle. Reduced-motion aware (renders
/// instantly when animations are disabled).
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool enabled;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.enabled = true,
  });

  /// Staggered list-entrance helper: delay = index * staggerInterval,
  /// clamped at staggerCap items.
  static Widget staggered(int index, Widget child, {bool enabled = true}) {
    final clamped = index.clamp(0, AppMotion.staggerCap);
    return FadeSlideIn(
      delay: AppMotion.staggerInterval * clamped,
      enabled: enabled,
      child: child,
    );
  }

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.enter,
  );
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: AppMotion.curveEnter);
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, 12),
    end: Offset.zero,
  ).animate(_opacity);

  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _controller.value = 1.0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.enabled) return;
    if (AppMotion.reduced(context)) {
      _controller.value = 1.0;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(offset: _offset.value, child: child),
      ),
      child: widget.child,
    );
  }
}

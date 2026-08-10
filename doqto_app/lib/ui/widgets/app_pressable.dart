import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tokens/motion.dart';

/// Universal press-feedback wrapper: scales to 0.97 + dims slightly while
/// pressed. Use on every tappable surface for a consistent premium feel.
///
/// - Never shifts layout (scale/opacity only).
/// - `enabled: false` → 0.4 opacity, no gestures.
/// - `haptic: true` → HapticFeedback.lightImpact on tap-down (primary actions).
/// - `minTarget: true` → enforces a 44x44 minimum tap target.
/// - Respects reduced motion.
class AppPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool haptic;
  final bool minTarget;

  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.haptic = false,
    this.minTarget = false,
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.maybe(context, AppMotion.micro);

    Widget child = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: duration,
      curve: AppMotion.standard,
      child: AnimatedOpacity(
        opacity: !widget.enabled
            ? 0.4
            : _pressed
                ? 0.85
                : 1.0,
        duration: duration,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );

    if (widget.minTarget) {
      child = ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: child,
      );
    }

    if (!_interactive) return child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) {
        if (widget.haptic) HapticFeedback.lightImpact();
        _setPressed(true);
      },
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: child,
    );
  }
}

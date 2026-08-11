import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/motion.dart';
import '../../../core/tokens/spacing.dart';
import '../../../state/auth_state.dart';

/// Splash-only motion values — a hero moment, deliberately slower than the
/// app-wide tokens. Everything collapses to static under reduced motion.
class _SplashMotion {
  static const Duration entrance = Duration(milliseconds: 1100);
  static const Duration loop = Duration(milliseconds: 2600);

  /// Minimum time the splash stays visible so the entrance can play.
  static const Duration minHold = Duration(milliseconds: 1600);
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // One-shot staged entrance: logo pops, then wordmark, then tagline.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _SplashMotion.entrance,
  );

  // Continuous ambience: expanding pulse rings + gentle logo breathing.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: _SplashMotion.loop,
  );

  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _logoScale = Tween<double>(begin: 0.6, end: 1.0)
      .animate(CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ));
  late final Animation<double> _wordmark = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.35, 0.70, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _tagline = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.55, 0.90, curve: Curves.easeOutCubic),
  );

  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (AppMotion.reduced(context)) {
      _entrance.value = 1.0; // static, no loop
    } else {
      _entrance.forward();
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final hold = AppMotion.reduced(context)
        ? Duration.zero
        : _SplashMotion.minHold;
    await Future.wait([
      ref.read(authProvider.notifier).bootstrap(),
      Future<void>.delayed(hold),
    ]);
    if (!mounted) return;
    final stage = ref.read(authProvider).stage;
    context.go(switch (stage) {
      AuthStage.signedIn => AppRoutes.chats,
      AuthStage.pendingVerification => AppRoutes.pending,
      AuthStage.needsOrg => AppRoutes.orgSelection,
      AuthStage.needsRegistration => AppRoutes.registration,
      _ => AppRoutes.phone,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // teal gradient needs light icons
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.medBlue, AppColors.medBlueDark],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Pulse rings radiating from the logo.
              AnimatedBuilder(
                animation: _loop,
                builder: (_, _) => CustomPaint(
                  painter: _PulseRingsPainter(
                    progress: _loop.value,
                    // Rings only once the logo has landed.
                    opacity: _logoFade.value,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildRise(
                      _wordmark,
                      Text(
                        Strings.appName,
                        style: GoogleFonts.sora(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildRise(
                      _tagline,
                      Text(
                        Strings.tagline,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          letterSpacing: 0.2,
                          color: AppColors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_entrance, _loop]),
      builder: (_, _) {
        // Gentle breathing once the entrance has landed.
        final breath =
            1 + 0.02 * math.sin(_loop.value * 2 * math.pi) * _entrance.value;
        return Opacity(
          opacity: _logoFade.value,
          child: Transform.scale(
            scale: _logoScale.value * breath,
            child: Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.18),
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Image.asset('assets/splash_logo_white.png'),
            ),
          ),
        );
      },
    );
  }

  /// Fade + rise entrance driven by [t].
  Widget _buildRise(Animation<double> t, Widget child) {
    return AnimatedBuilder(
      animation: t,
      builder: (_, _) => Opacity(
        opacity: t.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Three staggered rings expanding and fading out from screen center.
class _PulseRingsPainter extends CustomPainter {
  _PulseRingsPainter({required this.progress, required this.opacity});

  final double progress;
  final double opacity;

  static const _rings = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity == 0) return;
    final center = Offset(size.width / 2, size.height / 2 - 60);
    final maxRadius = size.shortestSide * 0.75;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < _rings; i++) {
      final t = (progress + i / _rings) % 1.0;
      paint.color = AppColors.white
          .withValues(alpha: 0.14 * (1 - t) * (1 - t) * opacity);
      canvas.drawCircle(center, 90 + t * maxRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulseRingsPainter old) =>
      old.progress != progress || old.opacity != opacity;
}

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

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  // One-shot logo entrance: scale + fade, emphasized (360ms).
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppMotion.emphasizedDuration,
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _entrance, curve: AppMotion.emphasized);
  late final Animation<double> _scale =
      Tween<double>(begin: 0.88, end: 1.0).animate(_fade);
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
      _entrance.value = 1.0;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await ref.read(authProvider.notifier).bootstrap();
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
      value: SystemUiOverlayStyle.light, // teal bg needs light status icons
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Image.asset('logo.png', width: 96, height: 96),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  Strings.appName,
                  style: GoogleFonts.sora(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  Strings.tagline,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/spacing.dart';
import '../../../state/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
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
    return Scaffold(
      backgroundColor: AppColors.medBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_hospital_rounded, size: 80, color: AppColors.white),
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
    );
  }
}

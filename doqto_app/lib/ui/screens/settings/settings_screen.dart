import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/tokens/spacing.dart';
import '../../../state/auth_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/primary_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          FadeSlideIn.staggered(
            0,
            ListTile(
                title: const Text('Name'),
                subtitle: Text(user?.fullName ?? '—')),
          ),
          FadeSlideIn.staggered(
            1,
            ListTile(
                title: const Text('Phone'), subtitle: Text(user?.phone ?? '—')),
          ),
          FadeSlideIn.staggered(
            2,
            ListTile(
                title: const Text('NPI'),
                subtitle: Text(user?.npiNumber ?? '—')),
          ),
          FadeSlideIn.staggered(
            3,
            ListTile(
                title: const Text('Specialty'),
                subtitle: Text(user?.specialty ?? '—')),
          ),
          // Destructive zone: visually separated from the info rows above,
          // rendered in red via the danger variant.
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          FadeSlideIn.staggered(
            4,
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppButton(
                label: 'Sign out',
                icon: Icons.logout,
                variant: AppButtonVariant.danger,
                expand: true,
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go(AppRoutes.phone);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../state/auth_state.dart';
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
          ListTile(title: const Text('Name'), subtitle: Text(user?.fullName ?? '—')),
          ListTile(title: const Text('Phone'), subtitle: Text(user?.phone ?? '—')),
          ListTile(title: const Text('NPI'), subtitle: Text(user?.npiNumber ?? '—')),
          ListTile(title: const Text('Specialty'), subtitle: Text(user?.specialty ?? '—')),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppButton(
              label: 'Sign out',
              variant: AppButtonVariant.danger,
              expand: true,
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) context.go(AppRoutes.phone);
              },
            ),
          ),
        ],
      ),
    );
  }
}

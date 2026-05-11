import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/validators.dart';
import '../../../data/api/api_client.dart';
import '../../../state/auth_state.dart';
import '../../../state/org_state.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/inline_error.dart';
import '../../widgets/primary_button.dart';

class CreateOrgScreen extends ConsumerStatefulWidget {
  const CreateOrgScreen({super.key});

  @override
  ConsumerState<CreateOrgScreen> createState() => _CreateOrgScreenState();
}

class _CreateOrgScreenState extends ConsumerState<CreateOrgScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _nameKey = GlobalKey<AppTextFieldState>();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!(_nameKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(orgProvider.notifier).createOrg(
            name: _name.text.trim(),
            city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          );
      // Recompute AuthStage from server truth. A newly-created org is
      // always `pending`, so the router sends us to /org/pending. If admin
      // auto-approved (dev only), it goes to /chats instead.
      await ref.read(authProvider.notifier).refreshOrgStatus();
      if (!mounted) return;
      final stage = ref.read(authProvider).stage;
      context.go(switch (stage) {
        AuthStage.signedIn => AppRoutes.chats,
        AuthStage.pendingVerification => AppRoutes.pending,
        _ => AppRoutes.orgSelection,
      });
    } catch (e) {
      if (!mounted) return;
      final msg = ErrorMessages.forApi(e);
      // Network / connectivity errors: show as snackbar since they're not
      // tied to any specific field.
      final isNetwork = e is ApiException && e.status == null;
      if (isNetwork) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.red,
          ),
        );
      } else {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Organization')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              key: _nameKey,
              controller: _name,
              label: 'Organization name',
              validator: Validators.orgName(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _city,
              label: 'City',
              helperText: 'Optional',
            ),
            InlineError(_error),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Create',
              onPressed: _submit,
              loading: _loading,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

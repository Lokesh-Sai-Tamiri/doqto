import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/validators.dart';
import '../../../state/auth_state.dart';
import '../../../state/org_state.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/inline_error.dart';
import '../../widgets/primary_button.dart';

class JoinOrgScreen extends ConsumerStatefulWidget {
  const JoinOrgScreen({super.key});

  @override
  ConsumerState<JoinOrgScreen> createState() => _JoinOrgScreenState();
}

class _JoinOrgScreenState extends ConsumerState<JoinOrgScreen> {
  final _code = TextEditingController();
  final _codeKey = GlobalKey<AppTextFieldState>();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!(_codeKey.currentState?.validate() ?? false)) return;
    final code = _code.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(orgProvider.notifier).joinOrg(code);
      // Re-evaluate the auth stage against the real org status returned by the
      // server. `refreshOrgStatus()` flips AuthStage to signedIn / pending /
      // suspended; the router redirect picks up the change and navigates us
      // to /chats or /org/pending automatically. Do NOT hardcode a route here
      // — that caused the "joined successfully but stuck on get-started" bug.
      await ref.read(authProvider.notifier).refreshOrgStatus();
      if (!mounted) return;
      final stage = ref.read(authProvider).stage;
      context.go(switch (stage) {
        AuthStage.signedIn => AppRoutes.chats,
        AuthStage.pendingVerification => AppRoutes.pending,
        _ => AppRoutes.orgSelection,
      });
    } catch (e) {
      setState(() => _error = ErrorMessages.forApi(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Organization')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              key: _codeKey,
              controller: _code,
              label: 'Invite code',
              hint: 'APOL·4827',
              style: AppText.inviteCode,
              validator: Validators.inviteCode(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            InlineError(_error),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Join',
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

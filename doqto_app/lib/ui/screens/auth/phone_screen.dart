import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../core/utils/error_messages.dart';
import '../../../state/auth_state.dart';
import '../../widgets/inline_error.dart';
import '../../widgets/phone_field.dart';
import '../../widgets/primary_button.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phoneKey = GlobalKey<PhoneFieldState>();
  String _e164 = '';
  bool _loading = false;
  String? _submitError;

  Future<void> _submit() async {
    if (!(_phoneKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _submitError = null;
    });
    try {
      await ref.read(authProvider.notifier).requestOtp(_e164);
      if (!mounted) return;
      context.push(AppRoutes.otp, extra: _e164);
    } catch (e) {
      setState(() => _submitError = ErrorMessages.forApi(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Strings.appName)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Center(child: Image.asset('logo.png', width: 72, height: 72)),
            const SizedBox(height: AppSpacing.lg),
            Text(Strings.authPhoneTitle, style: AppText.display),
            const SizedBox(height: AppSpacing.lg),
            PhoneField(
              key: _phoneKey,
              autofocus: true,
              helperText: 'Tap the flag to change country',
              onChanged: (full) {
                _e164 = full;
                if (_submitError != null) setState(() => _submitError = null);
              },
            ),
            InlineError(_submitError),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: Strings.authSendOtp,
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/validators.dart';
import '../../../state/auth_state.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/inline_error.dart';
import '../../widgets/primary_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  final _otpKey = GlobalKey<AppTextFieldState>();
  bool _loading = false;
  bool _resending = false;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownRemaining = AppConstants.otpResendCooldown.inSeconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _cooldownRemaining--;
        if (_cooldownRemaining <= 0) t.cancel();
      });
    });
  }

  Future<void> _verify() async {
    if (!(_otpKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .verifyOtp(phone: widget.phone, code: _controller.text);
      if (!mounted) return;
      final stage = ref.read(authProvider).stage;
      // After OTP verify, route by what AuthStage actually resolved to. A
      // fully-registered user with an active org goes to chats; otherwise
      // registration / org selection / pending screen.
      context.go(switch (stage) {
        AuthStage.signedIn => AppRoutes.chats,
        AuthStage.pendingVerification => AppRoutes.pending,
        AuthStage.needsOrg => AppRoutes.orgSelection,
        AuthStage.needsRegistration => AppRoutes.registration,
        _ => AppRoutes.phone,
      });
    } catch (e) {
      setState(() => _error = ErrorMessages.forApi(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldownRemaining > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).requestOtp(widget.phone);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New code sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ErrorMessages.forApi(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Text(Strings.authOtpTitle, style: AppText.display),
            const SizedBox(height: AppSpacing.xs),
            Text('Sent to ${widget.phone}', style: AppText.caption),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              key: _otpKey,
              controller: _controller,
              hint: Strings.authOtpHint,
              keyboardType: TextInputType.number,
              maxLength: AppConstants.otpLength,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: Validators.otp(AppConstants.otpLength),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            InlineError(_error),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed:
                    (_cooldownRemaining == 0 && !_resending) ? _resend : null,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.medBlue,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: _resending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _cooldownRemaining > 0
                            ? 'Resend code in ${_cooldownRemaining}s'
                            : Strings.authResend,
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: Strings.authVerify,
              onPressed: _verify,
              loading: _loading,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

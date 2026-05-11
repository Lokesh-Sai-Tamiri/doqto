import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/validators.dart';
import '../../../state/auth_state.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/inline_error.dart';
import '../../widgets/primary_button.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _name = TextEditingController();
  final _specialty = TextEditingController();
  final _npi = TextEditingController();

  final _nameKey = GlobalKey<AppTextFieldState>();
  final _npiKey = GlobalKey<AppTextFieldState>();

  bool _loading = false;
  String? _submitError;

  Future<void> _submit() async {
    // Validate every required field. Running all validators (not short-circuiting)
    // lets the user see every issue at once.
    final nameOk = _nameKey.currentState?.validate() ?? false;
    final npiOk = _npiKey.currentState?.validate() ?? false;
    if (!nameOk || !npiOk) return;

    setState(() {
      _loading = true;
      _submitError = null;
    });
    try {
      await ref.read(authProvider.notifier).completeRegistration(
            fullName: _name.text.trim(),
            specialty: _specialty.text.trim().isEmpty ? null : _specialty.text.trim(),
            npiNumber: _npi.text.trim(),
          );
      if (!mounted) return;
      context.go(AppRoutes.orgSelection);
    } catch (e) {
      setState(() => _submitError = ErrorMessages.forApi(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              key: _nameKey,
              controller: _name,
              label: Strings.regFullName,
              validator: Validators.fullName(),
              onChanged: (_) {
                if (_submitError != null) setState(() => _submitError = null);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _specialty,
              label: Strings.regSpecialty,
              helperText: 'Optional — e.g. Cardiology, Pediatrics',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              key: _npiKey,
              controller: _npi,
              label: Strings.regNpi,
              keyboardType: TextInputType.number,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              helperText: Strings.regNpiHelper,
              validator: Validators.npi(),
              onChanged: (_) {
                if (_submitError != null) setState(() => _submitError = null);
              },
            ),
            InlineError(_submitError),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: Strings.regContinue,
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

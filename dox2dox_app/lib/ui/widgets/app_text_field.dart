import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tokens/colors.dart';
import '../../core/tokens/radii.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../core/utils/validators.dart';

/// Global reusable input field.
///
/// Features:
///  * Label above, helper text below.
///  * Inline error text below (red, icon-prefixed) — shown when [errorText]
///    is non-null OR when an auto-validator runs and returns an error.
///  * Auto-validate via the [validator] param. Runs on blur, and on every
///    change after the first blur (classic form UX: don't nag while typing
///    the first time, but show live feedback once the user has committed).
///  * Parents can imperatively validate via a [GlobalKey<AppTextFieldState>]
///    and call `state.validate()` before submit — returns true if valid.
///
/// Never re-implement a text field in screens — use this.
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool obscure;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;
  final TextStyle? style;
  final bool autofocus;

  /// Optional validator — if provided, [AppTextField] renders its error in red.
  final Validator? validator;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.obscure = false,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.style,
    this.autofocus = false,
    this.validator,
  });

  @override
  State<AppTextField> createState() => AppTextFieldState();
}

class AppTextFieldState extends State<AppTextField> {
  final _focus = FocusNode();
  String? _internalError;
  bool _hasBlurred = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      _hasBlurred = true;
      _runValidator(widget.controller?.text ?? '');
    }
  }

  bool _runValidator(String value) {
    if (widget.validator == null) return true;
    final error = widget.validator!(value);
    if (error != _internalError) {
      setState(() => _internalError = error);
    }
    return error == null;
  }

  /// Call from the parent before submit. Marks the field as "blurred" so the
  /// error sticks, runs the validator, and returns true if the value is valid.
  bool validate() {
    _hasBlurred = true;
    return _runValidator(widget.controller?.text ?? '');
  }

  void _onChanged(String value) {
    widget.onChanged?.call(value);
    if (_hasBlurred) _runValidator(value);
  }

  @override
  Widget build(BuildContext context) {
    // Explicit errorText from parent wins over internal validator output.
    final errorToShow = widget.errorText ?? _internalError;
    final hasError = errorToShow != null && errorToShow.isNotEmpty;

    final errorBorder = OutlineInputBorder(
      borderRadius: AppRadii.rMd,
      borderSide: const BorderSide(color: AppColors.red, width: 1.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: AppText.subheading),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscure,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          onChanged: _onChanged,
          autofocus: widget.autofocus,
          style: widget.style ?? AppText.bodyPrimary,
          decoration: InputDecoration(
            hintText: widget.hint,
            counterText: '',
            enabledBorder: hasError ? errorBorder : null,
            focusedBorder: hasError ? errorBorder : null,
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 14, color: AppColors.red),
                const SizedBox(width: AppSpacing.xs + 2),
                Expanded(
                  child: Text(
                    errorToShow,
                    style: AppText.caption.copyWith(color: AppColors.red),
                  ),
                ),
              ],
            ),
          )
        else if (widget.helperText != null && widget.helperText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(widget.helperText!, style: AppText.caption),
          ),
      ],
    );
  }
}

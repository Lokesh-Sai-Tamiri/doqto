import 'package:flutter/material.dart';

import '../../core/constants/specialties.dart';
import '../../core/constants/strings.dart';
import '../../core/tokens/colors.dart';
import '../../core/tokens/radii.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import 'app_text_field.dart';

/// Specialty picker: type to filter [Specialties.all], or choose
/// [Specialties.other] and write in something the list does not cover.
///
/// Picking "Other" leaves that word in the dropdown and opens a second field
/// underneath, carrying across whatever had been typed so far. From then on
/// the second field holds the answer.
///
/// [controller] always holds the value to submit, never the literal word
/// "Other". The NPI registry lookup can write a taxonomy straight into it and
/// the dropdown will show it.
class SpecialtyField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? helperText;

  /// Shown under whichever field currently holds the answer — the dropdown,
  /// or the write-in field in "Other" mode.
  final String? errorText;

  /// Fires with the effective value on every change, typed or picked.
  final ValueChanged<String>? onChanged;

  const SpecialtyField({
    super.key,
    required this.controller,
    required this.label,
    this.helperText,
    this.errorText,
    this.onChanged,
  });

  @override
  State<SpecialtyField> createState() => _SpecialtyFieldState();
}

class _SpecialtyFieldState extends State<SpecialtyField> {
  /// What the dropdown shows. In "Other" mode that is the word Other, which is
  /// why it cannot be the caller's controller.
  late final TextEditingController _picker =
      TextEditingController(text: widget.controller.text);

  /// The write-in answer, shown only in "Other" mode.
  final TextEditingController _custom = TextEditingController();

  final FocusNode _pickerFocus = FocusNode();
  final FocusNode _customFocus = FocusNode();

  bool _other = false;

  /// The last thing actually typed into the dropdown. Read on selecting
  /// "Other" — by then RawAutocomplete has already overwritten the field with
  /// the chosen option, so the query cannot be recovered from the controller.
  String _query = '';

  /// Set while we write to the caller's controller ourselves, so our own
  /// writes don't come back through [_onExternalValue] as if someone else
  /// had made them.
  bool _writingBack = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onExternalValue);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalValue);
    _picker.dispose();
    _custom.dispose();
    _pickerFocus.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  /// Someone outside set the value — the NPI lookup, or a reset. Show it in
  /// the dropdown and drop out of "Other".
  void _onExternalValue() {
    if (_writingBack) return;
    setState(() {
      _other = false;
      _custom.clear();
      _query = '';
      _picker.text = widget.controller.text;
    });
  }

  void _publish(String value) {
    _writingBack = true;
    widget.controller.text = value;
    _writingBack = false;
    widget.onChanged?.call(value);
  }

  void _onSelected(String option) {
    if (option != Specialties.other) {
      setState(() {
        _other = false;
        _custom.clear();
        _query = '';
        _picker.text = option;
      });
      _pickerFocus.unfocus();
      _publish(option);
      return;
    }

    // "Other": keep the word in the dropdown, carry the half-typed query into
    // the write-in field, and put the caret at the end of it.
    final carried = _query.trim();
    setState(() {
      _other = true;
      _picker.text = Specialties.other;
      _custom.text = carried;
    });
    _custom.selection = TextSelection.collapsed(offset: carried.length);
    _publish(carried);
    _customFocus.requestFocus();
  }

  /// Typing in the dropdown means they are picking again, so the write-in
  /// field goes away.
  void _onPickerChanged(String value) {
    _query = value;
    if (_other) {
      setState(() {
        _other = false;
        _custom.clear();
      });
    }
    _publish(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RawAutocomplete<String>(
          textEditingController: _picker,
          focusNode: _pickerFocus,
          // In "Other" mode the field reads "Other", which would otherwise
          // filter the list down to that one entry. Show everything instead,
          // so tapping it is still a way to change your mind.
          optionsBuilder: (value) => Specialties.matching(
            _other && value.text == Specialties.other ? '' : value.text,
          ),
          onSelected: _onSelected,
          fieldViewBuilder: (context, controller, focusNode, _) => AppTextField(
            controller: controller,
            focusNode: focusNode,
            label: widget.label,
            helperText: _other ? null : widget.helperText,
            errorText: _other ? null : widget.errorText,
            onChanged: _onPickerChanged,
            suffix: Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: _OptionsList(options: options, onSelected: onSelected),
          ),
        ),
        if (_other) ...[
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _custom,
            focusNode: _customFocus,
            label: Strings.regSpecialtyOther,
            hint: Strings.regSpecialtyOtherHint,
            errorText: widget.errorText,
            onChanged: _publish,
          ),
        ],
      ],
    );
  }
}

class _OptionsList extends StatelessWidget {
  final Iterable<String> options;
  final ValueChanged<String> onSelected;

  const _OptionsList({required this.options, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final items = options.toList();
    return Material(
      elevation: 4,
      borderRadius: AppRadii.rMd,
      color: AppColors.surface,
      child: ConstrainedBox(
        // 145 specialties would otherwise run off the screen.
        constraints: const BoxConstraints(maxHeight: 260),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, i) {
            final option = items[i];
            final isOther = option == Specialties.other;
            return InkWell(
              onTap: () => onSelected(option),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Text(
                  isOther ? '$option…' : option,
                  style: isOther
                      ? AppText.bodyPrimary.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        )
                      : AppText.bodyPrimary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

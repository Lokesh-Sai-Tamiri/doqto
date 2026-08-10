import 'package:flutter/material.dart';

import '../../core/tokens/colors.dart';
import '../../core/tokens/radii.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';

/// Chip-style tag editor. Mirrors backend limits (≤20 items, ≤40 chars each).
class SkillsInput extends StatefulWidget {
  final List<String> initial;
  final ValueChanged<List<String>> onChanged;
  final int maxItems;
  final int maxLength;

  const SkillsInput({
    super.key,
    required this.initial,
    required this.onChanged,
    this.maxItems = 20,
    this.maxLength = 40,
  });

  @override
  State<SkillsInput> createState() => _SkillsInputState();
}

class _SkillsInputState extends State<SkillsInput> {
  late final List<String> _skills;
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _skills = [...widget.initial];
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    if (_skills.length >= widget.maxItems) return;
    if (_skills.any((s) => s.toLowerCase() == v.toLowerCase())) {
      _controller.clear();
      return;
    }
    setState(() {
      _skills.add(v);
      _controller.clear();
    });
    widget.onChanged(_skills);
    _focus.requestFocus();
  }

  void _remove(int i) {
    setState(() => _skills.removeAt(i));
    widget.onChanged(_skills);
  }

  @override
  Widget build(BuildContext context) {
    final atLimit = _skills.length >= widget.maxItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_skills.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var i = 0; i < _skills.length; i++)
                  _SkillChip(label: _skills[i], onDelete: () => _remove(i)),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: !atLimit,
                maxLength: widget.maxLength,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                style: AppText.bodyPrimary,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: atLimit
                      ? 'You\'ve reached ${widget.maxItems} skills'
                      : 'Add a skill and tap +',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadii.rMd,
                    borderSide: BorderSide(color: AppColors.gray200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadii.rMd,
                    borderSide: BorderSide(color: AppColors.medBlue, width: 1.5),
                  ),
                  border: OutlineInputBorder(borderRadius: AppRadii.rMd),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Material(
              color: atLimit ? AppColors.gray100 : AppColors.medBlue,
              borderRadius: AppRadii.rMd,
              child: InkWell(
                borderRadius: AppRadii.rMd,
                onTap: atLimit ? null : _add,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add,
                    color: atLimit ? AppColors.textMuted : AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;
  final VoidCallback onDelete;

  const _SkillChip({required this.label, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.medBlueLight,
        borderRadius: AppRadii.rFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppText.caption.copyWith(
              color: AppColors.medBlueDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            borderRadius: AppRadii.rFull,
            onTap: onDelete,
            child: Icon(Icons.close, size: 14, color: AppColors.medBlueDark),
          ),
        ],
      ),
    );
  }
}

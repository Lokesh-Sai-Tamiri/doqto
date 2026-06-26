import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/tokens/colors.dart';
import '../../core/tokens/radii.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';

class AppSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hint;
  final Duration debounce;

  const AppSearchBar({
    super.key,
    required this.onChanged,
    this.hint = 'Search…',
    this.debounce = const Duration(milliseconds: 200),
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () {
      widget.onChanged(value.trim());
    });
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    _debounceTimer?.cancel();
    widget.onChanged('');
    _focus.unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onChanged: _onChanged,
        style: AppText.bodyPrimary,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppText.body.copyWith(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.gray50,
          prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
          suffixIcon: hasText
              ? IconButton(
                  icon: Icon(Icons.close, color: AppColors.textMuted, size: 20),
                  onPressed: _clear,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          border: OutlineInputBorder(
            borderRadius: AppRadii.rFull,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadii.rFull,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadii.rFull,
            borderSide: BorderSide(color: AppColors.medBlue, width: 1.5),
          ),
        ),
      ),
    );
  }
}

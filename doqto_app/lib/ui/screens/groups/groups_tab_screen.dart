import 'package:flutter/material.dart';

import '../../../core/constants/strings.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';

/// Placeholder for the Groups branch so the tab renders. Real group content
/// (list, detail, join flows) lands in M5 — this is intentionally minimal.
class GroupsTabScreen extends StatelessWidget {
  const GroupsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(title: const Text(Strings.netTabGroups)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 56, color: AppColors.gray400),
              const SizedBox(height: AppSpacing.lg),
              Text(
                Strings.netGroupsComingTitle,
                style: AppText.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                Strings.netGroupsComingBody,
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

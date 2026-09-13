import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/strings.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/radii.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../state/auth_state.dart';
import '../../widgets/app_pressable.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/primary_button.dart';

/// Plan picker, shown once straight after registration.
///
// ponytail: presentation only — nothing is charged and the choice is not sent
// anywhere. Charging on iOS means StoreKit (Apple rejects card entry for app
// access under 3.1.1), so the provider decision is deliberately deferred; when
// it lands, `_plans` becomes the product list and `_continue` starts the
// purchase.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _Plan {
  final String id;
  final String name;
  final String price;
  final String? note;
  const _Plan(this.id, this.name, this.price, [this.note]);
}

const _plans = [
  _Plan('monthly', Strings.planMonthly, Strings.planMonthlyPrice),
  _Plan('yearly', Strings.planYearly, Strings.planYearlyPrice, Strings.planYearlyNote),
];

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  // Yearly is the better deal, so it starts selected.
  String _selected = 'yearly';
  bool _loading = false;

  Future<void> _leave() async {
    setState(() => _loading = true);
    // No explicit navigation: the router's redirect owns where a resolved auth
    // stage lands. It sends a signed-in user to chats and one whose org is
    // still under review to the pending screen — a hardcoded go(chats) would
    // get the second case wrong.
    await ref.read(authProvider.notifier).completePayment();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.planTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              FadeSlideIn.staggered(
                0,
                Text(Strings.planSubtitle, style: AppText.body),
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final (i, plan) in _plans.indexed) ...[
                FadeSlideIn.staggered(
                  i + 1,
                  _PlanCard(
                    plan: plan,
                    selected: plan.id == _selected,
                    onTap: () => setState(() => _selected = plan.id),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const Spacer(),
              FadeSlideIn.staggered(
                _plans.length + 1,
                AppButton(
                  label: Strings.planContinue,
                  onPressed: _leave,
                  loading: _loading,
                  expand: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: AppPressable(
                  onTap: _loading ? null : _leave,
                  minTarget: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      Strings.planSkip,
                      style: AppText.body.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      haptic: true,
      child: Semantics(
        selected: selected,
        button: true,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: selected ? AppColors.medBlueLight : AppColors.surface,
            borderRadius: AppRadii.rLg,
            border: Border.all(
              color: selected ? AppColors.medBlue : AppColors.gray200,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name, style: AppText.subheading),
                    if (plan.note case final note?) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(note, style: AppText.caption),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(plan.price, style: AppText.subheading),
              const SizedBox(width: AppSpacing.md),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.medBlue : AppColors.gray400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

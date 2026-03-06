/// ============================================================================
/// PLANS SCREEN — Stripe subscription management
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../organization/presentation/providers/organization_provider.dart';
import '../../data/models/billing_models.dart';
import '../../data/repositories/billing_repository.dart';
import '../providers/billing_provider.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen>
    with WidgetsBindingObserver {
  String? _selectedOrgId;
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Refresh subscription when returning from the browser (Stripe Checkout).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _selectedOrgId != null) {
      ref.read(subscriptionProvider.notifier).loadSubscription(_selectedOrgId!);
    }
  }

  void _loadData() {
    final orgState = ref.read(myOrganizationsProvider);
    final orgId = orgState.selectedOrganization?.organizationId;
    if (orgId != null) {
      setState(() => _selectedOrgId = orgId);
      ref.read(subscriptionProvider.notifier).loadSubscription(orgId);
    }
  }

  Future<void> _subscribe(PlanInfo plan, int seats) async {
    if (_selectedOrgId == null || _isLaunching) return;
    setState(() => _isLaunching = true);
    try {
      final repo = ref.read(billingRepositoryProvider);
      final url = await repo.createCheckoutSession(
        orgId: _selectedOrgId!,
        plan: plan.id,
        seats: seats,
        successUrl: '${AppConfig.apiBaseUrl}/billing/success',
        cancelUrl: '${AppConfig.apiBaseUrl}/billing/cancel',
      );
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('Could not open payment page');
      }
    } catch (e) {
      _showError('Failed to start checkout: $e');
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  Future<void> _openPortal() async {
    if (_selectedOrgId == null || _isLaunching) return;
    setState(() => _isLaunching = true);
    try {
      final repo = ref.read(billingRepositoryProvider);
      final url = await repo.createPortalSession(
        orgId: _selectedOrgId!,
        returnUrl: '${AppConfig.apiBaseUrl}/billing/return',
      );
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('Could not open billing portal');
      }
    } catch (e) {
      _showError('Failed to open billing portal: $e');
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(plansProvider);
    final subState = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Billing & Plans',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_selectedOrgId != null) {
            await ref
                .read(subscriptionProvider.notifier)
                .loadSubscription(_selectedOrgId!);
          }
          ref.invalidate(plansProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Current subscription card ──────────────────────────────
            if (subState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (subState.subscription != null &&
                subState.subscription!.isActive)
              _ActiveSubscriptionCard(
                subscription: subState.subscription!,
                onManage: _openPortal,
                isLaunching: _isLaunching,
              ),

            if (subState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  subState.errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 8),
            const Text(
              'Choose a Plan',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Billed annually • 14-day free trial • Cancel anytime',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // ── Plan cards ────────────────────────────────────────────
            plansAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(
                'Failed to load plans: $e',
                style: const TextStyle(color: AppColors.error),
              ),
              data: (plans) => Column(
                children: plans
                    .map((plan) => _PlanCard(
                          plan: plan,
                          currentSubscription: subState.subscription,
                          onSubscribe: _subscribe,
                          isLaunching: _isLaunching,
                        ))
                    .toList(),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'All plans include end-to-end encrypted messaging, voice messages, and HIPAA-compliant infrastructure.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Active Subscription Card
// ============================================================================

class _ActiveSubscriptionCard extends StatelessWidget {
  final SubscriptionModel subscription;
  final VoidCallback onManage;
  final bool isLaunching;

  const _ActiveSubscriptionCard({
    required this.subscription,
    required this.onManage,
    required this.isLaunching,
  });

  @override
  Widget build(BuildContext context) {
    final planName = subscription.plan.name[0].toUpperCase() +
        subscription.plan.name.substring(1);
    final renewalDate = subscription.currentPeriodEnd != null
        ? DateFormat('MMM d, y').format(subscription.currentPeriodEnd!)
        : null;
    final isTrialing = subscription.isTrialing;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text(
                isTrialing ? 'Free Trial Active' : 'Active Subscription',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$planName Plan',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${subscription.seats} seats',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          if (renewalDate != null) ...[
            const SizedBox(height: 4),
            Text(
              isTrialing
                  ? 'Trial ends $renewalDate'
                  : 'Renews $renewalDate',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
          if (subscription.cancelAtPeriodEnd) ...[
            const SizedBox(height: 4),
            const Text(
              'Cancels at period end',
              style: TextStyle(color: AppColors.warning, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isLaunching ? null : onManage,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isLaunching
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Manage Billing'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Plan Card
// ============================================================================

class _PlanCard extends StatefulWidget {
  final PlanInfo plan;
  final SubscriptionModel? currentSubscription;
  final Future<void> Function(PlanInfo, int) onSubscribe;
  final bool isLaunching;

  const _PlanCard({
    required this.plan,
    required this.currentSubscription,
    required this.onSubscribe,
    required this.isLaunching,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  late int _seats;

  @override
  void initState() {
    super.initState();
    _seats = widget.plan.minSeats;
  }

  bool get _isCurrent =>
      widget.currentSubscription != null &&
      widget.currentSubscription!.isActive &&
      widget.currentSubscription!.plan == widget.plan.id;

  int get _annualTotal => (widget.plan.pricePerSeatYear * _seats) ~/ 100;

  void _increment() {
    final max = widget.plan.maxSeats;
    if (max == null || _seats < max) {
      setState(() => _seats++);
    }
  }

  void _decrement() {
    if (_seats > widget.plan.minSeats) setState(() => _seats--);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: _isCurrent
            ? Border.all(color: AppColors.primary, width: 2)
            : Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.plan.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isCurrent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Current',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.plan.seatRange,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),

            // Price
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: widget.plan.formattedPrice,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Features
            ...widget.plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      f,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Seat stepper
            Row(
              children: [
                const Text(
                  'Seats:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _decrement,
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                Text(
                  '$_seats',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _increment,
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppColors.primary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            // Annual total
            Text(
              'Annual total: \$$_annualTotal',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 12),

            // Subscribe button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.isLaunching
                    ? null
                    : () => widget.onSubscribe(widget.plan, _seats),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textInverse,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: widget.isLaunching
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textInverse,
                        ),
                      )
                    : Text(
                        _isCurrent ? 'Change Plan' : 'Start Free Trial',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

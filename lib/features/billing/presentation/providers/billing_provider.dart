/// ============================================================================
/// BILLING PROVIDERS - Riverpod State Management
/// ============================================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/billing_models.dart';
import '../../data/repositories/billing_repository.dart';

// ============================================================================
// REPOSITORY PROVIDER
// ============================================================================

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository();
});

// ============================================================================
// PLANS PROVIDER (simple async, no state management needed)
// ============================================================================

final plansProvider = FutureProvider<List<PlanInfo>>((ref) async {
  final repo = ref.watch(billingRepositoryProvider);
  return repo.getPlans();
});

// ============================================================================
// SUBSCRIPTION STATE
// ============================================================================

class SubscriptionState {
  final bool isLoading;
  final SubscriptionModel? subscription;
  final String? errorMessage;

  const SubscriptionState({
    this.isLoading = false,
    this.subscription,
    this.errorMessage,
  });

  SubscriptionState copyWith({
    bool? isLoading,
    SubscriptionModel? subscription,
    bool clearSubscription = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      subscription: clearSubscription ? null : (subscription ?? this.subscription),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  late final BillingRepository _repository;

  @override
  SubscriptionState build() {
    _repository = ref.watch(billingRepositoryProvider);
    return const SubscriptionState();
  }

  Future<void> loadSubscription(String orgId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final sub = await _repository.getSubscription(orgId);
      state = state.copyWith(
        isLoading: false,
        subscription: sub,
        clearSubscription: sub == null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load subscription: $e',
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(() {
  return SubscriptionNotifier();
});

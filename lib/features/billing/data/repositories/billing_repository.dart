/// ============================================================================
/// BILLING REPOSITORY
/// ============================================================================
library;

import '../../../../core/services/api_service.dart';
import '../../../../core/config/app_config.dart';
import '../models/billing_models.dart';

class BillingRepository {
  final ApiService _api = ApiService();

  Future<List<PlanInfo>> getPlans() async {
    try {
      _log('Fetching billing plans...');
      final response = await _api.get<List<dynamic>>(
        '/billing/plans',
        fromJson: (json) => json as List<dynamic>,
      );
      if (response.success && response.data != null) {
        return response.data!
            .map((j) => PlanInfo.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      _log('Error fetching plans: $e');
      rethrow;
    }
  }

  Future<SubscriptionModel?> getSubscription(String orgId) async {
    try {
      _log('Fetching subscription for org $orgId...');
      final response = await _api.get<Map<String, dynamic>>(
        '/billing/subscription',
        queryParams: {'org_id': orgId},
        fromJson: (json) => json as Map<String, dynamic>,
      );
      if (response.success && response.data != null) {
        return SubscriptionModel.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      // 404 means no subscription — not an error
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        return null;
      }
      _log('Error fetching subscription: $e');
      rethrow;
    }
  }

  Future<String> createCheckoutSession({
    required String orgId,
    required SubscriptionPlan plan,
    required int seats,
    required String successUrl,
    required String cancelUrl,
  }) async {
    try {
      _log('Creating checkout session...');
      final response = await _api.post<Map<String, dynamic>>(
        '/billing/checkout',
        body: {
          'org_id': orgId,
          'plan': plan.name,
          'seats': seats,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );
      if (response.success && response.data != null) {
        return response.data!['checkout_url'] as String;
      }
      throw Exception(response.error ?? 'Failed to create checkout session');
    } catch (e) {
      _log('Error creating checkout session: $e');
      rethrow;
    }
  }

  Future<String> createPortalSession({
    required String orgId,
    required String returnUrl,
  }) async {
    try {
      _log('Creating portal session...');
      final response = await _api.post<Map<String, dynamic>>(
        '/billing/portal',
        body: {
          'org_id': orgId,
          'return_url': returnUrl,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );
      if (response.success && response.data != null) {
        return response.data!['portal_url'] as String;
      }
      throw Exception(response.error ?? 'Failed to create portal session');
    } catch (e) {
      _log('Error creating portal session: $e');
      rethrow;
    }
  }

  void _log(String message) {
    if (AppConfig.debugMode) {
      assert(() {
        // ignore: avoid_print
        print('[BillingRepository] $message');
        return true;
      }());
    }
  }
}

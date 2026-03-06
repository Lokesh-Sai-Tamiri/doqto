/// Billing domain models — plans, subscription state.

enum SubscriptionPlan { clinic, practice, hospital, network }

enum SubscriptionStatus { trialing, active, pastDue, canceled, incomplete }

class PlanInfo {
  final SubscriptionPlan id;
  final String name;
  final int minSeats;
  final int? maxSeats; // null means unlimited
  final int pricePerSeatYear; // USD cents
  final List<String> features;

  const PlanInfo({
    required this.id,
    required this.name,
    required this.minSeats,
    this.maxSeats,
    required this.pricePerSeatYear,
    required this.features,
  });

  factory PlanInfo.fromJson(Map<String, dynamic> json) {
    return PlanInfo(
      id: SubscriptionPlan.values.firstWhere(
        (e) => e.name == json['id'],
        orElse: () => SubscriptionPlan.clinic,
      ),
      name: json['name'] as String,
      minSeats: json['min_seats'] as int,
      maxSeats: json['max_seats'] as int?,
      pricePerSeatYear: json['price_per_seat_year'] as int,
      features: (json['features'] as List<dynamic>).cast<String>(),
    );
  }

  /// Formatted price like "$120/seat/yr"
  String get formattedPrice {
    final dollars = pricePerSeatYear ~/ 100;
    return '\$$dollars/seat/yr';
  }

  /// Seat range label like "10–25 seats"
  String get seatRange {
    if (maxSeats == null) return '$minSeats+ seats';
    return '$minSeats–$maxSeats seats';
  }
}

class SubscriptionModel {
  final String id;
  final String orgId;
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final int seats;
  final String stripeCustomerId;
  final String? stripeSubscriptionId;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? trialEnd;
  final bool cancelAtPeriodEnd;

  const SubscriptionModel({
    required this.id,
    required this.orgId,
    required this.plan,
    required this.status,
    required this.seats,
    required this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.trialEnd,
    this.cancelAtPeriodEnd = false,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    SubscriptionStatus parseStatus(String s) {
      switch (s) {
        case 'trialing':
          return SubscriptionStatus.trialing;
        case 'active':
          return SubscriptionStatus.active;
        case 'past_due':
          return SubscriptionStatus.pastDue;
        case 'canceled':
          return SubscriptionStatus.canceled;
        default:
          return SubscriptionStatus.incomplete;
      }
    }

    return SubscriptionModel(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      plan: SubscriptionPlan.values.firstWhere(
        (e) => e.name == json['plan'],
        orElse: () => SubscriptionPlan.clinic,
      ),
      status: parseStatus(json['status'] as String),
      seats: json['seats'] as int,
      stripeCustomerId: json['stripe_customer_id'] as String,
      stripeSubscriptionId: json['stripe_subscription_id'] as String?,
      currentPeriodStart: json['current_period_start'] != null
          ? DateTime.parse(json['current_period_start'] as String)
          : null,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.parse(json['current_period_end'] as String)
          : null,
      trialEnd: json['trial_end'] != null
          ? DateTime.parse(json['trial_end'] as String)
          : null,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
    );
  }

  bool get isActive =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.trialing;

  bool get isTrialing => status == SubscriptionStatus.trialing;
}

/// A billing plan offered on the subscription screen.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.pricePerMonth,
    required this.billingPeriod,
    this.mostPopular = false,
  });

  /// Stable plan key; maps to a Stripe Price ID in the server function.
  final String id;
  final String name;

  /// Display price, e.g. "€9.99".
  final String pricePerMonth;
  final String billingPeriod;
  final bool mostPopular;

  static const List<SubscriptionPlan> defaults = [
    SubscriptionPlan(
      id: 'monthly',
      name: 'Monthly',
      pricePerMonth: '€9.99',
      billingPeriod: 'per month',
    ),
    SubscriptionPlan(
      id: 'yearly',
      name: 'Yearly',
      pricePerMonth: '€4.99',
      billingPeriod: 'per month, billed yearly',
      mostPopular: true,
    ),
  ];
}

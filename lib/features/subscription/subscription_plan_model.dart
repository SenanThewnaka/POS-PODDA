class SubscriptionBillingOption {
  final String id;
  final String label;
  final String subtitle;
  final int months;
  final int durationDays;
  final int priceLkr;
  final int amountCents;
  final String cycleKey;
  final String? savingsBadge;
  final bool isPopular;

  const SubscriptionBillingOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.months,
    required this.durationDays,
    required this.priceLkr,
    required this.amountCents,
    required this.cycleKey,
    this.savingsBadge,
    this.isPopular = false,
  });

  double get monthlyEffectivePrice => priceLkr / months;

  static const List<SubscriptionBillingOption> options = [
    SubscriptionBillingOption(
      id: 'opt_1m',
      label: '1 Month',
      subtitle: 'Monthly Plan',
      months: 1,
      durationDays: 30,
      priceLkr: 2900,
      amountCents: 290000,
      cycleKey: 'monthly',
      savingsBadge: null,
      isPopular: false,
    ),
    SubscriptionBillingOption(
      id: 'opt_3m',
      label: '3 Months',
      subtitle: 'Quarterly Plan',
      months: 3,
      durationDays: 90,
      priceLkr: 7900,
      amountCents: 790000,
      cycleKey: 'quarterly',
      savingsBadge: 'Save Rs. 800',
      isPopular: false,
    ),
    SubscriptionBillingOption(
      id: 'opt_6m',
      label: '6 Months',
      subtitle: 'Semi-Annual Plan',
      months: 6,
      durationDays: 180,
      priceLkr: 14900,
      amountCents: 1490000,
      cycleKey: 'semi_annual',
      savingsBadge: 'Save Rs. 2,500',
      isPopular: false,
    ),
    SubscriptionBillingOption(
      id: 'opt_1y',
      label: '1 Year',
      subtitle: 'Annual Plan',
      months: 12,
      durationDays: 365,
      priceLkr: 27900,
      amountCents: 2790000,
      cycleKey: 'yearly',
      savingsBadge: 'Best Value • Save Rs. 6,900',
      isPopular: true,
    ),
  ];
}

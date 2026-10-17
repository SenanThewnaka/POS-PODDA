class SubscriptionBillingOption {
  final String id;
  final String tier; // 'plus' or 'pro'
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
    required this.tier,
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

  static const List<SubscriptionBillingOption> plusOptions = [
    SubscriptionBillingOption(
      id: 'opt_plus_1m',
      tier: 'plus',
      label: '1 Month',
      subtitle: 'Monthly Plan',
      months: 1,
      durationDays: 30,
      priceLkr: 1500,
      amountCents: 150000,
      cycleKey: 'monthly',
      savingsBadge: null,
      isPopular: false,
    ),
    SubscriptionBillingOption(
      id: 'opt_plus_3m',
      tier: 'plus',
      label: '3 Months',
      subtitle: 'Quarterly Plan',
      months: 3,
      durationDays: 90,
      priceLkr: 4200,
      amountCents: 420000,
      cycleKey: 'quarterly',
      savingsBadge: 'Save Rs. 300',
      isPopular: false,
    ),
    SubscriptionBillingOption(
      id: 'opt_plus_6m',
      tier: 'plus',
      label: '6 Months',
      subtitle: 'Semi-Annual Plan',
      months: 6,
      durationDays: 180,
      priceLkr: 7900,
      amountCents: 790000,
      cycleKey: 'semi_annual',
      savingsBadge: 'Save Rs. 1,100',
      isPopular: false,
    ),
    SubscriptionBillingOption(
      id: 'opt_plus_1y',
      tier: 'plus',
      label: '1 Year',
      subtitle: 'Annual Plan',
      months: 12,
      durationDays: 365,
      priceLkr: 14900,
      amountCents: 1490000,
      cycleKey: 'yearly',
      savingsBadge: 'Best Value • Save Rs. 3,100',
      isPopular: true,
    ),
  ];

  static const List<SubscriptionBillingOption> proOptions = [
    SubscriptionBillingOption(
      id: 'opt_pro_1m',
      tier: 'pro',
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
      id: 'opt_pro_3m',
      tier: 'pro',
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
      id: 'opt_pro_6m',
      tier: 'pro',
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
      id: 'opt_pro_1y',
      tier: 'pro',
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

  static List<SubscriptionBillingOption> get options => proOptions;

  static List<SubscriptionBillingOption> optionsForTier(String tier) {
    if (tier.toLowerCase() == 'plus') return plusOptions;
    return proOptions;
  }
}

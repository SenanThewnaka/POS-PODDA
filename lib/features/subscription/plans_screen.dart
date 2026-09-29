import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:sme_buddy/features/subscription/subscription_plan_model.dart';
import 'package:sme_buddy/features/subscription/payments_lk_service.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  String _selectedTier = 'pro'; // 'plus' or 'pro'
  late SubscriptionBillingOption _selectedOption;
  bool _isLoading = false;

  final currencyFormatter = NumberFormat('#,##0', 'en_US');

  final List<String> _plusFeatures = const [
    "Full POS Billing & Fast Barcode Scanning",
    "Thermal Receipt Printing (58mm / 80mm)",
    "Inventory Catalog & Low Stock Alerts",
    "Daily Sales Summary & Cash Shift Balancing",
    "Single Counter / Single Device Operation",
    "Automatic Cloud Sync & Local Backup",
  ];

  final List<String> _proFeatures = const [
    "Everything in Plus Included",
    "Unlimited Inventory Items & Dynamic Batches",
    "Multi-Cashier Logins & Custom Role Permissions",
    "Wholesale Purchase Cost & Margin Privacy Masking",
    "Supplier Goods Received Notes (GRN) Management",
    "Customer Credit Book (ණය පොත) & Settlement Receipts",
    "Custom Thermal Bill Header, Footer & Store Logo",
    "Advanced Financial Reports & Profit Analytics",
  ];

  @override
  void initState() {
    super.initState();
    // Default to pro (or user's current tier if plus)
    _selectedOption = SubscriptionBillingOption.proOptions[1]; // 3 Months default
  }

  void _switchTier(String tier) {
    if (_selectedTier == tier) return;
    setState(() {
      _selectedTier = tier;
      final newOptions = SubscriptionBillingOption.optionsForTier(tier);
      _selectedOption = newOptions.firstWhere(
        (o) => o.cycleKey == _selectedOption.cycleKey,
        orElse: () => newOptions[1],
      );
    });
  }

  Color get _tierColor =>
      _selectedTier == 'plus' ? const Color(0xFF0EA5E9) : const Color(0xFF6366F1);

  Future<void> _handlePayment() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final paymentsService = ref.read(paymentsLkServiceProvider);
      PaymentsLkCheckoutResult? checkout;

      // 1. Prefer secure Cloud Function (Universal: Web, PWA, Android, iOS with no CORS)
      try {
        checkout = await paymentsService.createCheckoutViaCloudFunction(
          tier: _selectedTier,
          cycleKey: _selectedOption.cycleKey,
        );
      } catch (cloudErr) {
        debugPrint("Cloud function checkout attempt: $cloudErr");
        // Fallback: If running offline or Cloud Function is not yet deployed,
        // native platforms can call direct gateway, while Web shows the sandbox dialog
        if (!kIsWeb) {
          final refId = 'sub_${user.shopId}_${DateTime.now().millisecondsSinceEpoch}';
          final tierName = _selectedTier == 'plus' ? 'Plus' : 'Pro';
          checkout = await paymentsService.createCheckout(
            amountCents: _selectedOption.amountCents,
            description: 'POS Podda $tierName - ${_selectedOption.label} Subscription',
            reference: refId,
            customerEmail: user.email,
            customerName: user.name,
            customerPhone: user.mobile,
          );
        } else {
          rethrow;
        }
      }

      if (mounted) setState(() => _isLoading = false);

      if (checkout != null && checkout.url.isNotEmpty) {
        await launchUrlString(checkout.url, mode: LaunchMode.externalApplication);

        if (mounted && (checkout.paymentId != null || checkout.checkoutId.isNotEmpty)) {
          _showVerificationModal(checkout.paymentId ?? '', checkout.url, checkout.checkoutId);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final isCorsOrFunctionError = kIsWeb ||
            e.toString().contains('Failed to fetch') ||
            e.toString().contains('ClientException') ||
            e.toString().contains('functions') ||
            e.toString().contains('FirebaseFunctionsException');
        if (isCorsOrFunctionError) {
          _showWebCorsTestingDialog(_selectedOption);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Payment initiation failed: $e"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _showWebCorsTestingDialog(SubscriptionBillingOption option) {
    final tierName = _selectedTier == 'plus' ? 'Plus (+)' : 'Pro';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Web Browser Notice",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "You are testing POS Podda inside a Web Browser (Chrome/Edge/Safari).",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              "Web browsers enforce strict CORS (Cross-Origin Resource Sharing) security that blocks direct client-side checkout calls to the Payments.lk API.",
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "On Android & iPhone (iOS), the payment gateway connects natively with 0 CORS issues!",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "To test your subscription upgrade flow right now on Web, you can activate $tierName (${option.label}) in Sandbox Mode:",
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.bolt, color: Colors.white, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: _tierColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _activateSubscription(option);
            },
            label: const Text("Activate Plan (Sandbox)", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showVerificationModal(String paymentId, String checkoutUrl, [String? checkoutId]) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        bool isChecking = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Icon(Icons.payment, size: 48, color: _tierColor),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Complete Payment on Payments.lk",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We opened the secure Payments.lk checkout page. Once you have completed payment via Card or LANKAQR, tap below to activate your plan.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isChecking
                        ? null
                        : () async {
                            setModalState(() => isChecking = true);
                            try {
                              final paymentsService = ref.read(paymentsLkServiceProvider);
                              bool isSucceeded = false;

                              // Try Cloud Function verification first
                              try {
                                final res = await paymentsService.verifyPaymentViaCloudFunction(
                                  paymentId: paymentId.isNotEmpty ? paymentId : null,
                                  checkoutId: checkoutId,
                                );
                                if (res['status'] == 'succeeded') {
                                  isSucceeded = true;
                                }
                              } catch (_) {
                                // Fallback to direct gateway check if available
                                if (paymentId.isNotEmpty) {
                                  final payment = await paymentsService.getPayment(paymentId);
                                  if (payment.status == 'succeeded') {
                                    isSucceeded = true;
                                  }
                                }
                              }

                              if (isSucceeded) {
                                if (context.mounted) Navigator.pop(sheetContext);
                                await _activateSubscription(_selectedOption);
                              } else {
                                setModalState(() => isChecking = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Payment is pending or not yet confirmed. If you completed checkout, please allow a moment and tap again.",
                                      ),
                                      backgroundColor: Colors.orangeAccent,
                                    ),
                                  );
                                }
                              }
                            } catch (err) {
                              setModalState(() => isChecking = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Verification error: $err"),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isChecking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            "I HAVE COMPLETED PAYMENT",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () async {
                      await launchUrlString(checkoutUrl, mode: LaunchMode.externalApplication);
                    },
                    child: const Text("Re-open Checkout Page"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _activateSubscription(SubscriptionBillingOption option) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    final now = DateTime.now();
    final baseDate = (user.expiryDate != null && user.expiryDate!.isAfter(now))
        ? user.expiryDate!
        : now;
    final newExpiry = baseDate.add(Duration(days: option.durationDays));
    final tierName = _selectedTier == 'plus' ? 'Plus (+)' : 'Pro';

    final updated = user.copyWith(
      plan: _selectedTier,
      subscriptionStatus: 'active',
      billingCycle: option.cycleKey,
      expiryDate: newExpiry,
    );

    await ref.read(userProfileRepositoryProvider).saveUserProfile(updated);

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.stars, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text("Plan Activated!"),
            ],
          ),
          content: Text(
            "Congratulations! Your shop has been upgraded to POS Podda $tierName for ${option.label}.\n\nValid until: ${DateFormat('MMM dd, yyyy').format(newExpiry)}.",
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text("OK, LET'S GO"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(userProfileProvider).value;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          "Subscription & Pricing",
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Plan Status Header
            if (user != null) _buildCurrentStatusBanner(user, isDark),
            const SizedBox(height: 20),

            // Tier Selector (Plus vs Pro)
            Text(
              "Choose Your Tier",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            _buildTierSelector(isDark),
            const SizedBox(height: 24),

            // Billing Cycle Selector (1M, 3M, 6M, 1Y)
            Text(
              "Select Billing Cycle",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            _buildBillingCycleSelector(isDark),
            const SizedBox(height: 24),

            // Plan Details Card
            _buildSelectedPlanCard(isDark),
            const SizedBox(height: 24),

            // Checkout CTA
            ElevatedButton(
              onPressed: _isLoading ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: _tierColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      "PAY RS. ${currencyFormatter.format(_selectedOption.priceLkr)} • ${_selectedOption.label.toUpperCase()} ${_selectedTier.toUpperCase()}",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
            ),
            const SizedBox(height: 12),

            // Gateway & Trust Assurance
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  "Secured by Payments.lk • Cards & LANKAQR Supported",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTierSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTierTab(
              title: "Plus (+)",
              subtitle: "Essential POS",
              isSelected: _selectedTier == 'plus',
              accentColor: const Color(0xFF0EA5E9),
              onTap: () => _switchTier('plus'),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildTierTab(
              title: "Pro",
              subtitle: "Complete ERP",
              badge: "POPULAR",
              isSelected: _selectedTier == 'pro',
              accentColor: const Color(0xFF6366F1),
              onTap: () => _switchTier('pro'),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierTab({
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
    required bool isDark,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.amber : Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white70 : (isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusBanner(user, bool isDark) {
    final now = DateTime.now();
    final expiry = user.expiryDate;
    final isExpired = expiry == null || now.isAfter(expiry);
    final daysLeft = expiry != null ? expiry.difference(now).inDays : 0;

    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      border: Border.all(
        color: isExpired ? Colors.redAccent.withValues(alpha: 0.5) : const Color(0xFF6366F1).withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isExpired ? Colors.red.withValues(alpha: 0.2) : const Color(0xFF6366F1).withValues(alpha: 0.2),
            child: Icon(
              isExpired ? Icons.warning_amber_rounded : Icons.verified,
              color: isExpired ? Colors.redAccent : const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Current Plan: ${user.plan.toString().toUpperCase()}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  isExpired
                      ? (expiry != null
                          ? "Expired on ${DateFormat('MMM dd, yyyy').format(expiry)}"
                          : "No active subscription / Inactive")
                      : "$daysLeft days left (Expires ${DateFormat('MMM dd, yyyy').format(expiry!)})",
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingCycleSelector(bool isDark) {
    final currentOptions = SubscriptionBillingOption.optionsForTier(_selectedTier);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)),
      ),
      child: Row(
        children: currentOptions.map((opt) {
          final isSelected = opt.id == _selectedOption.id;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedOption = opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _tierColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _tierColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    if (opt.isPopular)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.amber : Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "BEST",
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedPlanCard(bool isDark) {
    final isPlus = _selectedTier == 'plus';
    final planTitle = isPlus ? "POS PODDA PLUS (+)" : "POS PODDA PRO";
    final features = isPlus ? _plusFeatures : _proFeatures;
    final featuresHeader = isPlus ? "INCLUDED PLUS (+) FEATURES" : "INCLUDED PRO FEATURES";

    return GlassCard(
      borderRadius: 24,
      border: Border.all(color: _tierColor, width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Top
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: _tierColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  planTitle,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                ),
                if (_selectedOption.savingsBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _selectedOption.savingsBadge!,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price Breakdown
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "Rs. ${currencyFormatter.format(_selectedOption.priceLkr)}",
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "/ ${_selectedOption.label.toLowerCase()}",
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                if (_selectedOption.months > 1) ...[
                  const SizedBox(height: 2),
                  Text(
                    "Equivalent to Rs. ${currencyFormatter.format(_selectedOption.monthlyEffectivePrice.round())} / month",
                    style: TextStyle(color: _tierColor, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                Text(
                  featuresHeader,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

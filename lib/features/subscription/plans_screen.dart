import 'package:flutter/material.dart';
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
  SubscriptionBillingOption _selectedOption = SubscriptionBillingOption.options[1]; // default 3 Months
  bool _isLoading = false;

  final currencyFormatter = NumberFormat('#,##0', 'en_US');

  final List<String> _proFeatures = const [
    "Unlimited Inventory Items & Dynamic Batches",
    "Multi-Cashier Logins & Role Permission Templates",
    "Wholesale Purchase Cost & Margin Privacy Masking",
    "Supplier Goods Received Notes (GRN) Management",
    "Customer Credit Book (ණය පොත) & Settlement Receipts",
    "Shift Management, Cash Reconciliation & Z-Reports",
    "Barcode Sticker Generation & ESC/POS Printing",
    "Automatic Cloud Sync & Multi-Device Access",
  ];

  Future<void> _handlePayment() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final paymentsService = ref.read(paymentsLkServiceProvider);
      final refId = 'sub_${user.shopId}_${DateTime.now().millisecondsSinceEpoch}';

      final checkout = await paymentsService.createCheckout(
        amountCents: _selectedOption.amountCents,
        description: 'POS Podda Pro - ${_selectedOption.label} Subscription',
        reference: refId,
        customerEmail: user.email,
        customerName: user.name,
        customerPhone: user.mobile,
      );

      if (mounted) setState(() => _isLoading = false);

      if (checkout.url.isNotEmpty) {
        await launchUrlString(checkout.url, mode: LaunchMode.externalApplication);

        if (mounted && checkout.paymentId != null) {
          _showVerificationModal(checkout.paymentId!, checkout.url);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment initiation failed: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showVerificationModal(String paymentId, String checkoutUrl) {
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
                  const Center(
                    child: Icon(Icons.payment, size: 48, color: Color(0xFF6366F1)),
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
                              final payment = await paymentsService.getPayment(paymentId);

                              if (payment.isSucceeded) {
                                Navigator.pop(sheetContext); // Close modal
                                await _activateSubscription(_selectedOption);
                              } else {
                                setModalState(() => isChecking = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Status: ${payment.status.toUpperCase()}. If you just paid, please wait a moment and tap verify again.",
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              setModalState(() => isChecking = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Verification error: $e"),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isChecking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            "I HAVE PAID • VERIFY & ACTIVATE",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => launchUrlString(checkoutUrl, mode: LaunchMode.externalApplication),
                        child: const Text("Re-open Checkout"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                      ),
                    ],
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

    final updated = user.copyWith(
      plan: 'pro',
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
              Text("Plan Activated! 🎉"),
            ],
          ),
          content: Text(
            "Congratulations! Your POS Podda Pro subscription is active until ${DateFormat('MMMM dd, yyyy').format(newExpiry)}.\n\nAll Pro features are fully unlocked.",
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Return to home/settings
              },
              child: const Text("CONTINUE TO POS"),
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

            // 4-Option Duration Tabs (1M, 3M, 6M, 1Y)
            _buildBillingCycleSelector(isDark),
            const SizedBox(height: 24),

            // Pro Plan Card
            _buildSelectedPlanCard(isDark),
            const SizedBox(height: 24),

            // Checkout CTA
            ElevatedButton(
              onPressed: _isLoading ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
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
                      "PAY RS. ${currencyFormatter.format(_selectedOption.priceLkr)} • ${_selectedOption.label.toUpperCase()}",
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)),
      ),
      child: Row(
        children: SubscriptionBillingOption.options.map((opt) {
          final isSelected = opt.id == _selectedOption.id;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedOption = opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
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
    return GlassCard(
      borderRadius: 24,
      border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Top
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF6366F1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "POS PODDA PRO",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
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
                    style: const TextStyle(color: Color(0xFF6366F1), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                const Text(
                  "INCLUDED PRO FEATURES",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                ..._proFeatures.map((f) => Padding(
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

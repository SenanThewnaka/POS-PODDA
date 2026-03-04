import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/subscription/plans_screen.dart';

class SubscriptionInfoCard extends ConsumerWidget {
  const SubscriptionInfoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return userAsync.when(
      data: (user) {
        if (user == null || user.expiryDate == null) return const SizedBox();

        final now = DateTime.now();
        final expiry = user.expiryDate!;
        final daysLeft = expiry.difference(now).inDays;
        final isExpired = now.isAfter(expiry);
        
        // Trial UI - Updated for Dark/Glass Theme
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        Color baseColor = isDark ? Colors.blue : Colors.blueAccent;
        Color accentColor = isDark ? Colors.cyanAccent : Colors.blue.shade700;
        String planLabel = user.plan.toUpperCase();
        String cycleLabel = user.billingCycle.toUpperCase();
        
        if (user.plan == 'trial') {
           baseColor = Colors.orange;
           accentColor = isDark ? Colors.orangeAccent : Colors.deepOrange;
        } else if (user.plan == 'pro') {
           baseColor = Colors.purple;
           accentColor = isDark ? Colors.purpleAccent : Colors.purple;
        }
        
        if (isExpired) {
           baseColor = Colors.red;
           accentColor = Colors.redAccent;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(color: baseColor.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 0, offset: const Offset(0, 4))
            ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("CURRENT PLAN", style: TextStyle(fontSize: 12, color: accentColor.withValues(alpha: 0.8), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(planLabel, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: accentColor)),
                      Text(cycleLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isExpired ? Colors.red.withValues(alpha: 0.8) : Colors.green.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24)
                    ),
                    child: Text(
                      isExpired ? "EXPIRED" : "ACTIVE",
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              
              if (!isExpired) ...[
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      Text("Expires On:", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
                      Text(DateFormat('MMM dd, yyyy').format(expiry), style: TextStyle(fontWeight: FontWeight.bold, color: accentColor)),
                   ],
                 ),
                 const SizedBox(height: 8),
                 ClipRRect(
                   borderRadius: BorderRadius.circular(4),
                   child: LinearProgressIndicator(
                     value: (daysLeft / 14).clamp(0.0, 1.0), 
                     backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                     color: daysLeft < 3 ? Colors.redAccent : accentColor,
                     minHeight: 6,
                   ),
                 ),
                 const SizedBox(height: 8),
                 Text(
                   "$daysLeft Days Remaining", 
                   style: TextStyle(color: daysLeft < 3 ? Colors.redAccent : accentColor, fontWeight: FontWeight.bold),
                 ),
              ] else ...[
                 Text(
                   "Your subscription has ended. You are in Read-Only Mode.",
                   style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                 ),
                 const SizedBox(height: 8),

                  Text(
                   "Account management: yourdomain.com",
                   style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38),
                 )
              ],
              
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen()));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12)
                  ), 
                  child: const Text("VIEW PLANS & FEATURES", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_,__) => const SizedBox(),
    );
  }
}

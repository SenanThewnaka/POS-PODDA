import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';

class SubscriptionState {
  final bool isExpired;
  final bool isReadOnly;
  final String plan; // trial, plus, pro, free
  final bool canAddItems;
  final String? expirationReason; // "Trial Expired", "Subscription Expired", "Limit Reached"
  
  // Feature Access Flags
  final bool canManageTeam;
  final bool canUseCredit;
  final bool canViewAdvancedStats;
  final bool canUseGRN; // GRN is now available for both Plus and Pro

  const SubscriptionState({
    required this.isExpired,
    required this.isReadOnly,
    required this.plan,
    required this.canAddItems,
    this.expirationReason,
    this.canManageTeam = false,
    this.canUseCredit = false,
    this.canViewAdvancedStats = false,
    this.canUseGRN = true,
  });

  factory SubscriptionState.active(String plan) {
    final isProOrTrial = plan.toLowerCase() == 'pro' || plan.toLowerCase() == 'trial';
    return SubscriptionState(
      isExpired: false,
      isReadOnly: false,
      plan: plan,
      canAddItems: true,
      canManageTeam: isProOrTrial,
      canUseCredit: isProOrTrial,
      canViewAdvancedStats: isProOrTrial,
      canUseGRN: true, // both plus and pro can use GRN
    );
  }

  factory SubscriptionState.expired(String plan, String reason) {
    final isProOrTrial = plan.toLowerCase() == 'pro' || plan.toLowerCase() == 'trial';
    return SubscriptionState(
      isExpired: true,
      isReadOnly: true, // Expired means read-only
      plan: plan,
      canAddItems: false,
      expirationReason: reason,
      canManageTeam: isProOrTrial,
      canUseCredit: isProOrTrial,
      canViewAdvancedStats: isProOrTrial,
      canUseGRN: true,
    );
  }
}

final subscriptionProvider = Provider<SubscriptionState>((ref) {
  final user = ref.watch(userProfileProvider).value;
  
  if (user == null) {
    return SubscriptionState.active('free');
  }

  final ownerProfile = (user.shopId.isNotEmpty && user.shopId != user.uid)
      ? ref.watch(shopOwnerProfileProvider).value
      : user;

  final effectiveUser = ownerProfile ?? user;

  final now = DateTime.now();
  final isExpired = effectiveUser.expiryDate != null && effectiveUser.expiryDate!.isBefore(now);
  final plan = effectiveUser.plan.toLowerCase(); // 'trial', 'plus', 'pro', 'free'

  if (isExpired) {
    return SubscriptionState.expired(plan, "Your $plan subscription has expired. Please renew to continue adding data.");
  }

  return SubscriptionState.active(plan);
});

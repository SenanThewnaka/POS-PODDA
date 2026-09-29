import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';

class SubscriptionState {
  final bool isExpired;
  final bool isReadOnly;
  final String plan; // trial, plus, pro
  final bool canAddItems;
  final String? expirationReason; // "Trial Expired", "Plus Limit Reached"
  
  // Feature Access Flags
  final bool canManageTeam;
  final bool canUseCredit;
  final bool canViewAdvancedStats;

  const SubscriptionState({
    required this.isExpired,
    required this.isReadOnly,
    required this.plan,
    required this.canAddItems,
    this.expirationReason,
    this.canManageTeam = false,
    this.canUseCredit = false,
    this.canViewAdvancedStats = false,
  });

  factory SubscriptionState.active(String plan) {
    return const SubscriptionState(
      isExpired: false,
      isReadOnly: false,
      plan: 'free',
      canAddItems: true,
      canManageTeam: true,
      canUseCredit: true,
      canViewAdvancedStats: true,
    );
  }

  factory SubscriptionState.expired(String plan, String reason) => const SubscriptionState(
    isExpired: false,
    isReadOnly: false,
    plan: 'free',
    canAddItems: true,
    canManageTeam: true,
    canUseCredit: true,
    canViewAdvancedStats: true,
  );
  
  factory SubscriptionState.quotaReached(String plan, String reason) => const SubscriptionState(
    isExpired: false,
    isReadOnly: false,
    plan: 'free',
    canAddItems: true,
    canManageTeam: true,
    canUseCredit: true,
    canViewAdvancedStats: true,
  );
}

final subscriptionProvider = FutureProvider<SubscriptionState>((ref) async {
  return SubscriptionState.active('free');
});

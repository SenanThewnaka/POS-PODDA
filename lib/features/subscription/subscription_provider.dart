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
    // Pro & Trial have full access
    bool fullAccess = plan == 'pro' || plan == 'trial' || plan == 'business'; // 'business' alias for pro
    // Plus (Starter) has restricted access
    
    return SubscriptionState(
      isExpired: false,
      isReadOnly: false,
      plan: plan,
      canAddItems: true,
      canManageTeam: fullAccess,
      canUseCredit: fullAccess,
      canViewAdvancedStats: fullAccess,
    );
  }

  factory SubscriptionState.expired(String plan, String reason) => SubscriptionState(
    isExpired: true,
    isReadOnly: true,
    plan: plan,
    canAddItems: false,
    expirationReason: reason,
    // Expired users loose all feature access too
    canManageTeam: false,
    canUseCredit: false,
    canViewAdvancedStats: false,
  );
  
  factory SubscriptionState.quotaReached(String plan, String reason) {
    bool fullAccess = plan == 'pro' || plan == 'trial' || plan == 'business';
    return SubscriptionState(
      isExpired: false, // Not expired in time, but blocked action
      isReadOnly: false, // Can still edit/delete, just not ADD
      plan: plan,
      canAddItems: false,
      expirationReason: reason,
      canManageTeam: fullAccess,
      canUseCredit: fullAccess,
      canViewAdvancedStats: fullAccess,
    );
  }
}

final subscriptionProvider = FutureProvider<SubscriptionState>((ref) async {
  final userAsync = ref.watch(userProfileProvider);
  
  return userAsync.when(
    data: (user) async {
       if (user == null) return SubscriptionState.expired('none', 'No User');
       
       final plan = user.plan.toLowerCase(); // trial, plus, pro
       final now = DateTime.now();
       final expiry = user.expiryDate;

       // 1. Legacy / New User Healing
       // If expiry is missing (Existing user), give them a fresh 14-day trial from TODAY.
       if (expiry == null) {
          // Fire-and-forget update to fix their record
          final repo = ref.read(userProfileRepositoryProvider);
          final newExpiry = DateTime.now().add(const Duration(days: 14));
          
          // We define a migration method or just use SetOptions merge
          // But we need to use the repository.
          // Let's just do a direct firestore call here for simplicity or use repo.
          // Better: Create a 'startTrial' method in repo? 
          // For now, let's keep it self-contained if we can access repo.
          // Actually, we can just return Active 'trial' and trigger the write.
          
          Future.microtask(() async {
             try {
                 // Keep existing plan if user manually set it in DB without expiry
                 String targetPlan = user.plan.isNotEmpty ? user.plan : 'trial';
                 
                 final updatedUser = user.copyWith(
                    plan: targetPlan, 
                    subscriptionStatus: 'active',
                    expiryDate: newExpiry
                 );
                 await repo.saveUserProfile(updatedUser);
                 print("MIGRATION: Legacy user granted expiry duration. Plan: $targetPlan");
              } catch (e) {
                 print("MIGRATION ERROR: $e");
              }
           });
           
           // Return "Active" with the CURRENT plan (or trial fallback) so UI updates immediately
           return SubscriptionState.active(user.plan.isNotEmpty ? user.plan : 'trial');
       }

       // 2. Time Expiration Check (Global Read-Only)
       if (now.isAfter(expiry)) {
          return SubscriptionState.expired(plan, "Trial Expired");
       }
       
       // 2. Quota Check (Plus Plan - 500 Item Limit)
       if (plan == 'plus') {
          // Use count query (cheap)
          final productRepo = ref.read(productRepositoryProvider);
          try {
             final count = await productRepo.productsCount();
             if (count >= 500) {
                return SubscriptionState.quotaReached(plan, "Plus Limit (500) Reached");
             }
          } catch (e) {
             print("Subscription Check Error: $e");
          }
       }
       
       return SubscriptionState.active(plan);
    },
    loading: () => SubscriptionState.active('loading'), 
    error: (e, st) => SubscriptionState.expired('error', 'Error loading subscription'),
  );
});

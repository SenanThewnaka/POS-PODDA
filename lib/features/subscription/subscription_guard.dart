import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/subscription/subscription_provider.dart';
import 'package:sme_buddy/features/subscription/upgrade_dialog.dart';

enum SubscriptionAction {
  write, // General Writes (Add Sale, Edit, Delete) -> Block if Expired
  addItem, // Add New Product -> Block if Expired OR Quota Reached
  manageTeam, // Pro Feature
  accessCreditBook, // Pro Feature
  viewAdvancedStats, // Pro Feature
}

class SubscriptionGuard {
  
  // Returns TRUE if allowed, FALSE if blocked (and shows dialog)
  static Future<bool> check(BuildContext context, WidgetRef ref, SubscriptionAction action) async {
      // 1. Get State (ReadSync if possible, but it's AsyncValue. 
      // We can take the current value if loaded, or wait? 
      // Waiting is safer for edge cases, but for UI responsiveness we might hope it's loaded.
      // Usually, subscriptionProvider is loaded on app start.
      
      final subStateAsync = ref.read(subscriptionProvider);
      
      if (subStateAsync.isLoading) {
         // Allow permissive fallback or show loading?
         // Permissive is risky logic, restrictive is safer.
         // Let's assume active if loading to prevent flicker blocks? 
         // Or just block.
         // Let's just block with "Loading..." toast if strict, or allow.
         // Requirement: "The app must locally check". 
         return true; // Optimistic allow while loading
      }
      
      if (subStateAsync.hasError) {
         // Fallback allow
         return true;
      }
      
      final state = subStateAsync.value!;
      
      // 1. Check Global Expiration (Read Only Mode)
      if (state.isReadOnly) {
         UpgradeDialog.show(context, reason: "Trial Expired");
         return false;
      }
      
      // 2. Check Specific Action Locks
      if (action == SubscriptionAction.addItem) {
         if (!state.canAddItems) {
            UpgradeDialog.show(context, reason: state.expirationReason ?? "Limit Reached");
            return false; 
         }
      }
      
      if (action == SubscriptionAction.manageTeam) {
        if (!state.canManageTeam) {
           UpgradeDialog.show(context, reason: "Team Management is a Business Plan feature.");
           return false;
        }
      }
      
      if (action == SubscriptionAction.accessCreditBook) {
        if (!state.canUseCredit) {
           UpgradeDialog.show(context, reason: "Credit Book is a Business Plan feature.");
           return false;
        }
      }
      
      if (action == SubscriptionAction.viewAdvancedStats) {
        if (!state.canViewAdvancedStats) {
           UpgradeDialog.show(context, reason: "Advanced Analytics is a Business Plan feature.");
           return false;
        }
      }
      
      // If we are here, 'write' is allowed (because isReadOnly is false)
      // and 'addItem' is allowed (because canAddItems is true).
      
      return true;
  }
}

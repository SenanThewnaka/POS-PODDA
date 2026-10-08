import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/subscription/subscription_provider.dart';
import 'package:sme_buddy/features/subscription/upgrade_dialog.dart';

enum SubscriptionAction {
  write, // General Writes (Add Sale, Edit, Delete) -> Block if Expired
  addItem, // Add New Product -> Block if Expired
  manageTeam, // Pro Feature
  accessCreditBook, // Pro Feature
  viewAdvancedStats, // Pro Feature
  useGRN, // Plus and Pro Feature
}

class SubscriptionGuard {
  static Future<bool> check(BuildContext context, WidgetRef ref, SubscriptionAction action) async {
    final subState = ref.read(subscriptionProvider);

    // 1. Check expiration for WRITES
    if ((action == SubscriptionAction.write || action == SubscriptionAction.addItem || action == SubscriptionAction.useGRN) && subState.isExpired) {
      _showUpgradeDialog(context, subState.expirationReason ?? "Your subscription has expired. Please renew to continue.");
      return false;
    }

    // 2. Check feature-level gating (Pro limits)
    if (action == SubscriptionAction.manageTeam && !subState.canManageTeam) {
      _showUpgradeDialog(context, "Update to Pro plan to activate Employee & Team Management features.");
      return false;
    }
    
    if (action == SubscriptionAction.accessCreditBook && !subState.canUseCredit) {
      _showUpgradeDialog(context, "Update to Pro plan to activate Customer Credit Book (ණය පොත).");
      return false;
    }

    if (action == SubscriptionAction.viewAdvancedStats && !subState.canViewAdvancedStats) {
      _showUpgradeDialog(context, "Update to Pro plan to activate Advanced Profit Analytics.");
      return false;
    }

    return true; // Allowed
  }

  static void _showUpgradeDialog(BuildContext context, String reason) {
    UpgradeDialog.show(context, reason: reason);
  }
}

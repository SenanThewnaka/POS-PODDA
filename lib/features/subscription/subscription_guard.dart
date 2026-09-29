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
  // App is completely free - all actions unconditionally allowed
  static Future<bool> check(BuildContext context, WidgetRef ref, SubscriptionAction action) async {
    return true;
  }
}

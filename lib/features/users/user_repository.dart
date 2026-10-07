import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';

final userProfileRepositoryProvider = Provider((ref) => UserProfileRepository());

// Stream of the CURRENT User's Profile
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);
  return ref.watch(userProfileRepositoryProvider).userProfileStream(authUser.uid);
});

// Stream of the SHOP Owner's Profile (for employees to inherit shop tier & settings)
final shopOwnerProfileProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value(null);
  if (user.shopId.isEmpty || user.shopId == user.uid) {
    return Stream.value(user);
  }
  try {
    return ref.watch(userProfileRepositoryProvider).userProfileStream(user.shopId);
  } catch (_) {
    return Stream.value(user);
  }
});

class UserProfileRepository {
  final CollectionReference _collection = FirebaseFirestore.instance.collection('users');

  // Stream a specific user's profile by UID with Instant Local Hydration
  Stream<UserModel?> userProfileStream(String uid) async* {
    // 1. Immediately emit cached profile from local storage (0ms loading time)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_user_profile_$uid');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final map = jsonDecode(cachedJson) as Map<String, dynamic>;
        yield UserModel.fromMap(map);
      }
    } catch (e) {
      if (kDebugMode) print('Local profile cache read note: $e');
    }

    // 2. Stream real-time updates from Firestore & refresh local cache
    await for (final snapshot in _collection.doc(uid).snapshots()) {
      if (!snapshot.exists) {
        yield null;
      } else {
        final profile = UserModel.fromMap(snapshot.data() as Map<String, dynamic>);
        unawaited(
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('cached_user_profile_$uid', jsonEncode(profile.toCacheMap()));
          }).catchError((_) {}),
        );
        yield profile;
      }
    }
  }

  // Create or Update User Profile
  Future<void> saveUserProfile(UserModel user) async {
    // Keep local cache up to date immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_profile_${user.uid}', jsonEncode(user.toCacheMap()));
    } catch (_) {}

    await _collection.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }
  
  // Deactivate User Profile (Soft Delete)
  // Keeps the record for audit, but prevents login via AuthGate
  Future<void> deactivateUserProfile(String uid) async {
    await _collection.doc(uid).update({'isActive': false});
  }

  // Reactivate User Profile
  Future<void> reactivateUserProfile(String uid) async {
    await _collection.doc(uid).update({'isActive': true});
  }
  
  // Fetch single profile once
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _collection.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  final CollectionReference _trialHistoryCollection = FirebaseFirestore.instance.collection('trial_history');

  /// Check if the specified email has already consumed a 14-day free trial or deleted an account
  Future<bool> checkEmailHasUsedTrial(String email) async {
    try {
      final normalized = email.trim().toLowerCase();
      final doc = await _trialHistoryCollection.doc(normalized).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      return (data['hasUsedTrial'] == true) || (data['accountDeleted'] == true);
    } catch (e) {
      if (kDebugMode) print('Trial history check note: $e');
      return false;
    }
  }

  /// Record that an email has been granted a 14-day free trial
  Future<void> recordTrialGranted(String email, {required String uid, required DateTime expiryDate}) async {
    try {
      final normalized = email.trim().toLowerCase();
      await _trialHistoryCollection.doc(normalized).set({
        'email': normalized,
        'uid': uid,
        'hasUsedTrial': true,
        'accountDeleted': false,
        'trialGrantedAt': FieldValue.serverTimestamp(),
        'trialExpiryDate': Timestamp.fromDate(expiryDate),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('Record trial granted note: $e');
    }
  }

  /// Mark email as having deleted their account so they cannot re-signup for a free trial
  Future<void> recordAccountDeleted(String email, String uid) async {
    try {
      final normalized = email.trim().toLowerCase();
      await _trialHistoryCollection.doc(normalized).set({
        'email': normalized,
        'uid': uid,
        'hasUsedTrial': true,
        'accountDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('Record account deleted note: $e');
    }
  }

  /// Ensures a user profile exists in Firestore for a Google-authenticated user.
  /// If the profile already exists, returns it without modifying existing shop data.
  /// If new user, checks trial history:
  ///   - If email already used trial: grants 'trial' with 'expired' status.
  ///   - If email is new: grants 14-day 'trial' with 'active' status and expiryDate = now + 14 days.
  Future<UserModel> ensureUserProfileForGoogle(User user) async {
    final existing = await getUserProfile(user.uid);
    if (existing != null) {
      return existing;
    }

    final email = user.email ?? '';
    final hasUsedTrial = email.isNotEmpty ? await checkEmailHasUsedTrial(email) : false;

    final displayName = (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : (email.contains('@') ? email.split('@').first : 'Shop Owner');

    final now = DateTime.now();
    final DateTime trialExpiryDate;
    final String subscriptionStatus;

    if (hasUsedTrial) {
      // Trial already consumed by this email in a previous account!
      trialExpiryDate = now.subtract(const Duration(days: 1));
      subscriptionStatus = 'expired';
    } else {
      // Legitimate brand-new user: grant full 14-day free trial!
      trialExpiryDate = now.add(const Duration(days: 14));
      subscriptionStatus = 'active';
    }

    final newProfile = UserModel(
      uid: user.uid,
      email: email,
      name: displayName,
      mobile: user.phoneNumber ?? '',
      role: 'owner',
      shopId: user.uid,
      shopName: "$displayName's Shop",
      plan: 'trial',
      subscriptionStatus: subscriptionStatus,
      billingCycle: 'trial',
      expiryDate: trialExpiryDate,
      isVerified: true,
      verificationCode: null,
      welcomeSent: false,
    );

    await saveUserProfile(newProfile);

    if (!hasUsedTrial && email.isNotEmpty) {
      await recordTrialGranted(email, uid: user.uid, expiryDate: trialExpiryDate);
    }

    return newProfile;
  }

  /// Delete user account permanently:
  /// 1. Updates trial_history to record accountDeleted
  /// 2. Marks profile as deleted and deactivated
  /// 3. Clears local preferences
  Future<void> deleteUserAccount({required UserModel user}) async {
    // 1. Mark in trial_history so this email cannot re-signup for a free trial
    if (user.email.isNotEmpty) {
      await recordAccountDeleted(user.email, user.uid);
    }

    // 2. Mark profile deleted and deactivate
    await _collection.doc(user.uid).set({
      'isActive': false,
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'shopCode': null,
      'storedPassword': null,
    }, SetOptions(merge: true));

    // 3. Clear local storage cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user_profile_${user.uid}');
    } catch (_) {}
  }

  // Get all employees for a specific shop
  Stream<List<UserModel>> getShopEmployees(String shopId) {
    return _collection
        .where('shopId', isEqualTo: shopId)
        // Optionally exclude the owner themselves if needed, but 'role' filter is better in UI
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
              .toList();
        });
  }

  // Cancel or expire a specific user's subscription (for testing or cancellation)
  Future<void> cancelSubscription(String uid) async {
    final pastDate = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1)));
    await _collection.doc(uid).update({
      'plan': 'trial',
      'currentPlan': 'trial',
      'subscriptionStatus': 'expired',
      'expiryDate': pastDate,
    });
  }

  // Reset all active user subscriptions to expired (for testing sandbox payments)
  Future<int> resetAllSubscriptionsForTesting() async {
    final query = await _collection.get();
    final batch = FirebaseFirestore.instance.batch();
    int count = 0;
    final pastDate = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1)));
    for (final doc in query.docs) {
      batch.update(doc.reference, {
        'plan': 'trial',
        'currentPlan': 'trial',
        'subscriptionStatus': 'expired',
        'expiryDate': pastDate,
      });
      count++;
    }
    if (count > 0) {
      await batch.commit();
    }
    return count;
  }
}

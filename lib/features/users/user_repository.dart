import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';

final userProfileRepositoryProvider = Provider((ref) => UserProfileRepository());

final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);
  return ref.watch(userProfileRepositoryProvider).userProfileStream(authUser.uid);
});

final shopOwnerProfileProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value(null);
  if (user.shopId.isEmpty || user.shopId == user.uid) return Stream.value(user);
  try {
    return ref.watch(userProfileRepositoryProvider).userProfileStream(user.shopId);
  } catch (_) {
    return Stream.value(user);
  }
});

class UserProfileRepository {
  final CollectionReference _collection = FirebaseFirestore.instance.collection('users');
  final CollectionReference _trialHistoryCollection = FirebaseFirestore.instance.collection('trial_history');

  Stream<UserModel?> userProfileStream(String uid) async* {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_user_profile_$uid');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final map = jsonDecode(cachedJson) as Map<String, dynamic>;
        final removedLegacyPassword = map.remove('storedPassword') != null;
        final removedLegacyVerificationCode = map.remove('verificationCode') != null;
        if (removedLegacyPassword || removedLegacyVerificationCode) {
          await prefs.setString('cached_user_profile_$uid', jsonEncode(map));
        }
        yield UserModel.fromMap(map);
      }
    } catch (e) {
      if (kDebugMode) print('Local profile cache read note: $e');
    }

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

  Future<void> saveUserProfile(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_profile_${user.uid}', jsonEncode(user.toCacheMap()));
    } catch (_) {}

    // Delete legacy plaintext employee passwords on the next legitimate profile write.
    final data = user.toMap();
    data['storedPassword'] = FieldValue.delete();
    data['verificationCode'] = FieldValue.delete();
    await _collection.doc(user.uid).set(data, SetOptions(merge: true));
  }

  Future<void> deactivateUserProfile(String uid) async {
    await _collection.doc(uid).update({'isActive': false});
  }

  Future<void> reactivateUserProfile(String uid) async {
    await _collection.doc(uid).update({'isActive': true});
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _collection.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  /// Returns true only for a recorded prior trial. Read failures propagate so callers cannot fail open.
  Future<bool> checkEmailHasUsedTrial(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) throw ArgumentError('A verified email address is required.');
    final doc = await _trialHistoryCollection.doc(normalized).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>?;
    return data != null && (data['hasUsedTrial'] == true || data['accountDeleted'] == true);
  }

  /// Creates a verified owner profile and claims the one-time trial in one transaction.
  /// Existing trial history results in an expired trial profile, never a fresh entitlement.
  Future<UserModel> createOwnerProfile({
    required String uid,
    required String email,
    required String name,
    required String mobile,
    required String shopName,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != uid || authUser.emailVerified != true || authUser.email == null) {
      throw StateError('Verify the account email before creating a shop profile.');
    }
    final normalizedEmail = authUser.email!.trim().toLowerCase();
    if (email.trim().toLowerCase() != normalizedEmail) {
      throw StateError('The profile email must match the verified account email.');
    }
    await authUser.getIdToken(true);

    final userRef = _collection.doc(uid);
    final historyRef = _trialHistoryCollection.doc(normalizedEmail);
    UserModel? result;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final existingProfile = await transaction.get(userRef);
      if (existingProfile.exists) {
        result = UserModel.fromMap(existingProfile.data() as Map<String, dynamic>);
        return;
      }
      final historySnapshot = await transaction.get(historyRef);
      final history = historySnapshot.data() as Map<String, dynamic>?;
      final hasUsedTrial = historySnapshot.exists &&
          (history?['hasUsedTrial'] == true || history?['accountDeleted'] == true);
      final now = DateTime.now();
      final expiry = hasUsedTrial ? now.subtract(const Duration(days: 1)) : now.add(const Duration(days: 14));

      final profile = UserModel(
        uid: uid,
        email: authUser.email!,
        name: name.trim(),
        mobile: mobile.trim(),
        role: 'owner',
        shopId: uid,
        shopName: shopName.trim(),
        plan: 'trial',
        subscriptionStatus: hasUsedTrial ? 'expired' : 'active',
        billingCycle: 'trial',
        expiryDate: expiry,
        isVerified: true,
      );
      transaction.set(userRef, profile.toMap());

      if (!hasUsedTrial) {
        transaction.set(historyRef, {
          'email': normalizedEmail,
          'uid': uid,
          'hasUsedTrial': true,
          'accountDeleted': false,
          'trialGrantedAt': FieldValue.serverTimestamp(),
          'trialExpiryDate': Timestamp.fromDate(expiry),
        });
      }
      result = profile;
    });

    final profile = result;
    if (profile == null) throw StateError('Shop profile creation did not complete.');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_profile_$uid', jsonEncode(profile.toCacheMap()));
    } catch (_) {}
    return profile;
  }

  /// Ensures a verified Google-authenticated user has an owner profile.
  Future<UserModel> ensureUserProfileForGoogle(User user) async {
    final existing = await getUserProfile(user.uid);
    if (existing != null) return existing;
    if (!user.emailVerified || user.email == null || user.email!.isEmpty) {
      throw StateError('Verify the Google account email before creating a shop profile.');
    }

    final email = user.email!;
    final displayName = (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : (email.contains('@') ? email.split('@').first : 'Shop Owner');
    return createOwnerProfile(
      uid: user.uid,
      email: email,
      name: displayName,
      mobile: user.phoneNumber ?? '',
      shopName: "$displayName's Shop",
    );
  }

  Future<void> setEmployeePassword({required String employeeUid, required String newPassword}) async {
    if (newPassword.length < 6 || newPassword.length > 1024) {
      throw ArgumentError('Password must be between 6 and 1024 characters.');
    }
    await FirebaseFunctions.instance.httpsCallable('setEmployeePassword').call({
      'employeeUid': employeeUid,
      'newPassword': newPassword,
    });
  }

  Future<int> cleanupLegacyEmployeePasswords() async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('cleanupLegacyEmployeePasswords')
        .call();
    final data = result.data;
    if (data is Map && data['removedCount'] is num) {
      return (data['removedCount'] as num).toInt();
    }
    return 0;
  }

  Future<void> recordAccountDeleted(String email, String uid) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final ref = _trialHistoryCollection.doc(normalized);
    final existing = await ref.get();
    if (existing.exists) {
      final data = existing.data() as Map<String, dynamic>?;
      // Another UID already consumed this email's trial; that record is sufficient.
      if (data?['uid'] != uid) return;
      await ref.update({
        'hasUsedTrial': true,
        'accountDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'email': normalized,
        'uid': uid,
        'hasUsedTrial': true,
        'accountDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> deleteUserAccount({required UserModel user}) async {
    if (user.email.isNotEmpty) await recordAccountDeleted(user.email, user.uid);

    await _collection.doc(user.uid).set({
      'isActive': false,
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'shopCode': null,
      'storedPassword': FieldValue.delete(),
      'verificationCode': FieldValue.delete(),
    }, SetOptions(merge: true));

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user_profile_${user.uid}');
    } catch (_) {}
  }

  Stream<List<UserModel>> getShopEmployees(String shopId) {
    return _collection.where('shopId', isEqualTo: shopId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }
}

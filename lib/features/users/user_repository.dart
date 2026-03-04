import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';

final userProfileRepositoryProvider = Provider((ref) => UserProfileRepository());

// Stream of the CURRENT User's Profile
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);
  return ref.watch(userProfileRepositoryProvider).userProfileStream(authUser.uid);
});

class UserProfileRepository {
  final CollectionReference _collection = FirebaseFirestore.instance.collection('users');

  // Stream a specific user's profile by UID
  Stream<UserModel?> userProfileStream(String uid) {
    return _collection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  // Create or Update User Profile
  Future<void> saveUserProfile(UserModel user) async {
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
}

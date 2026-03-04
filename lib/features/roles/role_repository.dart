import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/roles/role_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';

final roleRepositoryProvider = Provider<RoleRepository>((ref) {
  return RoleRepository(FirebaseFirestore.instance);
});

final shopRolesStreamProvider = StreamProvider.family<List<RoleModel>, String>((ref, shopId) {
  final repo = ref.watch(roleRepositoryProvider);
  return repo.getRolesStream(shopId);
});

class RoleRepository {
  final FirebaseFirestore _firestore;

  RoleRepository(this._firestore);

  // Get roles collection for a shop: shops/{shopId}/roles
  CollectionReference<Map<String, dynamic>> _rolesRef(String shopId) {
    return _firestore.collection('shops').doc(shopId).collection('roles');
  }

  Future<void> saveRole(RoleModel role) async {
    await _rolesRef(role.shopId).doc(role.id).set(role.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteRole(String shopId, String roleId) async {
    await _rolesRef(shopId).doc(roleId).delete();
  }

  Stream<List<RoleModel>> getRolesStream(String shopId) {
    return _rolesRef(shopId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => RoleModel.fromMap(doc.data(), doc.id)).toList();
    });
  }
}

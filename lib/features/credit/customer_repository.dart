import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/credit/customer_model.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';

import 'package:sme_buddy/features/users/user_repository.dart';

final customerRepositoryProvider = Provider((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null) {
     throw Exception("CustomerRepository accessed without user profile");
  }
  return CustomerRepository(userProfile.shopId);
});

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(customerRepositoryProvider).customersStream();
});

class CustomerRepository {
  final String userId;
  CustomerRepository(this.userId);

  CollectionReference get _collection => 
      FirebaseFirestore.instance.collection('users').doc(userId).collection('customers');

  Stream<List<Customer>> customersStream() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Customer.fromMap(data);
      }).toList();
    });
  }

  Future<void> addCustomer(String name, String mobile) async {
    final docRef = _collection.doc();
    final newCustomer = Customer(
      id: docRef.id,
      name: name,
      mobile: mobile,
    );
    await docRef.set(newCustomer.toMap());
  }

  Future<void> updateBalance(String customerId, double amountToAdd) async {
    // Replaced Transaction with Atomic Increment for stability
    final docRef = _collection.doc(customerId);
    await docRef.update({
      'currentBalance': FieldValue.increment(amountToAdd)
    });
  }

  Future<void> updateCustomer(String id, String name, String mobile) async {
    await _collection.doc(id).update({
      'name': name,
      'mobile': mobile,
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/inventory/stock_batch_model.dart';
import 'package:sme_buddy/features/procurement/supplier_model.dart';
import 'package:sme_buddy/features/procurement/grn_model.dart';

final procurementRepositoryProvider = Provider<ProcurementRepository>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null) {
    throw Exception("ProcurementRepository accessed without user profile");
  }
  return ProcurementRepository(userProfile);
});

final suppliersStreamProvider = StreamProvider<List<SupplierModel>>((ref) {
  return ref.watch(procurementRepositoryProvider).getSuppliersStream();
});

final grnListStreamProvider = StreamProvider<List<GRNModel>>((ref) {
  return ref.watch(procurementRepositoryProvider).getGRNListStream();
});

class ProcurementRepository {
  final UserModel currentUser;

  ProcurementRepository(this.currentUser);

  CollectionReference get _suppliersCollection => FirebaseFirestore.instance
      .collection('shops')
      .doc(currentUser.shopId)
      .collection('suppliers');

  CollectionReference get _grnCollection => FirebaseFirestore.instance
      .collection('shops')
      .doc(currentUser.shopId)
      .collection('grn');

  CollectionReference get _productsCollection => FirebaseFirestore.instance
      .collection('shops')
      .doc(currentUser.shopId)
      .collection('products');

  // Stream of active suppliers
  Stream<List<SupplierModel>> getSuppliersStream() {
    return _suppliersCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SupplierModel.fromMap(
                doc.data() as Map<String, dynamic>,
                id: doc.id,
              ))
          .toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  // Save / Update supplier
  Future<void> saveSupplier(SupplierModel supplier) async {
    final docRef = supplier.id.isEmpty
        ? _suppliersCollection.doc()
        : _suppliersCollection.doc(supplier.id);

    final toSave = supplier.copyWith(id: docRef.id);
    await docRef.set(toSave.toMap(), SetOptions(merge: true));
  }

  // Soft delete supplier
  Future<void> deleteSupplier(String supplierId) async {
    await _suppliersCollection.doc(supplierId).update({'isActive': false});
  }

  // Stream of Goods Received Notes (GRN)
  Stream<List<GRNModel>> getGRNListStream() {
    return _grnCollection
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GRNModel.fromMap(
                doc.data() as Map<String, dynamic>,
                id: doc.id,
              ))
          .toList();
    });
  }

  // Receive GRN & automatically increment stock and create batches
  Future<String> receiveGRN(GRNModel grn) async {
    final firestore = FirebaseFirestore.instance;
    final writeBatch = firestore.batch();

    final grnRef = grn.id.isEmpty ? _grnCollection.doc() : _grnCollection.doc(grn.id);
    final grnNumber = grn.grnNumber.isEmpty
        ? 'GRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'
        : grn.grnNumber;

    final updatedGrn = GRNModel(
      id: grnRef.id,
      shopId: currentUser.shopId,
      grnNumber: grnNumber,
      supplierId: grn.supplierId,
      supplierName: grn.supplierName,
      invoiceNumber: grn.invoiceNumber,
      receivedAt: grn.receivedAt,
      items: grn.items,
      totalCost: grn.totalCost,
      paymentStatus: grn.paymentStatus,
      amountPaid: grn.amountPaid,
      notes: grn.notes,
      receivedById: currentUser.uid,
      receivedByName: currentUser.name,
    );

    // 1. Save GRN document
    writeBatch.set(grnRef, updatedGrn.toMap());

    // 2. For each line item: Create new StockBatch and update Product currentStock & cost/selling prices
    for (final item in grn.items) {
      final productRef = _productsCollection.doc(item.productId);
      final batchRef = productRef.collection('batches').doc();

      final newBatch = StockBatch(
        id: batchRef.id,
        productId: item.productId,
        costPrice: item.unitCostPrice,
        sellingPrice: item.sellingPrice,
        currentStock: item.quantity,
        createdAt: DateTime.now(),
        isActive: true,
      );

      writeBatch.set(batchRef, newBatch.toMap());

      // Update product current stock, latest cost price, and latest selling price
      final Map<String, dynamic> productUpdate = {
        'currentStock': FieldValue.increment(item.quantity),
        'costPrice': item.unitCostPrice,
      };

      if (item.sellingPrice > 0) {
        productUpdate['sellingPrice'] = item.sellingPrice;
      }

      writeBatch.update(productRef, productUpdate);
    }

    await writeBatch.commit();
    return grnRef.id;
  }
}

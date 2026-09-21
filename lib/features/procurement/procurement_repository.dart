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
      .collection('users')
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

  // Get remaining stock of a specific batch
  Future<double?> getBatchRemainingStock(String productId, String batchId) async {
    if (batchId.isEmpty) return null;
    try {
      final doc = await _productsCollection
          .doc(productId)
          .collection('batches')
          .doc(batchId)
          .get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      return (data['currentStock'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  // Receive GRN & automatically increment stock and create batches
  Future<String> receiveGRN(GRNModel grn) async {
    final firestore = FirebaseFirestore.instance;
    final writeBatch = firestore.batch();

    final grnRef = grn.id.isEmpty ? _grnCollection.doc() : _grnCollection.doc(grn.id);
    final grnNumber = grn.grnNumber.isEmpty
        ? 'GRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'
        : grn.grnNumber;

    // 1. For each line item: Create new StockBatch and update Product currentStock & cost/selling prices
    final savedItems = <GRNItem>[];
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
      savedItems.add(item.copyWith(batchId: batchRef.id));

      // Update product current stock, latest cost price, and latest selling price
      final Map<String, dynamic> productUpdate = {
        'currentStock': FieldValue.increment(item.quantity),
        'costPrice': item.unitCostPrice,
      };

      if (item.sellingPrice > 0) {
        productUpdate['sellingPrice'] = item.sellingPrice;
      }

      writeBatch.set(productRef, productUpdate, SetOptions(merge: true));
    }

    final updatedGrn = GRNModel(
      id: grnRef.id,
      shopId: currentUser.shopId,
      grnNumber: grnNumber,
      supplierId: grn.supplierId,
      supplierName: grn.supplierName,
      invoiceNumber: grn.invoiceNumber,
      receivedAt: grn.receivedAt,
      items: savedItems,
      totalCost: grn.totalCost,
      paymentStatus: grn.paymentStatus,
      amountPaid: grn.amountPaid,
      notes: grn.notes,
      receivedById: currentUser.uid,
      receivedByName: currentUser.name,
    );

    // 2. Save GRN document
    writeBatch.set(grnRef, updatedGrn.toMap());

    await writeBatch.commit();
    return grnRef.id;
  }

  // Update an existing GRN with Batch Consumption Floor Guard
  Future<void> updateGRN(GRNModel updatedGrn, GRNModel originalGrn) async {
    final firestore = FirebaseFirestore.instance;
    final writeBatch = firestore.batch();
    final grnRef = _grnCollection.doc(originalGrn.id);

    // Map original items by batchId or productId for lookup
    final origItemMap = <String, GRNItem>{};
    for (final it in originalGrn.items) {
      final key = (it.batchId != null && it.batchId!.isNotEmpty) ? it.batchId! : it.productId;
      origItemMap[key] = it;
    }

    final finalItems = <GRNItem>[];
    final remainingKeysInOriginal = Set<String>.from(origItemMap.keys);

    // Process updated items
    for (final currItem in updatedGrn.items) {
      final key = (currItem.batchId != null && currItem.batchId!.isNotEmpty)
          ? currItem.batchId!
          : currItem.productId;

      if (origItemMap.containsKey(key)) {
        // Existing line item modified or kept
        remainingKeysInOriginal.remove(key);
        final origItem = origItemMap[key]!;
        final batchId = currItem.batchId ?? origItem.batchId ?? '';
        final productRef = _productsCollection.doc(currItem.productId);

        final deltaStock = currItem.quantity - origItem.quantity;

        if (deltaStock < 0) {
          // Quantity reduction requested -> Check Floor Guard
          final remainingStock = await getBatchRemainingStock(currItem.productId, batchId);
          if (remainingStock != null) {
            final unitsSold = (origItem.quantity - remainingStock).clamp(0.0, double.infinity);
            if (currItem.quantity < unitsSold - 0.0001) {
              final soldStr = unitsSold.toStringAsFixed(unitsSold % 1 == 0 ? 0 : 2);
              throw Exception(
                "Cannot reduce '${origItem.productName}' quantity below $soldStr. "
                "$soldStr units have already been sold from this batch.",
              );
            }
          }
        }

        // Apply batch update if batchId exists
        if (batchId.isNotEmpty) {
          final batchRef = productRef.collection('batches').doc(batchId);
          writeBatch.update(batchRef, {
            'currentStock': FieldValue.increment(deltaStock),
            'costPrice': currItem.unitCostPrice,
            if (currItem.sellingPrice > 0) 'sellingPrice': currItem.sellingPrice,
          });
        }

        // Apply product stock delta and pricing update
        final Map<String, dynamic> productUpdate = {
          'currentStock': FieldValue.increment(deltaStock),
          'costPrice': currItem.unitCostPrice,
        };
        if (currItem.sellingPrice > 0) {
          productUpdate['sellingPrice'] = currItem.sellingPrice;
        }
        writeBatch.set(productRef, productUpdate, SetOptions(merge: true));

        finalItems.add(currItem.copyWith(
          batchId: batchId,
          subTotal: currItem.quantity * currItem.unitCostPrice,
        ));
      } else {
        // Brand new line item added during edit
        final productRef = _productsCollection.doc(currItem.productId);
        final batchRef = productRef.collection('batches').doc();

        final newBatch = StockBatch(
          id: batchRef.id,
          productId: currItem.productId,
          costPrice: currItem.unitCostPrice,
          sellingPrice: currItem.sellingPrice,
          currentStock: currItem.quantity,
          createdAt: DateTime.now(),
          isActive: true,
        );

        writeBatch.set(batchRef, newBatch.toMap());

        final Map<String, dynamic> productUpdate = {
          'currentStock': FieldValue.increment(currItem.quantity),
          'costPrice': currItem.unitCostPrice,
        };
        if (currItem.sellingPrice > 0) {
          productUpdate['sellingPrice'] = currItem.sellingPrice;
        }
        writeBatch.set(productRef, productUpdate, SetOptions(merge: true));

        finalItems.add(currItem.copyWith(
          batchId: batchRef.id,
          subTotal: currItem.quantity * currItem.unitCostPrice,
        ));
      }
    }

    // Process removed items
    for (final removedKey in remainingKeysInOriginal) {
      final removedItem = origItemMap[removedKey]!;
      final batchId = removedItem.batchId ?? '';

      if (batchId.isNotEmpty) {
        final remainingStock = await getBatchRemainingStock(removedItem.productId, batchId);
        if (remainingStock != null) {
          final unitsSold = (removedItem.quantity - remainingStock).clamp(0.0, double.infinity);
          if (unitsSold > 0.0001) {
            final soldStr = unitsSold.toStringAsFixed(unitsSold % 1 == 0 ? 0 : 2);
            throw Exception(
              "Cannot remove '${removedItem.productName}'. "
              "$soldStr units have already been sold from this batch.",
            );
          }
        }

        // Units sold is 0: batch can be safely marked inactive / zeroed
        final batchRef = _productsCollection
            .doc(removedItem.productId)
            .collection('batches')
            .doc(batchId);
        writeBatch.update(batchRef, {
          'currentStock': 0.0,
          'isActive': false,
        });
      }

      // Revert product currentStock
      final productRef = _productsCollection.doc(removedItem.productId);
      writeBatch.set(productRef, {
        'currentStock': FieldValue.increment(-removedItem.quantity),
      }, SetOptions(merge: true));
    }

    final newTotalCost = finalItems.fold(0.0, (sum, it) => sum + it.subTotal);

    final toSaveGRN = updatedGrn.copyWith(
      id: originalGrn.id,
      shopId: originalGrn.shopId,
      grnNumber: originalGrn.grnNumber,
      items: finalItems,
      totalCost: newTotalCost,
      receivedAt: updatedGrn.receivedAt,
      receivedById: currentUser.uid,
      receivedByName: currentUser.name,
    );

    writeBatch.set(grnRef, toSaveGRN.toMap(), SetOptions(merge: true));
    await writeBatch.commit();
  }
}

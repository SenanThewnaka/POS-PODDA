import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/shifts/shift_model.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:uuid/uuid.dart';

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null) {
    throw Exception("ShiftRepository accessed without active user profile");
  }
  return ShiftRepository(userProfile);
});

final currentShiftProvider = StreamProvider<ShiftModel?>((ref) {
  final repo = ref.watch(shiftRepositoryProvider);
  return repo.currentShiftStream;
});

final shiftHistoryProvider = StreamProvider<List<ShiftModel>>((ref) {
  final repo = ref.watch(shiftRepositoryProvider);
  return repo.shiftHistoryStream;
});

class ShiftRepository {
  final UserModel currentUser;
  ShiftRepository(this.currentUser);

  CollectionReference get _collection => FirebaseFirestore.instance
      .collection('shops')
      .doc(currentUser.shopId)
      .collection('shifts');

  Stream<ShiftModel?> get currentShiftStream {
    return _collection
        .where('isOpen', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return ShiftModel.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  Stream<List<ShiftModel>> get shiftHistoryStream {
    return _collection
        .where('isOpen', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ShiftModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.openedAt.compareTo(a.openedAt));
      return list.take(60).toList();
    });
  }

  DocumentReference get _activeShiftLockRef => FirebaseFirestore.instance
      .collection('shops')
      .doc(currentUser.shopId)
      .collection('system')
      .doc('active_shift');

  Future<ShiftModel> openShift({
    required double openingFloat,
    String? notes,
  }) async {
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final lockSnap = await transaction.get(_activeShiftLockRef);
      if (lockSnap.exists) {
        final lockData = lockSnap.data() as Map<String, dynamic>?;
        final activeShiftId = lockData?['shiftId'] as String?;
        final isOpen = lockData?['isOpen'] as bool? ?? false;
        if (isOpen && activeShiftId != null && activeShiftId.isNotEmpty) {
          final shiftDocRef = _collection.doc(activeShiftId);
          final shiftSnap = await transaction.get(shiftDocRef);
          if (shiftSnap.exists) {
            final shiftData = shiftSnap.data() as Map<String, dynamic>;
            if (shiftData['isOpen'] == true) {
              return ShiftModel.fromMap(shiftData);
            }
          }
        }
      }

      // Check if open shift already exists in collection (fallback / legacy)
      final existing = await _collection.where('isOpen', isEqualTo: true).limit(1).get();
      if (existing.docs.isNotEmpty) {
        final existingDoc = existing.docs.first;
        transaction.set(_activeShiftLockRef, {
          'shiftId': existingDoc.id,
          'isOpen': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return ShiftModel.fromMap(existingDoc.data() as Map<String, dynamic>);
      }

      final docRef = _collection.doc();
      final shift = ShiftModel(
        id: docRef.id,
        shopId: currentUser.shopId,
        cashierId: currentUser.uid,
        cashierName: currentUser.name ?? currentUser.username ?? 'Cashier',
        openedAt: DateTime.now(),
        isOpen: true,
        openingFloat: openingFloat,
        notes: notes,
      );

      transaction.set(docRef, shift.toMap());
      transaction.set(_activeShiftLockRef, {
        'shiftId': docRef.id,
        'isOpen': true,
        'openedAt': FieldValue.serverTimestamp(),
      });
      return shift;
    });
  }

  Future<bool> addCashTransaction({
    required String type, // 'IN' or 'OUT'
    required double amount,
    required String reason,
  }) async {
    DocumentReference? docRef;
    try {
      final lockSnap = await _activeShiftLockRef.get();
      if (lockSnap.exists) {
        final lockData = lockSnap.data() as Map<String, dynamic>?;
        if (lockData?['isOpen'] == true && lockData?['shiftId'] != null) {
          docRef = _collection.doc(lockData!['shiftId'] as String);
        }
      }
    } catch (_) {}

    if (docRef == null) {
      final activeDocs = await _collection.where('isOpen', isEqualTo: true).limit(1).get();
      if (activeDocs.docs.isEmpty) return false;
      docRef = activeDocs.docs.first.reference;
    }

    final tx = CashDrawerTransaction(
      id: const Uuid().v4(),
      type: type,
      amount: amount,
      reason: reason,
      timestamp: DateTime.now(),
      cashierName: currentUser.name ?? currentUser.username ?? 'Cashier',
    );

    final isIn = type == 'IN';
    await docRef.update({
      'cashTransactions': FieldValue.arrayUnion([tx.toMap()]),
      if (isIn) 'cashInTotal': FieldValue.increment(amount),
      if (!isIn) 'cashOutTotal': FieldValue.increment(amount),
      'expectedCash': FieldValue.increment(isIn ? amount : -amount),
    });

    return true;
  }

  Future<void> recordSaleInActiveShift({
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      DocumentReference? docRef;
      try {
        final lockSnap = await _activeShiftLockRef.get();
        if (lockSnap.exists) {
          final lockData = lockSnap.data() as Map<String, dynamic>?;
          if (lockData?['isOpen'] == true && lockData?['shiftId'] != null) {
            docRef = _collection.doc(lockData!['shiftId'] as String);
          }
        }
      } catch (_) {}

      if (docRef == null) {
        final activeDocs = await _collection.where('isOpen', isEqualTo: true).limit(1).get();
        if (activeDocs.docs.isEmpty) {
          if (kDebugMode) print('ShiftRepository: No open shift found to record sale.');
          return;
        }
        docRef = activeDocs.docs.first.reference;
      }

      final isCash = paymentMethod == 'CASH';
      final isCard = paymentMethod == 'CARD';
      final isCredit = paymentMethod == 'CREDIT';

      final Map<String, dynamic> updates = {
        'totalSales': FieldValue.increment(amount),
        'transactionCount': FieldValue.increment(1),
      };

      if (isCash) {
        updates['cashSales'] = FieldValue.increment(amount);
        updates['expectedCash'] = FieldValue.increment(amount);
      } else if (isCard) {
        updates['cardSales'] = FieldValue.increment(amount);
      } else if (isCredit) {
        updates['creditSales'] = FieldValue.increment(amount);
      }

      await docRef.update(updates);
    } catch (e) {
      if (kDebugMode) print('ShiftRepository error recording sale in active shift: $e');
    }
  }

  Future<ShiftModel> closeShift({
    required String shiftId,
    required double actualCash,
    String? notes,
  }) async {
    final docRef = _collection.doc(shiftId);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      throw Exception("Shift not found: $shiftId");
    }

    final shift = ShiftModel.fromMap(docSnap.data() as Map<String, dynamic>);
    final double diff = actualCash - shift.expectedCash;
    final now = DateTime.now();

    final updated = shift.copyWith(
      isOpen: false,
      closedAt: now,
      actualCash: actualCash,
      notes: notes ?? shift.notes,
    );

    final batch = FirebaseFirestore.instance.batch();
    batch.update(docRef, {
      'isOpen': false,
      'closedAt': Timestamp.fromDate(now),
      'actualCash': actualCash,
      'difference': diff,
      'notes': notes ?? shift.notes,
    });
    batch.set(_activeShiftLockRef, {
      'shiftId': null,
      'isOpen': false,
      'closedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    await batch.commit();

    return updated;
  }

  Future<ShiftModel?> getShift(String shiftId) async {
    final doc = await _collection.doc(shiftId).get();
    if (!doc.exists) return null;
    return ShiftModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}

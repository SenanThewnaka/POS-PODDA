import 'package:cloud_firestore/cloud_firestore.dart';
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
        .orderBy('openedAt', descending: true)
        .limit(60)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<ShiftModel> openShift({
    required double openingFloat,
    String? notes,
  }) async {
    // Check if open shift already exists
    final existing = await _collection.where('isOpen', isEqualTo: true).limit(1).get();
    if (existing.docs.isNotEmpty) {
      return ShiftModel.fromMap(existing.docs.first.data() as Map<String, dynamic>);
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

    await docRef.set(shift.toMap());
    return shift;
  }

  Future<void> addCashTransaction({
    required String type, // 'IN' or 'OUT'
    required double amount,
    required String reason,
  }) async {
    final activeDocs = await _collection.where('isOpen', isEqualTo: true).limit(1).get();
    if (activeDocs.docs.isEmpty) return;

    final doc = activeDocs.docs.first;
    final shift = ShiftModel.fromMap(doc.data() as Map<String, dynamic>);

    final tx = CashDrawerTransaction(
      id: const Uuid().v4(),
      type: type,
      amount: amount,
      reason: reason,
      timestamp: DateTime.now(),
      cashierName: currentUser.name ?? currentUser.username ?? 'Cashier',
    );

    final updatedTxList = [...shift.cashTransactions, tx];
    final double updatedIn = shift.cashInTotal + (type == 'IN' ? amount : 0);
    final double updatedOut = shift.cashOutTotal + (type == 'OUT' ? amount : 0);

    await doc.reference.update({
      'cashTransactions': updatedTxList.map((x) => x.toMap()).toList(),
      'cashInTotal': updatedIn,
      'cashOutTotal': updatedOut,
      'expectedCash': shift.openingFloat + shift.cashSales + updatedIn - updatedOut,
    });
  }

  Future<void> recordSaleInActiveShift({
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      final activeDocs = await _collection.where('isOpen', isEqualTo: true).limit(1).get();
      if (activeDocs.docs.isEmpty) return;

      final doc = activeDocs.docs.first;
      final shift = ShiftModel.fromMap(doc.data() as Map<String, dynamic>);

      final isCash = paymentMethod == 'CASH';
      final isCard = paymentMethod == 'CARD';
      final isCredit = paymentMethod == 'CREDIT';

      final double newCash = shift.cashSales + (isCash ? amount : 0);
      final double newCard = shift.cardSales + (isCard ? amount : 0);
      final double newCredit = shift.creditSales + (isCredit ? amount : 0);
      final double newTotal = shift.totalSales + amount;
      final int newCount = shift.transactionCount + 1;

      await doc.reference.update({
        'cashSales': newCash,
        'cardSales': newCard,
        'creditSales': newCredit,
        'totalSales': newTotal,
        'transactionCount': newCount,
        'expectedCash': shift.openingFloat + newCash + shift.cashInTotal - shift.cashOutTotal,
      });
    } catch (e) {
      // Fire-and-forget: do not block sale if shift update encounters error
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

    await docRef.update({
      'isOpen': false,
      'closedAt': Timestamp.fromDate(now),
      'actualCash': actualCash,
      'difference': diff,
      'notes': notes ?? shift.notes,
    });

    return updated;
  }

  Future<ShiftModel?> getShift(String shiftId) async {
    final doc = await _collection.doc(shiftId).get();
    if (!doc.exists) return null;
    return ShiftModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}

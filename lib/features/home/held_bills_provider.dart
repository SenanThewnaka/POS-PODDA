import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:sme_buddy/features/home/cart_provider.dart';

class HeldBill {
  final String id;
  final DateTime createdAt;
  final Map<String, CartItem> items;
  final double totalAmount;
  final String? note;
  final String? customerName;

  HeldBill({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.totalAmount,
    this.note,
    this.customerName,
  });

  int get itemCount => items.values.fold(0, (sum, i) => sum + i.quantity.toInt());

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'items': items.map((k, v) => MapEntry(k, v.toMap())),
      'totalAmount': totalAmount,
      'note': note,
      'customerName': customerName,
    };
  }

  factory HeldBill.fromMap(Map<String, dynamic> map) {
    final itemsRaw = map['items'] as Map<String, dynamic>? ?? {};
    final items = itemsRaw.map(
      (k, v) => MapEntry(k, CartItem.fromMap(Map<String, dynamic>.from(v as Map))),
    );
    return HeldBill(
      id: map['id'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      items: items,
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      note: map['note'],
      customerName: map['customerName'],
    );
  }

  String toJson() => jsonEncode(toMap());
  factory HeldBill.fromJson(String source) => HeldBill.fromMap(jsonDecode(source));
}

class HeldBillsNotifier extends StateNotifier<List<HeldBill>> {
  static const String _storageKey = 'pos_held_bills_list_v1';

  HeldBillsNotifier() : super([]) {
    load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey);
      if (rawList != null) {
        state = rawList.map((str) => HeldBill.fromJson(str)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      // Ignore fallback
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = state.map((bill) => bill.toJson()).toList();
      await prefs.setStringList(_storageKey, stringList);
    } catch (e) {
      // Ignore fallback
    }
  }

  Future<HeldBill> holdCurrentCart({
    required Map<String, CartItem> items,
    required double totalAmount,
    String? note,
    String? customerName,
  }) async {
    final newBill = HeldBill(
      id: 'HELD-${const Uuid().v4().substring(0, 8).toUpperCase()}',
      createdAt: DateTime.now(),
      items: Map.from(items),
      totalAmount: totalAmount,
      note: note,
      customerName: customerName,
    );

    state = [newBill, ...state];
    await _save();
    return newBill;
  }

  Future<void> deleteHeldBill(String id) async {
    state = state.where((bill) => bill.id != id).toList();
    await _save();
  }

  Future<HeldBill?> resumeHeldBill(String id) async {
    final billIndex = state.indexWhere((bill) => bill.id == id);
    if (billIndex == -1) return null;
    final bill = state[billIndex];
    state = state.where((b) => b.id != id).toList();
    await _save();
    return bill;
  }

  Future<void> clearAll() async {
    state = [];
    await _save();
  }
}

final heldBillsProvider = StateNotifierProvider<HeldBillsNotifier, List<HeldBill>>((ref) {
  return HeldBillsNotifier();
});

import 'package:cloud_firestore/cloud_firestore.dart';

class CashDrawerTransaction {
  final String id;
  final String type; // 'IN' or 'OUT'
  final double amount;
  final String reason;
  final DateTime timestamp;
  final String? cashierName;

  CashDrawerTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.timestamp,
    this.cashierName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
      'cashierName': cashierName,
    };
  }

  factory CashDrawerTransaction.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return CashDrawerTransaction(
      id: map['id'] ?? '',
      type: map['type'] ?? 'IN',
      amount: (map['amount'] ?? 0.0).toDouble(),
      reason: map['reason'] ?? '',
      timestamp: parseTime(map['timestamp']),
      cashierName: map['cashierName'],
    );
  }
}

class ShiftModel {
  final String id;
  final String shopId;
  final String cashierId;
  final String cashierName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final bool isOpen;
  final double openingFloat;
  final double cashSales;
  final double cardSales;
  final double creditSales;
  final double totalSales;
  final int transactionCount;
  final double cashInTotal;
  final double cashOutTotal;
  final List<CashDrawerTransaction> cashTransactions;
  final double? actualCash;
  final String? notes;

  ShiftModel({
    required this.id,
    required this.shopId,
    required this.cashierId,
    required this.cashierName,
    required this.openedAt,
    this.closedAt,
    this.isOpen = true,
    this.openingFloat = 0.0,
    this.cashSales = 0.0,
    this.cardSales = 0.0,
    this.creditSales = 0.0,
    this.totalSales = 0.0,
    this.transactionCount = 0,
    this.cashInTotal = 0.0,
    this.cashOutTotal = 0.0,
    this.cashTransactions = const [],
    this.actualCash,
    this.notes,
  });

  double get expectedCash =>
      openingFloat + cashSales + cashInTotal - cashOutTotal;

  double? get difference =>
      actualCash != null ? actualCash! - expectedCash : null;

  bool get isBalanced => difference != null && difference!.abs() < 0.01;
  bool get isOver => difference != null && difference! > 0.01;
  bool get isShort => difference != null && difference! < -0.01;

  ShiftModel copyWith({
    String? id,
    String? shopId,
    String? cashierId,
    String? cashierName,
    DateTime? openedAt,
    DateTime? closedAt,
    bool? isOpen,
    double? openingFloat,
    double? cashSales,
    double? cardSales,
    double? creditSales,
    double? totalSales,
    int? transactionCount,
    double? cashInTotal,
    double? cashOutTotal,
    List<CashDrawerTransaction>? cashTransactions,
    double? actualCash,
    String? notes,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      isOpen: isOpen ?? this.isOpen,
      openingFloat: openingFloat ?? this.openingFloat,
      cashSales: cashSales ?? this.cashSales,
      cardSales: cardSales ?? this.cardSales,
      creditSales: creditSales ?? this.creditSales,
      totalSales: totalSales ?? this.totalSales,
      transactionCount: transactionCount ?? this.transactionCount,
      cashInTotal: cashInTotal ?? this.cashInTotal,
      cashOutTotal: cashOutTotal ?? this.cashOutTotal,
      cashTransactions: cashTransactions ?? this.cashTransactions,
      actualCash: actualCash ?? this.actualCash,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'openedAt': Timestamp.fromDate(openedAt),
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      'isOpen': isOpen,
      'openingFloat': openingFloat,
      'cashSales': cashSales,
      'cardSales': cardSales,
      'creditSales': creditSales,
      'totalSales': totalSales,
      'transactionCount': transactionCount,
      'cashInTotal': cashInTotal,
      'cashOutTotal': cashOutTotal,
      'cashTransactions': cashTransactions.map((x) => x.toMap()).toList(),
      'expectedCash': expectedCash,
      'actualCash': actualCash,
      'difference': difference,
      'notes': notes,
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    final rawTx = map['cashTransactions'] as List<dynamic>? ?? [];

    return ShiftModel(
      id: map['id'] ?? '',
      shopId: map['shopId'] ?? '',
      cashierId: map['cashierId'] ?? '',
      cashierName: map['cashierName'] ?? '',
      openedAt: parseTime(map['openedAt']),
      closedAt: map['closedAt'] != null ? parseTime(map['closedAt']) : null,
      isOpen: map['isOpen'] ?? false,
      openingFloat: (map['openingFloat'] ?? 0.0).toDouble(),
      cashSales: (map['cashSales'] ?? 0.0).toDouble(),
      cardSales: (map['cardSales'] ?? 0.0).toDouble(),
      creditSales: (map['creditSales'] ?? 0.0).toDouble(),
      totalSales: (map['totalSales'] ?? 0.0).toDouble(),
      transactionCount: (map['transactionCount'] ?? 0).toInt(),
      cashInTotal: (map['cashInTotal'] ?? 0.0).toDouble(),
      cashOutTotal: (map['cashOutTotal'] ?? 0.0).toDouble(),
      cashTransactions: rawTx
          .map((item) =>
              CashDrawerTransaction.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      actualCash: map['actualCash'] != null
          ? (map['actualCash'] as num).toDouble()
          : null,
      notes: map['notes'],
    );
  }
}

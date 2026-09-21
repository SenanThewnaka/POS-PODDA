import 'package:cloud_firestore/cloud_firestore.dart';

class GRNItem {
  final String productId;
  final String productName;
  final double quantity;
  final double unitCostPrice;
  final double sellingPrice;
  final double subTotal; // quantity * unitCostPrice
  final DateTime? expiryDate;
  final String? batchNumber;
  final String? batchId; // Link to StockBatch

  GRNItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCostPrice,
    required this.sellingPrice,
    required this.subTotal,
    this.expiryDate,
    this.batchNumber,
    this.batchId,
  });

  GRNItem copyWith({
    String? productId,
    String? productName,
    double? quantity,
    double? unitCostPrice,
    double? sellingPrice,
    double? subTotal,
    DateTime? expiryDate,
    String? batchNumber,
    String? batchId,
  }) {
    return GRNItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitCostPrice: unitCostPrice ?? this.unitCostPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      subTotal: subTotal ?? this.subTotal,
      expiryDate: expiryDate ?? this.expiryDate,
      batchNumber: batchNumber ?? this.batchNumber,
      batchId: batchId ?? this.batchId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitCostPrice': unitCostPrice,
      'sellingPrice': sellingPrice,
      'subTotal': subTotal,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'batchNumber': batchNumber,
      'batchId': batchId,
    };
  }

  factory GRNItem.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return GRNItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] ?? 0.0).toDouble(),
      unitCostPrice: (map['unitCostPrice'] ?? 0.0).toDouble(),
      sellingPrice: (map['sellingPrice'] ?? 0.0).toDouble(),
      subTotal: (map['subTotal'] ?? 0.0).toDouble(),
      expiryDate: parseDate(map['expiryDate']),
      batchNumber: map['batchNumber'],
      batchId: map['batchId'],
    );
  }
}

class GRNModel {
  final String id;
  final String shopId;
  final String grnNumber;
  final String? supplierId;
  final String? supplierName;
  final String? invoiceNumber;
  final DateTime receivedAt;
  final List<GRNItem> items;
  final double totalCost;
  final String paymentStatus; // 'PAID', 'CREDIT', 'PARTIAL'
  final double amountPaid;
  final String? notes;
  final String? receivedById;
  final String? receivedByName;

  GRNModel({
    required this.id,
    required this.shopId,
    required this.grnNumber,
    this.supplierId,
    this.supplierName,
    this.invoiceNumber,
    required this.receivedAt,
    this.items = const [],
    required this.totalCost,
    this.paymentStatus = 'PAID',
    this.amountPaid = 0.0,
    this.notes,
    this.receivedById,
    this.receivedByName,
  });

  GRNModel copyWith({
    String? id,
    String? shopId,
    String? grnNumber,
    String? supplierId,
    String? supplierName,
    String? invoiceNumber,
    DateTime? receivedAt,
    List<GRNItem>? items,
    double? totalCost,
    String? paymentStatus,
    double? amountPaid,
    String? notes,
    String? receivedById,
    String? receivedByName,
  }) {
    return GRNModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      grnNumber: grnNumber ?? this.grnNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      receivedAt: receivedAt ?? this.receivedAt,
      items: items ?? this.items,
      totalCost: totalCost ?? this.totalCost,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountPaid: amountPaid ?? this.amountPaid,
      notes: notes ?? this.notes,
      receivedById: receivedById ?? this.receivedById,
      receivedByName: receivedByName ?? this.receivedByName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'grnNumber': grnNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'invoiceNumber': invoiceNumber,
      'receivedAt': Timestamp.fromDate(receivedAt),
      'items': items.map((x) => x.toMap()).toList(),
      'totalCost': totalCost,
      'paymentStatus': paymentStatus,
      'amountPaid': amountPaid,
      'notes': notes,
      'receivedById': receivedById,
      'receivedByName': receivedByName,
    };
  }

  factory GRNModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return GRNModel(
      id: id ?? map['id'] ?? '',
      shopId: map['shopId'] ?? '',
      grnNumber: map['grnNumber'] ?? '',
      supplierId: map['supplierId'],
      supplierName: map['supplierName'],
      invoiceNumber: map['invoiceNumber'],
      receivedAt: parseTime(map['receivedAt']),
      items: List<GRNItem>.from(
        (map['items'] as List<dynamic>? ?? []).map<GRNItem>(
          (x) => GRNItem.fromMap(x as Map<String, dynamic>),
        ),
      ),
      totalCost: (map['totalCost'] ?? 0.0).toDouble(),
      paymentStatus: map['paymentStatus'] ?? 'PAID',
      amountPaid: (map['amountPaid'] ?? 0.0).toDouble(),
      notes: map['notes'],
      receivedById: map['receivedById'],
      receivedByName: map['receivedByName'],
    );
  }
}

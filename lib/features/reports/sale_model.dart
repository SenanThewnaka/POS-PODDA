import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItem {
  final String productId;
  final String productName;
  final double unitPrice; // Price at time of sale
  final double costPrice; // Cost at time of sale (for Profit calc)
  final double quantity;
  final double subTotal;
  final String? description;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.costPrice = 0.0,
    required this.quantity,
    required this.subTotal,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'unitPrice': unitPrice,
      'costPrice': costPrice,
      'quantity': quantity,
      'subTotal': subTotal,
      'description': description,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
      costPrice: (map['costPrice'] ?? 0.0).toDouble(),
      quantity: (map['quantity'] ?? 0.0).toDouble(),
      subTotal: (map['subTotal'] ?? 0.0).toDouble(),
      description: map['description'],
    );
  }
}

class Sale {
  final String id;
  final DateTime timestamp;
  final double totalAmount;
  final String paymentMethod; // CASH, CARD, CREDIT
  final String? customerId;
  final double amountPaid;
  final bool isFullyPaid;
  final List<SaleItem> items; // List of items sold
  final List<String> productIds; // For Querying: "Does this sale contain product X?"
  
  // Audit Trail
  final String? userId; // Who made the sale
  final String? userName;

  Sale({
    required this.id, 
    required this.timestamp, 
    required this.totalAmount, 
    required this.paymentMethod, 
    this.customerId,
    this.amountPaid = 0.0,
    this.isFullyPaid = true, // Default true for Cash/Card, False for Credit (handled in repo)
    this.items = const [],
    List<String>? productIds,
    this.userId,
    this.userName,
  }) : productIds = productIds ?? items.map((e) => e.productId).toList();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': Timestamp.fromDate(timestamp),
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'customerId': customerId,
      'amountPaid': amountPaid,
      'isFullyPaid': isFullyPaid,
      'items': items.map((x) => x.toMap()).toList(),
      'productIds': productIds,
      'userId': userId,
      'userName': userName,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now(); // Fallback
    }

    return Sale(
      id: map['id'] ?? '',
      timestamp: parseTimestamp(map['timestamp']),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? '',
      customerId: map['customerId'],
      amountPaid: (map['amountPaid'] ?? 0.0).toDouble(),
      isFullyPaid: map['isFullyPaid'] ?? false,
      items: List<SaleItem>.from(
        (map['items'] as List<dynamic>? ?? []).map<SaleItem>(
          (x) => SaleItem.fromMap(x as Map<String, dynamic>),
        ),
      ),
      productIds: List<String>.from(map['productIds'] ?? []),
      userId: map['userId'],
      userName: map['userName'],
    );
  }

  double get cashTendered => paymentMethod == 'CASH' ? amountPaid : totalAmount;
  double get changeDue => (amountPaid - totalAmount).clamp(0.0, double.infinity);

  Sale copyWith({
    String? id,
    DateTime? timestamp,
    double? totalAmount,
    String? paymentMethod,
    String? customerId,
    double? amountPaid,
    bool? isFullyPaid,
    List<SaleItem>? items,
    List<String>? productIds,
    String? userId,
    String? userName,
  }) {
    return Sale(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: customerId ?? this.customerId,
      amountPaid: amountPaid ?? this.amountPaid,
      isFullyPaid: isFullyPaid ?? this.isFullyPaid,
      items: items ?? this.items,
      productIds: productIds ?? this.productIds,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
    );
  }
}

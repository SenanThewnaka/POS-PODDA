class StockBatch {
  final String id;
  final String productId;
  final double costPrice;
  final double sellingPrice;
  final double currentStock;
  final DateTime createdAt;
  final bool isActive;

  StockBatch({
    required this.id,
    required this.productId,
    required this.costPrice,
    required this.sellingPrice,
    required this.currentStock,
    required this.createdAt,
    this.isActive = true,
  });

  StockBatch copyWith({
    String? id,
    String? productId,
    double? costPrice,
    double? sellingPrice,
    double? currentStock,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return StockBatch(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      currentStock: currentStock ?? this.currentStock,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'currentStock': currentStock,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }

  factory StockBatch.fromMap(Map<String, dynamic> map) {
    return StockBatch(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      costPrice: (map['costPrice'] ?? 0.0).toDouble(),
      sellingPrice: (map['sellingPrice'] ?? 0.0).toDouble(),
      currentStock: (map['currentStock'] ?? 0.0).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      isActive: map['isActive'] ?? true,
    );
  }
}

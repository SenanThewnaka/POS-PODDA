

class Product {
  final String id;
  final String name;
  final double sellingPrice;
  final double costPrice;
  final String stockType; // 'unit' | 'weight'
  final double currentStock;
  final String? baseUnit; // 'g', 'ml', 'cm' if measurable
  final List<BuyingOption> buyingOptions;
  final String? barcode;
  
  final String productType; // 'PHYSICAL', 'SERVICE'
  final bool isVariablePrice; // If true, prompt for price at checkout
  final double? lowStockThreshold; // Alert threshold
  final bool isActive; // Logic deletion logic
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.sellingPrice,
    this.costPrice = 0.0,
    this.stockType = 'unit',
    this.currentStock = 0.0,
    this.barcode,
    this.baseUnit,
    this.buyingOptions = const [],
    this.productType = 'PHYSICAL',
    this.isVariablePrice = false,
    this.lowStockThreshold,
    this.isActive = true,
    required this.createdAt,
  });

  Product copyWith({
    String? id,
    String? name,
    double? sellingPrice,
    double? costPrice,
    String? stockType,
    double? currentStock,
    String? barcode,
    String? baseUnit,
    List<BuyingOption>? buyingOptions,
    String? productType,
    bool? isVariablePrice,
    double? lowStockThreshold,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      costPrice: costPrice ?? this.costPrice,
      stockType: stockType ?? this.stockType,
      currentStock: currentStock ?? this.currentStock,
      barcode: barcode ?? this.barcode,
      baseUnit: baseUnit ?? this.baseUnit,
      buyingOptions: buyingOptions ?? this.buyingOptions,
      productType: productType ?? this.productType,
      isVariablePrice: isVariablePrice ?? this.isVariablePrice,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sellingPrice': sellingPrice,
      'costPrice': costPrice,
      'stockType': stockType,
      'currentStock': currentStock,
      'barcode': barcode,
      'baseUnit': baseUnit,
      'buyingOptions': buyingOptions.map((x) => x.toMap()).toList(),
      'productType': productType,
      'isVariablePrice': isVariablePrice,
      'lowStockThreshold': lowStockThreshold,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      sellingPrice: (map['sellingPrice'] ?? 0.0).toDouble(),
      costPrice: (map['costPrice'] ?? 0.0).toDouble(),
      stockType: map['stockType'] ?? 'unit',
      currentStock: (map['currentStock'] ?? 0.0).toDouble(),
      barcode: map['barcode'],
      baseUnit: map['baseUnit'],
      buyingOptions: List<BuyingOption>.from(
        (map['buyingOptions'] as List<dynamic>? ?? []).map<BuyingOption>(
          (x) => BuyingOption.fromMap(x as Map<String, dynamic>),
        ),
      ),
      productType: map['productType'] ?? 'PHYSICAL',
      isVariablePrice: map['isVariablePrice'] ?? false,
      lowStockThreshold: (map['lowStockThreshold'] as num?)?.toDouble(),
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['createdAt']) : DateTime.now(),
    );
  }
}

class BuyingOption {
  final String name; // e.g. "Sack (50kg)"
  final double quantityInBaseUnit; // e.g. 50000 (if base is g)

  BuyingOption({required this.name, required this.quantityInBaseUnit});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantityInBaseUnit': quantityInBaseUnit,
    };
  }

  factory BuyingOption.fromMap(Map<String, dynamic> map) {
    return BuyingOption(
      name: map['name'] ?? '',
      quantityInBaseUnit: (map['quantityInBaseUnit'] ?? 0.0).toDouble(),
    );
  }
}

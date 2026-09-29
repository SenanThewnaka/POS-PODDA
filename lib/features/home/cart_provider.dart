import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'dart:math';

class CartItem {
  final String id; // Unique ID (UUID)
  final Product product;
  final double quantity;
  final double effectivePrice; // Price after discount (or normal price)
  final double costPrice; // Cost per unit (defaults to product.costPrice, but can be overridden)
  final String? description; // Custom description (e.g. "Reload - 077...")

  CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.effectivePrice,
    required this.costPrice,
    this.description,
  });

  double get subTotal => quantity * effectivePrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product': product.toMap(),
      'quantity': quantity,
      'effectivePrice': effectivePrice,
      'costPrice': costPrice,
      'description': description,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] ?? '',
      product: Product.fromMap(Map<String, dynamic>.from(map['product'] as Map)),
      quantity: (map['quantity'] ?? 1.0).toDouble(),
      effectivePrice: (map['effectivePrice'] ?? 0.0).toDouble(),
      costPrice: (map['costPrice'] ?? 0.0).toDouble(),
      description: map['description'],
    );
  }
}

// Key: CartItem ID (Unique), Value: CartItem
final cartProvider = StateNotifierProvider<CartNotifier, Map<String, CartItem>>((ref) {
  return CartNotifier();
});

// Computed Total Price
final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  double total = 0;
  cart.forEach((id, item) {
    total += item.subTotal;
  });
  return total;
});

// Computed Total Item Count (units)
final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.length; 
});

class CartNotifier extends StateNotifier<Map<String, CartItem>> {
  CartNotifier() : super({});

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString();
  }

  void addToCart(Product product, {double quantity = 1, double? overridePrice, double? overrideCostPrice, String? description}) {
    state = {...state};
    
    final priceToUse = overridePrice ?? product.sellingPrice;
    final costToUse = overrideCostPrice ?? product.costPrice;
    
    // Check if an IDENTICAL item exists (Product + Price + Description match)
    // We iterate existing items to find a match.
    // Exception: If product is SERVICE, and user wants distinct items, they might provide different descriptions?
    // If description is same and price is same, we merge.
    
    String? existingKey;
    
    for (var entry in state.entries) {
      final item = entry.value;
      if (item.product.id == product.id) {
         // Potential match. Check specific attributes.
         // 1. Price match (allowing small float diff)
         bool priceMatch = (item.effectivePrice - priceToUse).abs() < 0.01;
         // 2. Cost match (allowing small float diff) - Variable services need distinct costs
         bool costMatch = (item.costPrice - costToUse).abs() < 0.01;
         // 3. Description match
         bool descMatch = item.description == description;
         
         if (priceMatch && costMatch && descMatch) {
           existingKey = entry.key;
           break;
         }
      }
    }

    if (existingKey != null) {
      // MERGE: Update quantity
      final currentItem = state[existingKey]!;
      state[existingKey] = CartItem(
        id: currentItem.id,
        product: product, 
        quantity: currentItem.quantity + quantity,
        effectivePrice: currentItem.effectivePrice,
        costPrice: currentItem.costPrice,
        description: currentItem.description,
      );
    } else {
      // NEW ENTRY
      final newId = _generateId();
      state[newId] = CartItem(
        id: newId,
        product: product, 
        quantity: quantity,
        effectivePrice: priceToUse,
        costPrice: costToUse,
        description: description,
      );
    }
  }

  // Update Quantity by CartItemID
  void updateQuantity(String cartItemId, double quantity) {
    state = {...state};
     if (state.containsKey(cartItemId)) {
       final current = state[cartItemId]!;
       if (quantity <= 0) {
         state.remove(cartItemId);
       } else {
         state[cartItemId] = CartItem(
           id: current.id,
           product: current.product,
           quantity: quantity,
           effectivePrice: current.effectivePrice,
           costPrice: current.costPrice,
           description: current.description,
         );
       }
     }
  }
  
  // Update Price/Description logic (from Edit Sheet)
  void updateItemDetails(String cartItemId, {double? newPrice, String? newDescription, double? newQuantity}) {
    state = {...state};
    if (state.containsKey(cartItemId)) {
      final current = state[cartItemId]!;
      state[cartItemId] = CartItem(
        id: current.id,
        product: current.product,
        quantity: newQuantity ?? current.quantity,
        effectivePrice: newPrice ?? current.effectivePrice,
        costPrice: current.costPrice, // Preserve cost
        description: newDescription ?? current.description,
      );
    }
  }

  void removeFromCart(String cartItemId) {
    state = {...state};
    state.remove(cartItemId);
  }

  void clearCart() {
    state = {};
  }

  void replaceCart(Map<String, CartItem> newCart) {
    state = Map.from(newCart);
  }
}

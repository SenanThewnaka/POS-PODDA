import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sme_buddy/features/home/cart_provider.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/utils/quantity_parser.dart';
import 'package:sme_buddy/utils/unit_formatter.dart';

// Helper to build a test product
Product _makeProduct({
  String id = 'p1',
  String name = 'Test Item',
  double price = 100.0,
  double cost = 60.0,
  double stock = 10.0,
}) {
  return Product(
    id: id,
    name: name,
    sellingPrice: price,
    costPrice: cost,
    currentStock: stock,
    stockType: 'unit',
    productType: 'PHYSICAL',
    isActive: true,
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  // ─── CartItem ──────────────────────────────────────────────────────────────

  group('CartItem.subTotal', () {
    test('calculates correctly for whole numbers', () {
      final product = _makeProduct(price: 150.0);
      final item = CartItem(
        id: '1',
        product: product,
        quantity: 3,
        effectivePrice: 150.0,
        costPrice: 60.0,
      );
      expect(item.subTotal, 450.0);
    });

    test('calculates correctly for fractional quantities (weight)', () {
      final product = _makeProduct(price: 200.0);
      final item = CartItem(
        id: '1',
        product: product,
        quantity: 0.5,
        effectivePrice: 200.0,
        costPrice: 100.0,
      );
      expect(item.subTotal, 100.0);
    });

    test('effectivePrice overrides product selling price', () {
      final product = _makeProduct(price: 100.0);
      final item = CartItem(
        id: '1',
        product: product,
        quantity: 2,
        effectivePrice: 90.0, // discounted price
        costPrice: 60.0,
      );
      // Subtotal should use effectivePrice (90), not product.sellingPrice (100)
      expect(item.subTotal, 180.0);
    });
  });

  // ─── CartNotifier ──────────────────────────────────────────────────────────

  group('CartNotifier.addToCart', () {
    late ProviderContainer container;
    late CartNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(cartProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('adds a new item to an empty cart', () {
      final product = _makeProduct();
      notifier.addToCart(product, quantity: 1);

      expect(container.read(cartProvider).length, 1);
    });

    test('merges identical items (same product + price + description)', () {
      final product = _makeProduct();
      notifier.addToCart(product, quantity: 1);
      notifier.addToCart(product, quantity: 2);

      final cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart.values.first.quantity, 3.0);
    });

    test('does NOT merge items with different effective prices', () {
      final product = _makeProduct();
      notifier.addToCart(product, quantity: 1, overridePrice: 100.0);
      notifier.addToCart(product, quantity: 1, overridePrice: 90.0); // discount

      expect(container.read(cartProvider).length, 2);
    });

    test('does NOT merge items with different descriptions (custom services)', () {
      final product = _makeProduct(id: 'svc', name: 'Reload');
      notifier.addToCart(product, quantity: 1, description: 'Reload - 077xxx');
      notifier.addToCart(product, quantity: 1, description: 'Reload - 078xxx');

      expect(container.read(cartProvider).length, 2);
    });

    test('uses override price when provided', () {
      final product = _makeProduct(price: 100.0);
      notifier.addToCart(product, quantity: 1, overridePrice: 75.0);

      expect(container.read(cartProvider).values.first.effectivePrice, 75.0);
    });

    test('uses product price when no override', () {
      final product = _makeProduct(price: 100.0);
      notifier.addToCart(product, quantity: 1);

      expect(container.read(cartProvider).values.first.effectivePrice, 100.0);
    });
  });

  group('CartNotifier.updateQuantity', () {
    late ProviderContainer container;
    late CartNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(cartProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('updates quantity of an existing item', () {
      final product = _makeProduct();
      notifier.addToCart(product, quantity: 1);
      final itemId = container.read(cartProvider).keys.first;

      notifier.updateQuantity(itemId, 5);
      expect(container.read(cartProvider)[itemId]!.quantity, 5.0);
    });

    test('removes item when quantity set to 0', () {
      final product = _makeProduct();
      notifier.addToCart(product, quantity: 2);
      final itemId = container.read(cartProvider).keys.first;

      notifier.updateQuantity(itemId, 0);
      expect(container.read(cartProvider).isEmpty, true);
    });

    test('removes item when quantity is negative', () {
      final product = _makeProduct();
      notifier.addToCart(product, quantity: 2);
      final itemId = container.read(cartProvider).keys.first;

      notifier.updateQuantity(itemId, -1);
      expect(container.read(cartProvider).isEmpty, true);
    });
  });

  group('CartNotifier.removeFromCart', () {
    late ProviderContainer container;
    late CartNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(cartProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('removes the correct item', () {
      final p1 = _makeProduct(id: 'p1');
      final p2 = _makeProduct(id: 'p2', name: 'Other');
      notifier.addToCart(p1);
      notifier.addToCart(p2);

      final keyToRemove = container.read(cartProvider)
          .entries
          .firstWhere((e) => e.value.product.id == 'p1')
          .key;
      notifier.removeFromCart(keyToRemove);

      expect(container.read(cartProvider).length, 1);
      expect(container.read(cartProvider).values.first.product.id, 'p2');
    });
  });

  group('CartNotifier.clearCart', () {
    late ProviderContainer container;
    late CartNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(cartProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('empties the entire cart', () {
      notifier.addToCart(_makeProduct(id: 'p1'));
      notifier.addToCart(_makeProduct(id: 'p2', name: 'B'));
      notifier.addToCart(_makeProduct(id: 'p3', name: 'C'));
      expect(container.read(cartProvider).length, 3);

      notifier.clearCart();
      expect(container.read(cartProvider).isEmpty, true);
    });
  });

  // ─── Derived Providers ─────────────────────────────────────────────────────

  group('cartTotalProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('returns 0 for an empty cart', () {
      expect(container.read(cartTotalProvider), 0.0);
    });

    test('sums all item subtotals correctly', () {
      final notifier = container.read(cartProvider.notifier);
      notifier.addToCart(_makeProduct(id: 'p1', price: 100), quantity: 2); // 200
      notifier.addToCart(_makeProduct(id: 'p2', name: 'B', price: 50), quantity: 3); // 150

      expect(container.read(cartTotalProvider), 350.0);
    });

    test('updates total after removing an item', () {
      final notifier = container.read(cartProvider.notifier);
      notifier.addToCart(_makeProduct(id: 'p1', price: 100), quantity: 2);
      notifier.addToCart(_makeProduct(id: 'p2', name: 'B', price: 50), quantity: 1);

      final removeKey = container.read(cartProvider)
          .entries
          .firstWhere((e) => e.value.product.id == 'p1')
          .key;
      container.read(cartProvider.notifier).removeFromCart(removeKey);

      expect(container.read(cartTotalProvider), 50.0);
    });

    test('respects discounted effective prices in total', () {
      final notifier = container.read(cartProvider.notifier);
      // Product costs Rs. 100 but sold at Rs. 80 discount
      notifier.addToCart(_makeProduct(price: 100), quantity: 2, overridePrice: 80.0);

      expect(container.read(cartTotalProvider), 160.0); // NOT 200
    });
  });

  group('cartItemCountProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('returns 0 for empty cart', () {
      expect(container.read(cartItemCountProvider), 0);
    });

    test('returns number of distinct line items (not units)', () {
      final notifier = container.read(cartProvider.notifier);
      // 1 product added with quantity 5 = 1 line item
      notifier.addToCart(_makeProduct(id: 'p1'), quantity: 5);
      // 1 different product = another line item
      notifier.addToCart(_makeProduct(id: 'p2', name: 'B'));

      expect(container.read(cartItemCountProvider), 2);
    });
  });

  // ─── Measurable & Variable Quantity Parsing & Formatting ──────────────────

  group('QuantityParser & UnitFormatter for Measurable Products', () {
    test('TC-QP-01: Parses weight input for baseUnit "kg"', () {
      expect(QuantityParser.parse('500g', 'kg'), 0.5);
      expect(QuantityParser.parse('1kg 500g', 'kg'), 1.5);
      expect(QuantityParser.parse('2kg', 'kg'), 2.0);
      expect(QuantityParser.parse('250g', 'kg'), 0.25);
      expect(QuantityParser.parse('0.5', 'kg'), 0.5);
      expect(QuantityParser.parse('1.5', 'kg'), 1.5);
    });

    test('TC-QP-02: Parses weight input for baseUnit "g"', () {
      expect(QuantityParser.parse('500g', 'g'), 500.0);
      expect(QuantityParser.parse('1kg', 'g'), 1000.0);
      expect(QuantityParser.parse('1kg 500g', 'g'), 1500.0);
      expect(QuantityParser.parse('1.5', 'g'), 1500.0);
    });

    test('TC-QP-03: Parses volume input for baseUnit "l" and "ml"', () {
      expect(QuantityParser.parse('500ml', 'l'), 0.5);
      expect(QuantityParser.parse('1l 250ml', 'l'), 1.25);
      expect(QuantityParser.parse('250ml', 'ml'), 250.0);
      expect(QuantityParser.parse('1.5l', 'ml'), 1500.0);
    });

    test('TC-QP-04: UnitFormatter formats quantities for kg and g', () {
      expect(UnitFormatter.format(0.5, 'kg'), '500g');
      expect(UnitFormatter.format(1.5, 'kg'), '1kg 500g');
      expect(UnitFormatter.format(10.0, 'kg'), '10kg');
      expect(UnitFormatter.format(500.0, 'g'), '500g');
      expect(UnitFormatter.format(1500.0, 'g'), '1kg 500g');
      expect(UnitFormatter.format(0.25, 'l'), '250ml');
      expect(UnitFormatter.format(1.5, 'l'), '1L 500ml');
    });

    test('TC-QP-05: Cart calculations with baseUnit "kg" product when customer enters 500g', () {
      final product = Product(
        id: 'sugar-kg-1',
        name: 'White Sugar',
        sellingPrice: 300.0, // Rs. 300 per kg
        costPrice: 200.0,
        currentStock: 10.0, // 10 kg
        stockType: 'weight',
        baseUnit: 'kg',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

      final parsedQty = QuantityParser.parse('500g', product.baseUnit);
      expect(parsedQty, 0.5); // 0.5 kg

      final cartItem = CartItem(
        id: 'cart-1',
        product: product,
        quantity: parsedQty,
        effectivePrice: product.sellingPrice, // 300.0
        costPrice: product.costPrice,
      );

      // Price for 500g of sugar at Rs. 300/kg should be exactly Rs. 150.00
      expect(cartItem.subTotal, 150.0);
    });
  });
}

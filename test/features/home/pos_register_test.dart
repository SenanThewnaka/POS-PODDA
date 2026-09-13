import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sme_buddy/features/checkout/checkout_screen.dart';
import 'package:sme_buddy/features/home/cart_provider.dart';
import 'package:sme_buddy/features/home/home_screen.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/inventory/stock_batch_model.dart';
import 'package:sme_buddy/features/shifts/shift_model.dart';
import 'package:sme_buddy/features/shifts/shift_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';

class FakeProductRepository implements ProductRepository {
  final List<Product> _products;
  FakeProductRepository(this._products);

  @override
  String get userId => 'shop_123';

  @override
  Stream<List<Product>> productsStream() => Stream.value(_products);

  @override
  Future<List<StockBatch>> getPosBatches(String productId) async => [];

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    final matches = _products.where((p) => p.barcode == barcode && p.isActive);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _testProducts = [
  Product(
    id: 'prod_bread',
    name: 'White Bread 450g',
    sellingPrice: 180.0,
    costPrice: 140.0,
    stockType: 'unit',
    currentStock: 25.0,
    lowStockThreshold: 5.0,
    barcode: '8901234567890',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  ),
  Product(
    id: 'prod_sugar',
    name: 'White Sugar',
    sellingPrice: 0.28, // 280 / kg -> 0.28 / g
    costPrice: 0.22,
    stockType: 'weight',
    baseUnit: 'g',
    currentStock: 3000.0, // 3 kg
    lowStockThreshold: 1000.0,
    barcode: '8909999999999',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  ),
  Product(
    id: 'prod_service',
    name: 'Mobile Phone Reload',
    sellingPrice: 0.0,
    costPrice: 0.0,
    stockType: 'service',
    productType: 'SERVICE',
    isVariablePrice: true,
    currentStock: 999.0,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  ),
  Product(
    id: 'prod_low_stock',
    name: 'Highland Butter 200g',
    sellingPrice: 750.0,
    costPrice: 620.0,
    stockType: 'unit',
    currentStock: 3.0, // Below threshold 5 -> Low stock!
    lowStockThreshold: 5.0,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  ),
  Product(
    id: 'prod_out_of_stock',
    name: 'Fresh Milk 1L',
    sellingPrice: 420.0,
    costPrice: 350.0,
    stockType: 'unit',
    currentStock: 0.0, // Out of stock!
    lowStockThreshold: 5.0,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  ),
  Product(
    id: 'prod_inactive',
    name: 'Discontinued Item',
    sellingPrice: 50.0,
    costPrice: 30.0,
    stockType: 'unit',
    currentStock: 10.0,
    isActive: false, // Inactive / Deactivated
    createdAt: DateTime(2026, 1, 1),
  ),
];

final _testShift = ShiftModel(
  id: 'shift_1',
  shopId: 'shop_123',
  cashierId: 'user_1',
  cashierName: 'Senan Cashier',
  openedAt: DateTime.now(),
  openingFloat: 5000.0,
  cashSales: 1500.0,
  cardSales: 0.0,
  creditSales: 0.0,
  cashInTotal: 0.0,
  cashOutTotal: 0.0,
  isOpen: true,
);

final _testUser = UserModel(
  uid: 'user_1',
  email: 'senan@pos.lk',
  name: 'Senan',
  mobile: '0771234567',
  role: 'owner',
  shopId: 'shop_123',
  shopName: 'Podda Supermart',
  isActive: true,
);

Widget _createTestWidget({
  List<Product>? products,
  ShiftModel? shift,
  UserModel? user,
  CartNotifier? cartNotifier,
}) {
  final catalog = products ?? _testProducts;
  final fakeRepo = FakeProductRepository(catalog);

  return ProviderScope(
    overrides: [
      productsStreamProvider.overrideWith((ref) => Stream.value(catalog)),
      currentShiftProvider.overrideWith((ref) => Stream.value(shift ?? _testShift)),
      userProfileProvider.overrideWith((ref) => Stream.value(user ?? _testUser)),
      productRepositoryProvider.overrideWithValue(fakeRepo),
      if (cartNotifier != null)
        cartProvider.overrideWith((ref) => cartNotifier),
    ],
    child: const MaterialApp(
      home: HomeScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Category A: Catalog Search, Filters & Stock Indicators', () {
    testWidgets('TC-POS-01: Real-time search by name filters catalog', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      // Initially all active items are shown
      expect(find.text('White Bread 450g'), findsOneWidget);
      expect(find.text('White Sugar'), findsOneWidget);

      // Search for "Bread"
      await tester.enterText(find.byType(TextField).first, 'Bread');
      await tester.pumpAndSettle();

      expect(find.text('White Bread 450g'), findsOneWidget);
      expect(find.text('White Sugar'), findsNothing);
    });

    testWidgets('TC-POS-02: Barcode search matches item', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '8901234567890');
      await tester.pumpAndSettle();

      expect(find.text('White Bread 450g'), findsOneWidget);
      expect(find.text('White Sugar'), findsNothing);
    });

    testWidgets('TC-POS-03: Empty catalog shows clear message', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'NonExistentItem999');
      await tester.pumpAndSettle();

      expect(find.text('No items found for All'), findsOneWidget);
    });

    testWidgets('TC-POS-04: Type category filtering works correctly', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      // Tap 'Measurable' filter chip
      await tester.tap(find.text('Measurable'));
      await tester.pumpAndSettle();

      expect(find.text('White Sugar'), findsOneWidget);
      expect(find.text('White Bread 450g'), findsNothing);

      // Tap 'Service' filter chip
      await tester.ensureVisible(find.text('Service'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();

      expect(find.text('Mobile Phone Reload'), findsOneWidget);
      expect(find.text('White Sugar'), findsNothing);
    });

    testWidgets('TC-POS-05: Inactive products are completely hidden from POS', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Discontinued Item'), findsNothing);
    });

    testWidgets('TC-POS-06: Stock level indicators display correctly', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      // Normal stock (Bread: 25)
      expect(find.text('Stock: 25 Units'), findsOneWidget);
      // Low stock (Butter: 3)
      expect(find.text('Low: 3 Units'), findsOneWidget);
      // Out of stock (Milk: 0)
      expect(find.text('Out of Stock'), findsOneWidget);
    });

    testWidgets('TC-POS-07: Unit price scales automatically (g to kg)', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      // Sugar price 0.28/g scaled to 280/kg
      expect(find.text('Rs. 280/kg'), findsOneWidget);
    });
  });

  group('Category B: Cart State & Line Item Mutations', () {
    test('TC-POS-08: Add standard unit item to cart', () {
      final container = ProviderContainer();
      final product = _testProducts[0]; // Bread

      container.read(cartProvider.notifier).addToCart(product, quantity: 1);

      final cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart.values.first.product.name, 'White Bread 450g');
      expect(cart.values.first.quantity, 1);
      expect(container.read(cartTotalProvider), 180.0);
    });

    test('TC-POS-09: Merge identical items in cart', () {
      final container = ProviderContainer();
      final product = _testProducts[0]; // Bread

      container.read(cartProvider.notifier).addToCart(product, quantity: 1);
      container.read(cartProvider.notifier).addToCart(product, quantity: 2);

      final cart = container.read(cartProvider);
      expect(cart.length, 1); // Single merged entry
      expect(cart.values.first.quantity, 3);
      expect(container.read(cartTotalProvider), 540.0);
    });

    test('TC-POS-10: Custom notes isolate items into distinct lines', () {
      final container = ProviderContainer();
      final service = _testProducts[2]; // Reload

      container.read(cartProvider.notifier).addToCart(
        service,
        overridePrice: 500.0,
        description: '0771234567',
      );
      container.read(cartProvider.notifier).addToCart(
        service,
        overridePrice: 500.0,
        description: '0719876543',
      );

      final cart = container.read(cartProvider);
      expect(cart.length, 2); // Two separate lines due to different descriptions
      expect(container.read(cartTotalProvider), 1000.0);
    });

    test('TC-POS-11: Inline stepper increment increases quantity and total', () {
      final container = ProviderContainer();
      final product = _testProducts[0];

      container.read(cartProvider.notifier).addToCart(product, quantity: 1);
      final itemId = container.read(cartProvider).keys.first;

      container.read(cartProvider.notifier).updateQuantity(itemId, 2);

      expect(container.read(cartProvider)[itemId]!.quantity, 2);
      expect(container.read(cartTotalProvider), 360.0);
    });

    test('TC-POS-12: Inline stepper decrement decreases quantity', () {
      final container = ProviderContainer();
      final product = _testProducts[0];

      container.read(cartProvider.notifier).addToCart(product, quantity: 2);
      final itemId = container.read(cartProvider).keys.first;

      container.read(cartProvider.notifier).updateQuantity(itemId, 1);

      expect(container.read(cartProvider)[itemId]!.quantity, 1);
      expect(container.read(cartTotalProvider), 180.0);
    });

    test('TC-POS-13: Stepper decrement to 0 removes item completely', () {
      final container = ProviderContainer();
      final product = _testProducts[0];

      container.read(cartProvider.notifier).addToCart(product, quantity: 1);
      final itemId = container.read(cartProvider).keys.first;

      container.read(cartProvider.notifier).updateQuantity(itemId, 0);

      expect(container.read(cartProvider).isEmpty, isTrue);
      expect(container.read(cartTotalProvider), 0.0);
    });

    test('TC-POS-14: Clear cart resets cart to empty', () {
      final container = ProviderContainer();
      container.read(cartProvider.notifier).addToCart(_testProducts[0], quantity: 2);
      container.read(cartProvider.notifier).addToCart(_testProducts[1], quantity: 1000);

      expect(container.read(cartProvider).length, 2);

      container.read(cartProvider.notifier).clearCart();

      expect(container.read(cartProvider).isEmpty, isTrue);
      expect(container.read(cartTotalProvider), 0.0);
    });
  });

  group('Category C: Hardware Hotkeys & Barcode Auto-Ring', () {
    testWidgets('TC-POS-15: [F1] hotkey focuses catalog search input', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      expect(tester.widget<TextField>(searchField).focusNode?.hasFocus ?? false, isFalse);

      // Press F1
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();

      // Search field should now be focused
      final focusScope = FocusScope.of(tester.element(searchField));
      expect(focusScope.hasFocus, isTrue);
    });

    testWidgets('TC-POS-16: [F2] hotkey triggers Clear Order dialog when cart has items', (tester) async {
      final cartNotifier = CartNotifier();
      cartNotifier.addToCart(_testProducts[0], quantity: 1);

      await tester.pumpWidget(_createTestWidget(cartNotifier: cartNotifier));
      await tester.pumpAndSettle();

      // Press F2
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pumpAndSettle();

      // Assert Clear Order dialog appears
      expect(find.text('Clear Current Order?'), findsOneWidget);
      expect(find.text('Clear Cart [Enter]'), findsOneWidget);
    });

    testWidgets('TC-POS-17: [F12] hotkey opens CheckoutScreen when cart has items', (tester) async {
      final cartNotifier = CartNotifier();
      cartNotifier.addToCart(_testProducts[0], quantity: 1);

      await tester.pumpWidget(_createTestWidget(cartNotifier: cartNotifier));
      await tester.pumpAndSettle();

      // Press F12
      await tester.sendKeyEvent(LogicalKeyboardKey.f12);
      await tester.pumpAndSettle();

      expect(find.byType(CheckoutScreen), findsOneWidget);
    });

    testWidgets('TC-POS-18: Submitting matching barcode auto-adds product to cart', (tester) async {
      final cartNotifier = CartNotifier();

      await tester.pumpWidget(_createTestWidget(cartNotifier: cartNotifier));
      await tester.pumpAndSettle();

      // Enter exact barcode for White Bread and press enter
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, '8901234567890');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify Bread was auto-added to cart
      expect(cartNotifier.state.length, 1);
      expect(cartNotifier.state.values.first.product.name, 'White Bread 450g');
    });
  });

  group('Category D: Responsive Layout & Dual-Pane Verification', () {
    testWidgets('TC-POS-19: Mobile layout (<750px) shows floating bottom cart bar', (tester) async {
      tester.view.physicalSize = const Size(412 * 2.0, 915 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cartNotifier = CartNotifier();
      cartNotifier.addToCart(_testProducts[0], quantity: 1);

      await tester.pumpWidget(_createTestWidget(cartNotifier: cartNotifier));
      await tester.pumpAndSettle();

      // In mobile, floating cart bar is rendered at bottom
      expect(find.text('View Cart'), findsOneWidget);
      expect(find.text('Rs. 180.00'), findsOneWidget);
    });

    testWidgets('TC-POS-20: Desktop layout (>=1100px) shows side-by-side Dual-Pane register', (tester) async {
      tester.view.physicalSize = const Size(1200 * 1.0, 800 * 1.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cartNotifier = CartNotifier();
      cartNotifier.addToCart(_testProducts[0], quantity: 2);

      await tester.pumpWidget(_createTestWidget(cartNotifier: cartNotifier));
      await tester.pumpAndSettle();

      // In desktop dual-pane, "Current Order" column is visible alongside catalog
      expect(find.text('Current Order'), findsOneWidget);
      expect(find.text('White Bread 450g'), findsWidgets); // Shown in catalog and in cart pane!
      expect(find.textContaining('CHECKOUT [F12]'), findsOneWidget);
    });
  });
}

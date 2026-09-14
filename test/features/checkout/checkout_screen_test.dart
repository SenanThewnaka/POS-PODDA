import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sme_buddy/features/checkout/checkout_screen.dart';
import 'package:sme_buddy/features/credit/customer_model.dart';
import 'package:sme_buddy/features/credit/customer_repository.dart';
import 'package:sme_buddy/features/home/cart_provider.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/reports/receipt_screen.dart';
import 'package:sme_buddy/features/reports/sale_model.dart';
import 'package:sme_buddy/features/reports/sales_repository.dart';
import 'package:sme_buddy/features/settings/printer_settings_service.dart';
import 'package:sme_buddy/features/shifts/shift_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';

// ---------------------------------------------------------------------------
// Test Fakes & Mock Repositories
// ---------------------------------------------------------------------------

class FakeSalesRepository implements SalesRepository {
  final List<Sale> recordedSales = [];

  @override
  UserModel get currentUser => _testUser;

  @override
  Future<Sale> recordSale(
    double amount,
    String method,
    String? customerId,
    Map<String, CartItem> cartItems, {
    double? amountTendered,
  }) async {
    final double tenderPaid = method == 'CASH'
        ? (amountTendered != null && amountTendered >= amount ? amountTendered : amount)
        : (method != 'CREDIT' ? amount : 0.0);

    final sale = Sale(
      id: 'sale_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      totalAmount: amount,
      paymentMethod: method,
      customerId: customerId,
      amountPaid: tenderPaid,
      isFullyPaid: method != 'CREDIT',
      items: cartItems.values
          .map((item) => SaleItem(
                productId: item.product.id,
                productName: item.product.name,
                unitPrice: item.effectivePrice,
                costPrice: item.costPrice,
                quantity: item.quantity,
                subTotal: item.subTotal,
              ))
          .toList(),
    );
    recordedSales.add(sale);
    return sale;
  }

  @override
  Future<Sale?> getSaleById(String saleId) async {
    try {
      return recordedSales.firstWhere((s) => s.id == saleId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Sale> updateSalePaymentDetails({
    required String saleId,
    required double amountPaid,
  }) async {
    final idx = recordedSales.indexWhere((s) => s.id == saleId);
    if (idx == -1) throw Exception("Sale not found: $saleId");
    final updated = recordedSales[idx].copyWith(amountPaid: amountPaid);
    recordedSales[idx] = updated;
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeShiftRepository implements ShiftRepository {
  final List<Map<String, dynamic>> shiftSalesRecords = [];

  @override
  UserModel get currentUser => _testUser;

  @override
  Future<void> recordSaleInActiveShift({
    required double amount,
    required String paymentMethod,
  }) async {
    shiftSalesRecords.add({'amount': amount, 'method': paymentMethod});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCustomerRepository implements CustomerRepository {
  final List<Map<String, dynamic>> balanceUpdates = [];

  @override
  String get userId => 'shop_123';

  @override
  Future<void> updateBalance(String customerId, double amountToAdd) async {
    balanceUpdates.add({'customerId': customerId, 'amount': amountToAdd});
  }

  @override
  Stream<List<Customer>> customersStream() => Stream.value([
        Customer(id: 'cust_1', name: 'Nimal Perera', mobile: '0771122334', currentBalance: 500.0),
        Customer(id: 'cust_2', name: 'Kamal Silva', mobile: '0714455667', currentBalance: 0.0),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeProductRepository implements ProductRepository {
  final List<List<BatchSaleItem>> salesProcessed = [];

  @override
  String get userId => 'shop_123';

  @override
  Future<void> processSale(List<BatchSaleItem> items) async {
    salesProcessed.add(items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Test Data Fixtures
// ---------------------------------------------------------------------------

final _testUser = UserModel(
  uid: 'user_1',
  email: 'cashier@pos.lk',
  name: 'Senan Cashier',
  mobile: '0771234567',
  role: 'cashier',
  shopId: 'shop_123',
  shopName: 'Podda Supermart',
  isActive: true,
);

final _testProduct1 = Product(
  id: 'prod_bread',
  name: 'White Bread 450g',
  sellingPrice: 180.0,
  costPrice: 140.0,
  stockType: 'unit',
  currentStock: 20.0,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

final _testProduct2 = Product(
  id: 'prod_butter',
  name: 'Highland Butter 200g',
  sellingPrice: 750.0,
  costPrice: 600.0,
  stockType: 'unit',
  currentStock: 10.0,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

Widget _createCheckoutWidget({
  required CartNotifier cartNotifier,
  FakeSalesRepository? salesRepo,
  FakeShiftRepository? shiftRepo,
  FakeCustomerRepository? customerRepo,
  FakeProductRepository? productRepo,
}) {
  return ProviderScope(
    overrides: [
      userProfileProvider.overrideWith((ref) => Stream.value(_testUser)),
      cartProvider.overrideWith((ref) => cartNotifier),
      salesRepositoryProvider.overrideWithValue(salesRepo ?? FakeSalesRepository()),
      shiftRepositoryProvider.overrideWithValue(shiftRepo ?? FakeShiftRepository()),
      customerRepositoryProvider.overrideWithValue(customerRepo ?? FakeCustomerRepository()),
      productRepositoryProvider.overrideWithValue(productRepo ?? FakeProductRepository()),
      printerSettingsProvider.overrideWith((ref) => PrinterSettingsNotifier()),
    ],
    child: const MaterialApp(
      home: CheckoutScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Test Suite Execution
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category A: Payment Method Toggles & State Transitions', () {
    testWidgets('TC-CHK-01: Initial state shows total, defaults to CASH, and cash given matches total', (tester) async {
      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // 750.00

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Verify total
      expect(find.text('TOTAL TO PAY'), findsOneWidget);
      expect(find.text('Rs. 750.00'), findsWidgets);

      // Verify default is CASH
      expect(find.text('CASH TENDERED'), findsOneWidget);

      // Cash given defaults to exact total
      expect(find.text('Exact (Rs. 750)'), findsOneWidget);
    });

    testWidgets('TC-CHK-02: Toggle to CARD sets method to CARD and hides cash NumPad', (tester) async {
      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1);

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Tap CARD toggle
      await tester.tap(find.text('CARD'));
      await tester.pumpAndSettle();

      // Cash tendered and numpad should disappear
      expect(find.text('CASH TENDERED'), findsNothing);
      expect(find.text('CHANGE DUE'), findsNothing);
    });

    testWidgets('TC-CHK-03: Toggle to CREDIT displays Customer Selection card', (tester) async {
      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1);

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Tap CREDIT toggle
      await tester.tap(find.text('CREDIT'));
      await tester.pumpAndSettle();

      // Customer selection prompt visible
      expect(find.text('SELECT CUSTOMER'), findsWidgets);
      expect(find.text('Tap to Select Customer'), findsOneWidget);
    });

    testWidgets('TC-CHK-04: Keyboard hotkeys F1, F2, F3 switch payment modes and digits type into cash tender', (tester) async {
      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1);

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Press 'F2' -> CARD
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pumpAndSettle();
      expect(find.text('CASH TENDERED'), findsNothing);

      // Press 'F3' -> CREDIT
      await tester.sendKeyEvent(LogicalKeyboardKey.f3);
      await tester.pumpAndSettle();
      expect(find.text('Tap to Select Customer'), findsOneWidget);

      // Press 'F1' -> CASH
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      expect(find.text('CASH TENDERED'), findsOneWidget);

      // Typing digits 1, 2, 3 types into cash tender without switching payment mode
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pumpAndSettle();
      expect(find.text('Rs. 123.00'), findsOneWidget);
      expect(find.text('CASH TENDERED'), findsOneWidget);
    });
  });

  group('Category B: Cash Tender & Touch NumPad Calculation Engine', () {
    testWidgets('TC-CHK-05: Exact tender chip selects exact amount', (tester) async {
      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // 750.00

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // First change amount with NumPad 1000
      await tester.tap(find.text('Rs. 1000'));
      await tester.pumpAndSettle();
      expect(find.text('Rs. 1000.00'), findsOneWidget);

      // Tap Exact chip
      await tester.tap(find.text('Exact (Rs. 750)'));
      await tester.pumpAndSettle();

      expect(find.text('Rs. 750.00'), findsWidgets);
      expect(find.text('Rs. 0.00'), findsOneWidget); // 0 change due
    });

    testWidgets('TC-CHK-06: Quick Cash note chips update cash tendered', (tester) async {
      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // 750.00

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Tap Rs. 2000 chip
      await tester.tap(find.text('Rs. 2000'));
      await tester.pumpAndSettle();

      // Cash tendered is 2000, change is 1250
      expect(find.text('Rs. 2000.00'), findsOneWidget);
      expect(find.text('Rs. 1250.00'), findsOneWidget);
    });

    testWidgets('TC-CHK-07: Touch NumPad digits concatenate correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // 750.00

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Tap 'C' to clear
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      expect(find.text('Rs. 0.00'), findsWidgets);

      // Tap 8, 5, 0
      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();

      expect(find.text('Rs. 850.00'), findsOneWidget);
      expect(find.text('Rs. 100.00'), findsOneWidget); // Change: 850 - 750 = 100
    });

    testWidgets('TC-CHK-08: Touch NumPad 00 appends double zeros', (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // 750.00

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Tap 'C' to clear
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();

      // Tap 5 then 00
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('00'));
      await tester.pumpAndSettle();

      expect(find.text('Rs. 500.00'), findsWidgets);
    });

    testWidgets('TC-CHK-09: Touch NumPad C resets cash given to 0', (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1);

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();

      expect(find.text('Amount Remaining:'), findsOneWidget);
      expect(find.text('Rs. 750.00'), findsWidgets);
    });

    testWidgets('TC-CHK-10: NumPad backspace removes last entered digit', (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1);

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Clear then enter 1, 5, 0, 0 -> 1500
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('numpad_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();
      expect(find.text('Rs. 1500.00'), findsOneWidget);

      // Tap backspace icon
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pumpAndSettle();

      // Now 150.00
      expect(find.text('Rs. 150.00'), findsOneWidget);
    });

    testWidgets('TC-CHK-11: Change Due green banner displays exact difference when tender >= total', (tester) async {
      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // 750.00

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Set cash to 1000
      await tester.tap(find.text('Rs. 1000'));
      await tester.pumpAndSettle();

      expect(find.text('CHANGE DUE'), findsOneWidget);
      expect(find.text('Rs. 250.00'), findsOneWidget);
    });

    testWidgets('TC-CHK-12: Amount Remaining amber warning appears when tender < total', (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // 750.00

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Set cash to 500
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('00'));
      await tester.pumpAndSettle();

      expect(find.text('Amount Remaining:'), findsOneWidget);
      expect(find.text('Rs. 250.00'), findsOneWidget);
    });
  });

  group('Category C: Validation, Debouncing & Error Handling', () {
    testWidgets('TC-CHK-13: Insufficient cash attempt triggers warning SnackBar', (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // 750.00

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Enter 500
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('00'));
      await tester.pumpAndSettle();

      // Tap Pay button
      await tester.ensureVisible(find.textContaining('COMPLETE SALE'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('COMPLETE SALE'));
      await tester.pumpAndSettle();

      // Verify SnackBar warning
      expect(find.textContaining('Insufficient Cash! Short by Rs. 250.00'), findsOneWidget);
    });

    testWidgets('TC-CHK-14: Zero cash tendered automatically defaults to exact payment on submit', (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // 750.00
      final salesRepo = FakeSalesRepository();

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart, salesRepo: salesRepo));
      await tester.pumpAndSettle();

      // Clear cash given to 0
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();

      // Tap Complete
      await tester.ensureVisible(find.textContaining('COMPLETE SALE'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('COMPLETE SALE'));
      await tester.pumpAndSettle();

      // Sale should proceed successfully with exact cash (750.00)
      expect(salesRepo.recordedSales.length, 1);
      expect(salesRepo.recordedSales.first.totalAmount, 750.0);
      expect(find.byType(ReceiptScreen), findsOneWidget);
    });

    testWidgets('TC-CHK-15: Credit payment without customer prompts SELECT CUSTOMER', (tester) async {
      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1);

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Switch to CREDIT
      await tester.tap(find.text('CREDIT'));
      await tester.pumpAndSettle();

      // Button says SELECT CUSTOMER
      expect(find.text('SELECT CUSTOMER'), findsWidgets);
    });
  });

  group('Category D: End-to-End Sale Finalization & Repositories', () {
    testWidgets('TC-CHK-16: Cash sale records sale, records in shift, updates stock, clears cart, and navigates to ReceiptScreen', (tester) async {
      final cart = CartNotifier();
      cart.addToCart(_testProduct1, quantity: 2); // 2 * 180 = 360.00

      final salesRepo = FakeSalesRepository();
      final shiftRepo = FakeShiftRepository();
      final productRepo = FakeProductRepository();

      await tester.pumpWidget(_createCheckoutWidget(
        cartNotifier: cart,
        salesRepo: salesRepo,
        shiftRepo: shiftRepo,
        productRepo: productRepo,
      ));
      await tester.pumpAndSettle();

      // Complete sale
      await tester.ensureVisible(find.textContaining('COMPLETE SALE'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('COMPLETE SALE'));
      await tester.pumpAndSettle();

      // 1. Sale recorded in salesRepo
      expect(salesRepo.recordedSales.length, 1);
      final sale = salesRepo.recordedSales.first;
      expect(sale.totalAmount, 360.0);
      expect(sale.paymentMethod, 'CASH');
      expect(sale.isFullyPaid, isTrue);

      // 2. Sale recorded in shiftRepo
      expect(shiftRepo.shiftSalesRecords.length, 1);
      expect(shiftRepo.shiftSalesRecords.first['amount'], 360.0);
      expect(shiftRepo.shiftSalesRecords.first['method'], 'CASH');

      // 3. Stock processed in productRepo
      expect(productRepo.salesProcessed.length, 1);
      expect(productRepo.salesProcessed.first.first.productId, 'prod_bread');
      expect(productRepo.salesProcessed.first.first.quantity, 2.0);

      // 4. Cart cleared
      expect(cart.state.isEmpty, isTrue);

      // 5. Navigated to ReceiptScreen
      expect(find.byType(ReceiptScreen), findsOneWidget);
    });

    testWidgets('TC-CHK-17: CARD sale records sale with CARD payment method', (tester) async {
      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // 750.00
      final salesRepo = FakeSalesRepository();
      final shiftRepo = FakeShiftRepository();

      await tester.pumpWidget(_createCheckoutWidget(
        cartNotifier: cart,
        salesRepo: salesRepo,
        shiftRepo: shiftRepo,
      ));
      await tester.pumpAndSettle();

      // Select CARD
      await tester.tap(find.text('CARD'));
      await tester.pumpAndSettle();

      // Complete sale
      await tester.ensureVisible(find.textContaining('COMPLETE SALE'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('COMPLETE SALE'));
      await tester.pumpAndSettle();

      expect(salesRepo.recordedSales.length, 1);
      expect(salesRepo.recordedSales.first.paymentMethod, 'CARD');
      expect(shiftRepo.shiftSalesRecords.first['method'], 'CARD');
      expect(find.byType(ReceiptScreen), findsOneWidget);
    });

    testWidgets('TC-CHK-18: [Esc] key pops and cancels back to POS register', (tester) async {
      final cart = CartNotifier();
      cart.addToCart(_testProduct1, quantity: 1);

      bool popped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(_testUser)),
            cartProvider.overrideWith((ref) => cart),
            printerSettingsProvider.overrideWith((ref) => PrinterSettingsNotifier()),
          ],
          child: MaterialApp(
            home: Navigator(
              onPopPage: (route, result) {
                popped = true;
                return route.didPop(result);
              },
              pages: const [
                MaterialPage(child: Scaffold(body: Text('Home Register'))),
                MaterialPage(child: CheckoutScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CheckoutScreen), findsOneWidget);

      // Send ESC
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });

    testWidgets('TC-CHK-19: [Enter] key completes payment transaction', (tester) async {
      final cart = CartNotifier();
      cart.addToCart(_testProduct1, quantity: 1); // 180.00
      final salesRepo = FakeSalesRepository();

      await tester.pumpWidget(_createCheckoutWidget(
        cartNotifier: cart,
        salesRepo: salesRepo,
      ));
      await tester.pumpAndSettle();

      // Press Enter key
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(salesRepo.recordedSales.length, 1);
      expect(find.byType(ReceiptScreen), findsOneWidget);
    });
  });

  group('Category E: Responsive Layout & Ergonomics Stress Tests', () {
    testWidgets('TC-CHK-20: Mobile layout (412x915) renders with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(412 * 2.0, 915 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 2); // 1500.00

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      expect(find.text('TOTAL TO PAY'), findsOneWidget);
      expect(find.text('Rs. 1500.00'), findsWidgets);
      expect(find.text('CASH TENDERED'), findsOneWidget);
    });

    testWidgets('TC-CHK-21: Small screen (330x700) renders and scrolls with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(330 * 2.0, 700 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1);

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      expect(find.text('TOTAL TO PAY'), findsOneWidget);
    });

    testWidgets('TC-CHK-22: Desktop layout (1200x800) renders centered with hotkey hints strip with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(1200 * 1.0, 800 * 1.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1);

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      expect(find.text('[F1] Cash'), findsOneWidget);
      expect(find.text('[F2] Card'), findsOneWidget);
      expect(find.text('[F3] Credit'), findsOneWidget);
      expect(find.text('[Enter] Pay'), findsOneWidget);
      expect(find.text('[Esc] Back'), findsOneWidget);
    });

    testWidgets('TC-CHK-23: Physical keyboard digits replace default total on first keystroke', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // Total: 750.00

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Initially cash tendered defaults to 750.00
      expect(find.text('Rs. 750.00'), findsWidgets);

      // Cashier types 1, 0, 0, 0 on physical keyboard
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pumpAndSettle();
      expect(find.text('Rs. 1.00'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pumpAndSettle();

      expect(find.text('Rs. 1000.00'), findsOneWidget);
      expect(find.text('Rs. 250.00'), findsOneWidget); // Change: 1000 - 750 = 250
    });

    testWidgets('TC-CHK-24: Physical NumPad digits and backspace work as expected', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // Total: 750.00

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Type 8, 0, 0 on NumPad
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad8);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad0);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad0);
      await tester.pumpAndSettle();

      expect(find.text('Rs. 800.00'), findsOneWidget);

      // Hit Backspace
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(find.text('Rs. 80.00'), findsOneWidget);
    });

    testWidgets('TC-CHK-25: iPad portrait layout (768x1024) renders with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 2);

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      expect(find.text('CASH TENDERED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-CHK-26: Tapping CASH TENDERED bar selects amount and keyboard typing overwrites value', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cart = CartNotifier();
      cart.addToCart(_testProduct2, quantity: 1); // 750.00

      await tester.pumpWidget(_createCheckoutWidget(cartNotifier: cart));
      await tester.pumpAndSettle();

      // Initially SELECTED badge is visible and cash matches 750.00
      expect(find.text('SELECTED'), findsOneWidget);
      expect(find.text('Rs. 750.00'), findsWidgets);

      // Typing 5 replaces 750 with 5.00
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.pumpAndSettle();
      expect(find.text('Rs. 5.00'), findsOneWidget);
      expect(find.text('SELECTED'), findsNothing);

      // Tapping the CASH TENDERED bar re-selects it
      await tester.tap(find.text('CASH TENDERED'));
      await tester.pumpAndSettle();
      expect(find.text('SELECTED'), findsOneWidget);

      // Typing 2 replaces the selected amount with 2.00
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pumpAndSettle();
      expect(find.text('Rs. 2.00'), findsOneWidget);

      // Typing 0 appends to make it 20.00
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pumpAndSettle();
      expect(find.text('Rs. 20.00'), findsOneWidget);
    });
  });
}

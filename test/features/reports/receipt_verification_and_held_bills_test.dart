import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sme_buddy/features/home/cart_provider.dart';
import 'package:sme_buddy/features/home/held_bills_dialog.dart';
import 'package:sme_buddy/features/home/held_bills_provider.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/reports/receipt_screen.dart';
import 'package:sme_buddy/features/reports/sale_model.dart';
import 'package:sme_buddy/features/reports/sales_repository.dart';
import 'package:sme_buddy/features/reports/verify_receipt_dialog.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';

final _testUser = UserModel(
  uid: 'user_123',
  shopId: 'shop_123',
  name: 'Kasun Bandara',
  email: 'kasun@pos.lk',
  mobile: '0771234567',
  role: 'cashier',
  shopName: 'Super Mart Colombo',
  shopAddress: '123 Galle Road, Colombo',
);

class FakeReceiptSalesRepository implements SalesRepository {
  final Map<String, Sale> salesDb = {};

  @override
  UserModel get currentUser => _testUser;

  @override
  Future<Sale?> getSaleById(String saleId) async {
    return salesDb[saleId];
  }

  @override
  Future<Sale> updateSalePaymentDetails({
    required String saleId,
    required double amountPaid,
  }) async {
    final sale = salesDb[saleId];
    if (sale == null) throw Exception("Sale not found: $saleId");
    final updated = sale.copyWith(amountPaid: amountPaid);
    salesDb[saleId] = updated;
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProduct = Product(
    id: 'prod_1',
    name: 'Keells Bread',
    sellingPrice: 180.0,
    costPrice: 140.0,
    barcode: '479000111222',
    createdAt: DateTime.now(),
  );

  final testProduct2 = Product(
    id: 'prod_2',
    name: 'Anchor Butter 200g',
    sellingPrice: 850.0,
    costPrice: 700.0,
    barcode: '479000333444',
    createdAt: DateTime.now(),
  );

  group('Held Bills & Parked Orders System', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('HeldBill serialization and deserialization retains all fields', () {
      final item = CartItem(
        id: 'ci_1',
        product: testProduct,
        quantity: 2,
        effectivePrice: 180.0,
        costPrice: 140.0,
      );

      final bill = HeldBill(
        id: 'HELD-TEST01',
        createdAt: DateTime(2026, 9, 14, 15, 30),
        items: {'ci_1': item},
        totalAmount: 360.0,
        note: 'Customer went to get wallet',
        customerName: 'Saman Kumara',
      );

      final jsonStr = bill.toJson();
      final restored = HeldBill.fromJson(jsonStr);

      expect(restored.id, 'HELD-TEST01');
      expect(restored.totalAmount, 360.0);
      expect(restored.note, 'Customer went to get wallet');
      expect(restored.customerName, 'Saman Kumara');
      expect(restored.items.length, 1);
      expect(restored.items['ci_1']!.product.name, 'Keells Bread');
      expect(restored.itemCount, 2);
    });

    test('HeldBillsNotifier holds current cart, persists, and resumes bill', () async {
      final notifier = HeldBillsNotifier();

      final items = {
        'item_1': CartItem(
          id: 'item_1',
          product: testProduct,
          quantity: 2,
          effectivePrice: 180.0,
          costPrice: 140.0,
        ),
        'item_2': CartItem(
          id: 'item_2',
          product: testProduct2,
          quantity: 1,
          effectivePrice: 850.0,
          costPrice: 700.0,
        ),
      };

      final held = await notifier.holdCurrentCart(
        items: items,
        totalAmount: 1210.0,
        note: 'Table 4',
        customerName: 'Nimal',
      );

      expect(notifier.state.length, 1);
      expect(notifier.state.first.id, held.id);
      expect(notifier.state.first.totalAmount, 1210.0);
      expect(notifier.state.first.note, 'Table 4');

      // Resume
      final resumed = await notifier.resumeHeldBill(held.id);
      expect(resumed, isNotNull);
      expect(resumed!.totalAmount, 1210.0);
      expect(notifier.state.isEmpty, true);
    });

    testWidgets('HeldBillsDialog renders parked bills and handles actions', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final notifier = HeldBillsNotifier();

      await notifier.holdCurrentCart(
        items: {
          'c1': CartItem(
            id: 'c1',
            product: testProduct,
            quantity: 1,
            effectivePrice: 180.0,
            costPrice: 140.0,
          ),
        },
        totalAmount: 180.0,
        note: 'Counter 1',
        customerName: 'Sunil',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            heldBillsProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: HeldBillsDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Held Orders"), findsOneWidget);
      expect(find.text("Sunil"), findsOneWidget);
      expect(find.text("Note: Counter 1"), findsOneWidget);
      expect(find.text("Rs. 180.00"), findsOneWidget);
      expect(find.text("Resume"), findsOneWidget);
    });
  });

  group('Post-Checkout Receipt Editing & Recalculation', () {
    late FakeReceiptSalesRepository fakeSalesRepo;

    setUp(() {
      fakeSalesRepo = FakeReceiptSalesRepository();
    });

    testWidgets('ReceiptScreen displays Cash Tendered and Change Due for CASH sales', (tester) async {
      final sale = Sale(
        id: 'BILL-009988',
        timestamp: DateTime.now(),
        totalAmount: 500.0,
        paymentMethod: 'CASH',
        amountPaid: 1000.0, // Customer gave 1000 for a 500 bill
        items: [
          SaleItem(
            productId: testProduct.id,
            productName: 'Keells Bread',
            unitPrice: 250.0,
            costPrice: 200.0,
            quantity: 2,
            subTotal: 500.0,
          ),
        ],
      );

      fakeSalesRepo.salesDb[sale.id] = sale;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesRepositoryProvider.overrideWithValue(fakeSalesRepo),
            userProfileProvider.overrideWith((ref) => Stream.value(_testUser)),
          ],
          child: MaterialApp(
            home: ReceiptScreen(sale: sale),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check displayed total, tendered, change due, and bill id
      expect(find.text("PAYMENT SUCCESSFUL"), findsOneWidget);
      expect(find.text("Rs. 500.00"), findsWidgets); // Total
      expect(find.text("Rs. 1000.00"), findsOneWidget); // Cash Tendered
      expect(find.text("Rs. 500.00"), findsWidgets); // Change Due
      expect(find.textContaining("BILL-009988"), findsWidgets);
      expect(find.text("Edit"), findsOneWidget);
    });

    testWidgets('ReceiptScreen Edit Cash dialog updates amountPaid and recalculates Change Due', (tester) async {
      final sale = Sale(
        id: 'BILL-007711',
        timestamp: DateTime.now(),
        totalAmount: 500.0,
        paymentMethod: 'CASH',
        amountPaid: 500.0, // Initially cashier accidentally marked 500
        items: [
          SaleItem(
            productId: testProduct.id,
            productName: 'Keells Bread',
            unitPrice: 500.0,
            costPrice: 400.0,
            quantity: 1,
            subTotal: 500.0,
          ),
        ],
      );

      fakeSalesRepo.salesDb[sale.id] = sale;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesRepositoryProvider.overrideWithValue(fakeSalesRepo),
            userProfileProvider.overrideWith((ref) => Stream.value(_testUser)),
          ],
          child: MaterialApp(
            home: ReceiptScreen(sale: sale),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial change due is 0.00
      expect(find.text("Rs. 0.00"), findsOneWidget);

      // Tap Edit
      await tester.tap(find.text("Edit"));
      await tester.pumpAndSettle();

      expect(find.text("Correct Cash Tendered"), findsOneWidget);

      // Tap quick note chip Rs. 2000
      await tester.tap(find.text("Rs. 2000"));
      await tester.pumpAndSettle();

      // Recalculated Change Due in dialog should be 1500.00
      expect(find.text("Rs. 1500.00"), findsOneWidget);

      // Tap Save & Recalculate
      await tester.tap(find.text("Save & Recalculate"));
      await tester.pumpAndSettle();

      // Receipt screen should now show Cash Tendered Rs. 2000.00 and Change Due Rs. 1500.00
      expect(find.text("Rs. 2000.00"), findsOneWidget);
      expect(find.text("Rs. 1500.00"), findsOneWidget);
      expect(fakeSalesRepo.salesDb['BILL-007711']!.amountPaid, 2000.0);
    });
  });

  group('Receipt Verification & Returns', () {
    late FakeReceiptSalesRepository fakeSalesRepo;

    setUp(() {
      fakeSalesRepo = FakeReceiptSalesRepository();
    });

    testWidgets('VerifyReceiptDialog finds legit bill and displays line items and cashier', (tester) async {
      final sale = Sale(
        id: 'REC-554433',
        timestamp: DateTime(2026, 9, 14, 10, 15),
        totalAmount: 1030.0,
        paymentMethod: 'CASH',
        amountPaid: 2000.0,
        userName: 'Kasun Cashier',
        items: [
          SaleItem(
            productId: 'p1',
            productName: 'Keells Bread',
            unitPrice: 180.0,
            costPrice: 140.0,
            quantity: 1,
            subTotal: 180.0,
          ),
          SaleItem(
            productId: 'p2',
            productName: 'Anchor Butter 200g',
            unitPrice: 850.0,
            costPrice: 700.0,
            quantity: 1,
            subTotal: 850.0,
          ),
        ],
      );

      fakeSalesRepo.salesDb[sale.id] = sale;

      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesRepositoryProvider.overrideWithValue(fakeSalesRepo),
            userProfileProvider.overrideWith((ref) => Stream.value(_testUser)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VerifyReceiptDialog(initialBillId: 'REC-554433')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("LEGITIMATE RECEIPT VERIFIED"), findsOneWidget);
      expect(find.textContaining("REC-554433"), findsWidgets);
      expect(find.textContaining("Kasun Cashier"), findsOneWidget);
      expect(find.text("Keells Bread"), findsOneWidget);
      expect(find.text("Anchor Butter 200g"), findsOneWidget);
      expect(find.text("Rs. 1030.00"), findsOneWidget);
      expect(find.text("Open Receipt & Reprint"), findsOneWidget);
    });

    testWidgets('VerifyReceiptDialog displays error when Bill ID is not found in database', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesRepositoryProvider.overrideWithValue(fakeSalesRepo),
            userProfileProvider.overrideWith((ref) => Stream.value(_testUser)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VerifyReceiptDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'FAKE-BILL-999');
      await tester.tap(find.text("Verify"));
      await tester.pumpAndSettle();

      expect(find.text("VERIFICATION FAILED"), findsOneWidget);
      expect(find.textContaining("Receipt ID 'FAKE-BILL-999' not found"), findsOneWidget);
    });
  });
}

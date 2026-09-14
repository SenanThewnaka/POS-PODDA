import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/inventory/stock_batch_model.dart';
import 'package:sme_buddy/features/procurement/grn_model.dart';
import 'package:sme_buddy/features/procurement/supplier_model.dart';
import 'package:sme_buddy/features/procurement/procurement_repository.dart';
import 'package:sme_buddy/features/procurement/suppliers_screen.dart';
import 'package:sme_buddy/features/procurement/create_grn_screen.dart';
import 'package:sme_buddy/features/procurement/grn_history_screen.dart';

// ---------------------------------------------------------------------------
// Fakes & Mocks
// ---------------------------------------------------------------------------

class FakeProcurementRepository implements ProcurementRepository {
  @override
  final UserModel currentUser;

  final List<SupplierModel> suppliers;
  final List<GRNModel> grns;
  final List<SupplierModel> savedSuppliers = [];
  final List<String> deletedSupplierIds = [];
  final List<GRNModel> receivedGRNs = [];

  final StreamController<List<SupplierModel>> _supplierStreamCtrl =
      StreamController<List<SupplierModel>>.broadcast();
  final StreamController<List<GRNModel>> _grnStreamCtrl =
      StreamController<List<GRNModel>>.broadcast();

  FakeProcurementRepository({
    UserModel? user,
    List<SupplierModel>? initialSuppliers,
    List<GRNModel>? initialGRNs,
  })  : currentUser = user ?? _testUser,
        suppliers = initialSuppliers ?? [],
        grns = initialGRNs ?? [] {
    _supplierStreamCtrl.add(suppliers);
    _grnStreamCtrl.add(grns);
  }

  @override
  Stream<List<SupplierModel>> getSuppliersStream() async* {
    yield List.from(suppliers);
    yield* _supplierStreamCtrl.stream;
  }

  @override
  Future<void> saveSupplier(SupplierModel supplier) async {
    savedSuppliers.add(supplier);
    final idx = suppliers.indexWhere((s) => s.id == supplier.id && s.id.isNotEmpty);
    if (idx >= 0) {
      suppliers[idx] = supplier;
    } else {
      final newId = supplier.id.isEmpty ? 'supp-${suppliers.length + 1}' : supplier.id;
      suppliers.add(supplier.copyWith(id: newId));
    }
    _supplierStreamCtrl.add(List.from(suppliers));
  }

  @override
  Future<void> deleteSupplier(String supplierId) async {
    deletedSupplierIds.add(supplierId);
    suppliers.removeWhere((s) => s.id == supplierId);
    _supplierStreamCtrl.add(List.from(suppliers));
  }

  @override
  Stream<List<GRNModel>> getGRNListStream() async* {
    yield List.from(grns);
    yield* _grnStreamCtrl.stream;
  }

  @override
  Future<String> receiveGRN(GRNModel grn) async {
    receivedGRNs.add(grn);
    final id = grn.id.isEmpty ? 'grn-${grns.length + 1}' : grn.id;
    grns.insert(0, grn);
    _grnStreamCtrl.add(List.from(grns));
    return id;
  }

  void dispose() {
    _supplierStreamCtrl.close();
    _grnStreamCtrl.close();
  }
}

// ---------------------------------------------------------------------------
// Test Data & Helpers
// ---------------------------------------------------------------------------

final _testUser = UserModel(
  uid: 'test-user-id',
  email: 'owner@test.com',
  name: 'Owner Tester',
  mobile: '0771234567',
  role: 'owner',
  shopId: 'test-shop-id',
  shopName: 'POS Podda Supermarket',
  isActive: true,
);

final List<SupplierModel> _sampleSuppliers = [
  SupplierModel(
    id: 'supp-1',
    name: 'Ceylon Foods PLC',
    companyName: 'Ceylon Foods Distributors',
    phone: '0771234567',
    email: 'sales@ceylonfoods.lk',
    address: '123 Galle Road, Colombo',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  ),
  SupplierModel(
    id: 'supp-2',
    name: 'Lanka Beverages Ltd',
    companyName: 'Lanka Beverages Co',
    phone: '0112345678',
    email: 'orders@lankabev.lk',
    address: '45 Kandy Road, Kelaniya',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  ),
];

final List<Product> _sampleProducts = [
  Product(
    id: 'prod-1',
    name: 'Highland Fresh Milk 1L',
    costPrice: 420.0,
    sellingPrice: 500.0,
    currentStock: 25.0,
    stockType: 'unit',
    isActive: true,
    barcode: '4791234567890',
    createdAt: DateTime(2026, 1, 1),
  ),
  Product(
    id: 'prod-2',
    name: 'Munchee Super Cream Cracker',
    costPrice: 180.0,
    sellingPrice: 230.0,
    currentStock: 40.0,
    stockType: 'unit',
    isActive: true,
    barcode: '4799876543210',
    createdAt: DateTime(2026, 1, 1),
  ),
];

Widget _wrapWithProviders({
  required Widget child,
  FakeProcurementRepository? procurementRepo,
  List<Product>? products,
  List<SupplierModel>? suppliers,
}) {
  final repo = procurementRepo ??
      FakeProcurementRepository(
        initialSuppliers: suppliers ?? _sampleSuppliers,
      );

  return ProviderScope(
    overrides: [
      userProfileProvider.overrideWith((ref) => Stream.value(_testUser)),
      procurementRepositoryProvider.overrideWithValue(repo),
      suppliersStreamProvider.overrideWith((ref) => repo.getSuppliersStream()),
      grnListStreamProvider.overrideWith((ref) => repo.getGRNListStream()),
      productsStreamProvider.overrideWith((ref) => Stream.value(products ?? _sampleProducts)),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

// ---------------------------------------------------------------------------
// Test Suite Execution
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category A: Procurement Domain & Profit Margin Math', () {
    test('TC-PRC-01: Line Item Subtotal Calculation (qty * unitCost)', () {
      final item = GRNItem(
        productId: 'prod-1',
        productName: 'Highland Fresh Milk 1L',
        quantity: 20.0,
        unitCostPrice: 150.0,
        sellingPrice: 200.0,
        subTotal: 20.0 * 150.0,
      );

      expect(item.subTotal, 3000.0);
    });

    test('TC-PRC-02: Total GRN Cost & Retail Value calculations', () {
      final item1 = GRNItem(
        productId: 'prod-1',
        productName: 'Item 1',
        quantity: 20.0,
        unitCostPrice: 150.0,
        sellingPrice: 200.0,
        subTotal: 3000.0,
      );
      final item2 = GRNItem(
        productId: 'prod-2',
        productName: 'Item 2',
        quantity: 10.0,
        unitCostPrice: 300.0,
        sellingPrice: 400.0,
        subTotal: 3000.0,
      );

      final items = [item1, item2];
      final totalCost = items.fold(0.0, (sum, i) => sum + i.subTotal);
      final totalRetail = items.fold(0.0, (sum, i) => sum + (i.quantity * i.sellingPrice));

      expect(totalCost, 6000.0);
      expect(totalRetail, 8000.0);
    });

    test('TC-PRC-03: Expected Profit & Gross Margin Percentage', () {
      const totalCost = 6000.0;
      const totalRetail = 8000.0;
      const profit = totalRetail - totalCost;
      final margin = (profit / totalRetail) * 100;

      expect(profit, 2000.0);
      expect(margin, 25.0);
    });

    test('TC-PRC-04: StockBatch Model Serialization & CopyWith', () {
      final batch = StockBatch(
        id: 'batch-001',
        productId: 'prod-1',
        costPrice: 120.0,
        sellingPrice: 160.0,
        currentStock: 50.0,
        createdAt: DateTime(2026, 1, 1),
        isActive: true,
      );

      final map = batch.toMap();
      expect(map['id'], 'batch-001');
      expect(map['costPrice'], 120.0);
      expect(map['sellingPrice'], 160.0);
      expect(map['currentStock'], 50.0);

      final restored = StockBatch.fromMap(map);
      expect(restored.id, batch.id);
      expect(restored.costPrice, batch.costPrice);

      final updated = batch.copyWith(currentStock: 45.0);
      expect(updated.currentStock, 45.0);
      expect(updated.id, 'batch-001');
    });
  });

  group('Category B: Supplier Management (SuppliersScreen)', () {
    testWidgets('TC-PRC-05: Render Active Suppliers List', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(child: const SuppliersScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Suppliers Directory'), findsOneWidget);
      expect(find.text('Ceylon Foods PLC'), findsOneWidget);
      expect(find.text('Lanka Beverages Ltd'), findsOneWidget);
      expect(find.text('0771234567'), findsOneWidget);
    });

    testWidgets('TC-PRC-06: Real-Time Supplier Search Filtering', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(child: const SuppliersScreen()));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Ceylon');
      await tester.pumpAndSettle();

      expect(find.text('Ceylon Foods PLC'), findsOneWidget);
      expect(find.text('Lanka Beverages Ltd'), findsNothing);
    });

    testWidgets('TC-PRC-07: Empty Supplier Search State', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(child: const SuppliersScreen()));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'NonExistent999');
      await tester.pumpAndSettle();

      expect(find.text("No suppliers match 'nonexistent999'"), findsOneWidget);
    });

    testWidgets('TC-PRC-08: Add Supplier Validation requires name', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(child: const SuppliersScreen()));
      await tester.pumpAndSettle();

      // Tap + New Supplier button
      await tester.tap(find.text('NEW SUPPLIER'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Submit with empty name (button label is 'Add Supplier')
      final saveBtn = find.widgetWithText(ElevatedButton, 'Add Supplier');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('TC-PRC-09: Add Supplier successfully invokes saveSupplier', (tester) async {
      final repo = FakeProcurementRepository(initialSuppliers: []);

      await tester.pumpWidget(_wrapWithProviders(
        child: const SuppliersScreen(),
        procurementRepo: repo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('NEW SUPPLIER'));
      await tester.pumpAndSettle();

      // Enter name & phone
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Elephant House Distributors');
      await tester.enterText(textFields.at(2), '0719876543');
      await tester.pumpAndSettle();

      final saveBtn = find.widgetWithText(ElevatedButton, 'Add Supplier');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(repo.savedSuppliers.length, 1);
      expect(repo.savedSuppliers.first.name, 'Elephant House Distributors');
      expect(repo.savedSuppliers.first.phone, '0719876543');
    });

    testWidgets('TC-PRC-10: Soft Delete Supplier invokes deleteSupplier', (tester) async {
      final repo = FakeProcurementRepository(initialSuppliers: List.from(_sampleSuppliers));

      await tester.pumpWidget(_wrapWithProviders(
        child: const SuppliersScreen(),
        procurementRepo: repo,
      ));
      await tester.pumpAndSettle();

      // Tap popup menu or delete button on first card
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      // Tap Remove in menu
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      // Confirm dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(repo.deletedSupplierIds.length, 1);
      expect(repo.deletedSupplierIds.first, 'supp-1');
    });
  });

  group('Category C: Inward GRN Creation & Line Items (CreateGRNScreen)', () {
    testWidgets('TC-PRC-11: Screen renders initial GRN fields and empty items placeholder', (tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(child: const CreateGRNScreen()));
      await tester.pumpAndSettle();

      expect(find.text('New Goods Received Note (GRN)'), findsOneWidget);
      expect(find.text('GRN Information'), findsOneWidget);
      expect(find.text('Inward Line Items'), findsOneWidget);
      expect(find.text('No items added to this GRN yet'), findsOneWidget);
      expect(find.text('Total Purchase Cost (Payable):'), findsOneWidget);
    });

    testWidgets('TC-PRC-12: Empty items submission triggers warning SnackBar', (tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(child: const CreateGRNScreen()));
      await tester.pumpAndSettle();

      // Tapping CONFIRM & INWARD when items are empty is disabled
      final confirmBtn = find.text('CONFIRM & INWARD');
      expect(confirmBtn, findsOneWidget);

      final textButton = tester.widget<TextButton>(find.widgetWithText(TextButton, 'CONFIRM & INWARD'));
      expect(textButton.onPressed, isNull); // Disabled when items empty
    });

    testWidgets('TC-PRC-13: Add Line Item Modal Validation requires valid quantity and cost', (tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(child: const CreateGRNScreen()));
      await tester.pumpAndSettle();

      // Open Add Item Dialog
      await tester.tap(find.text('ADD ITEM'));
      await tester.pumpAndSettle();

      expect(find.text('Add Inward Product'), findsOneWidget);

      // Select first product
      await tester.tap(find.text('Highland Fresh Milk 1L'));
      await tester.pumpAndSettle();

      // Clear quantity to 0
      final qtyField = find.widgetWithText(TextFormField, '1');
      await tester.enterText(qtyField, '0');
      await tester.pumpAndSettle();

      // Tap Add to GRN
      await tester.tap(find.text('Add to GRN'));
      await tester.pumpAndSettle();

      expect(find.text('Valid qty required'), findsOneWidget);
    });

    testWidgets('TC-PRC-14: Adding Line Item updates item list and financial summary', (tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(child: const CreateGRNScreen()));
      await tester.pumpAndSettle();

      // Open Add Item Dialog
      await tester.tap(find.text('ADD ITEM'));
      await tester.pumpAndSettle();

      // Select first product
      await tester.tap(find.text('Highland Fresh Milk 1L'));
      await tester.pumpAndSettle();

      // Set Qty: 10, Cost: 400, Sell: 500
      final qtyField = find.widgetWithText(TextFormField, '1');
      await tester.enterText(qtyField, '10');
      await tester.pumpAndSettle();

      // Cost price is already populated with 420.00
      await tester.tap(find.text('Add to GRN'));
      await tester.pumpAndSettle();

      // Item should appear in list: 10 × 420 = 4200.00
      expect(find.text('Highland Fresh Milk 1L'), findsOneWidget);
      expect(find.text('Rs. 4200.00'), findsWidgets); // subtotal & total cost
      expect(find.text('1 items'), findsOneWidget);
    });

    testWidgets('TC-PRC-15: Removing Line Item removes it from list and recomputes total', (tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(child: const CreateGRNScreen()));
      await tester.pumpAndSettle();

      // Add item
      await tester.tap(find.text('ADD ITEM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Highland Fresh Milk 1L'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to GRN'));
      await tester.pumpAndSettle();

      expect(find.text('Highland Fresh Milk 1L'), findsOneWidget);

      // Remove item
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Highland Fresh Milk 1L'), findsNothing);
      expect(find.text('No items added to this GRN yet'), findsOneWidget);
      expect(find.text('Rs. 0.00'), findsWidgets);
    });

    testWidgets('TC-PRC-16: Payment Status changes update styling', (tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(child: const CreateGRNScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Paid in Full'), findsOneWidget);
      expect(find.text('Amount Paid (Rs.)'), findsOneWidget);

      // Change to Credit / On Account
      final dropdown = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Credit / On Account').last);
      await tester.pumpAndSettle();

      // Amount paid input should hide in Credit mode
      expect(find.text('Amount Paid (Rs.)'), findsNothing);
    });

    testWidgets('TC-PRC-17: Notes and Invoice Number input fields persist values', (tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(child: const CreateGRNScreen()));
      await tester.pumpAndSettle();

      final invoiceField = find.widgetWithText(TextField, 'Supplier Invoice / Bill #');
      await tester.enterText(invoiceField, 'INV-2026-0042');
      await tester.pumpAndSettle();

      final notesField = find.widgetWithText(TextField, 'Notes / Receiving Remarks');
      await tester.enterText(notesField, 'Goods checked and accepted in good condition');
      await tester.pumpAndSettle();

      expect(find.text('INV-2026-0042'), findsOneWidget);
      expect(find.text('Goods checked and accepted in good condition'), findsOneWidget);
    });
  });

  group('Category D: Inventory Receiving & Batches Integration', () {
    testWidgets('TC-PRC-18: Submitting GRN invokes procurementRepo.receiveGRN', (tester) async {
      final repo = FakeProcurementRepository();

      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(
        child: const CreateGRNScreen(),
        procurementRepo: repo,
      ));
      await tester.pumpAndSettle();

      // Add Item
      await tester.tap(find.text('ADD ITEM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Highland Fresh Milk 1L'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to GRN'));
      await tester.pumpAndSettle();

      // Enter invoice
      final invoiceField = find.widgetWithText(TextField, 'Supplier Invoice / Bill #');
      await tester.enterText(invoiceField, 'INV-2026-999');
      await tester.pumpAndSettle();

      // Tap CONFIRM & INWARD
      await tester.tap(find.widgetWithText(TextButton, 'CONFIRM & INWARD'));
      await tester.pumpAndSettle();

      expect(repo.receivedGRNs.length, 1);
      final received = repo.receivedGRNs.first;
      expect(received.invoiceNumber, 'INV-2026-999');
      expect(received.items.length, 1);
      expect(received.items.first.productId, 'prod-1');
      expect(received.totalCost, 420.0);
    });

    testWidgets('TC-PRC-19: GRNHistoryScreen renders received GRN list and status badge', (tester) async {
      final sampleGRN = GRNModel(
        id: 'grn-101',
        shopId: 'test-shop-id',
        grnNumber: 'GRN-101',
        supplierName: 'Ceylon Foods PLC',
        invoiceNumber: 'INV-001',
        receivedAt: DateTime.now(),
        totalCost: 15400.0,
        paymentStatus: 'PAID',
        items: [
          GRNItem(
            productId: 'prod-1',
            productName: 'Highland Fresh Milk 1L',
            quantity: 30.0,
            unitCostPrice: 420.0,
            sellingPrice: 500.0,
            subTotal: 12600.0,
          ),
        ],
      );

      final repo = FakeProcurementRepository(initialGRNs: [sampleGRN]);

      await tester.pumpWidget(_wrapWithProviders(
        child: const GRNHistoryScreen(),
        procurementRepo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Procurement & GRN Inward'), findsOneWidget);
      expect(find.text('GRN-101'), findsOneWidget);
      expect(find.text('Ceylon Foods PLC'), findsOneWidget);
      expect(find.text('Rs. 15400.00'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);
    });
  });

  group('Category E: Multi-Device Layout & Ergonomics', () {
    testWidgets('TC-PRC-20: Responsive Layouts (Mobile, Small, Desktop) render with 0 overflow', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Mobile Portrait (412x915)
      tester.view.physicalSize = const Size(412 * 2.0, 915 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpWidget(_wrapWithProviders(child: const CreateGRNScreen()));
      await tester.pumpAndSettle();
      expect(find.text('New Goods Received Note (GRN)'), findsOneWidget);

      // 2. Small Screen (330x700)
      tester.view.physicalSize = const Size(330 * 2.0, 700 * 2.0);
      await tester.pumpWidget(_wrapWithProviders(child: const CreateGRNScreen()));
      await tester.pumpAndSettle();
      expect(find.text('New Goods Received Note (GRN)'), findsOneWidget);

      // 3. Desktop (1200x800) - dual pane view
      tester.view.physicalSize = const Size(1200 * 1.0, 800 * 1.0);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(_wrapWithProviders(child: const CreateGRNScreen()));
      await tester.pumpAndSettle();
      expect(find.text('New Goods Received Note (GRN)'), findsOneWidget);
    });
  });
}

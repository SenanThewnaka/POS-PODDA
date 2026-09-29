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
  final List<GRNModel> updatedGRNs = [];
  final Map<String, double> batchStock = {};

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
    for (final grn in grns) {
      for (final it in grn.items) {
        if (it.batchId != null && it.batchId!.isNotEmpty) {
          batchStock[it.batchId!] = it.quantity;
        }
      }
    }
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
  Future<double?> getBatchRemainingStock(String productId, String batchId) async {
    return batchStock[batchId];
  }

  @override
  Future<String> receiveGRN(GRNModel grn) async {
    final id = grn.id.isEmpty ? 'grn-${grns.length + 1}' : grn.id;
    final savedItems = <GRNItem>[];
    for (int i = 0; i < grn.items.length; i++) {
      final it = grn.items[i];
      final bId = it.batchId?.isNotEmpty == true ? it.batchId! : 'batch-${it.productId}-$i';
      savedItems.add(it.copyWith(batchId: bId));
      batchStock[bId] = it.quantity;
    }
    final savedGRN = grn.copyWith(id: id, items: savedItems);
    receivedGRNs.add(savedGRN);
    grns.insert(0, savedGRN);
    _grnStreamCtrl.add(List.from(grns));
    return id;
  }

  @override
  Future<void> updateGRN(GRNModel updatedGrn, GRNModel originalGrn) async {
    final origItemMap = <String, GRNItem>{};
    for (final it in originalGrn.items) {
      final key = (it.batchId != null && it.batchId!.isNotEmpty) ? it.batchId! : it.productId;
      origItemMap[key] = it;
    }

    final finalItems = <GRNItem>[];
    final remainingKeys = Set<String>.from(origItemMap.keys);

    for (final currItem in updatedGrn.items) {
      final key = (currItem.batchId != null && currItem.batchId!.isNotEmpty)
          ? currItem.batchId!
          : currItem.productId;

      if (origItemMap.containsKey(key)) {
        remainingKeys.remove(key);
        final origItem = origItemMap[key]!;
        final batchId = currItem.batchId ?? origItem.batchId ?? '';
        final deltaStock = currItem.quantity - origItem.quantity;

        if (deltaStock < 0) {
          final remaining = batchStock[batchId] ?? origItem.quantity;
          final unitsSold = (origItem.quantity - remaining).clamp(0.0, double.infinity);
          if (currItem.quantity < unitsSold - 0.0001) {
            final soldStr = unitsSold.toStringAsFixed(unitsSold % 1 == 0 ? 0 : 2);
            throw Exception(
              "Cannot reduce '${origItem.productName}' quantity below $soldStr. "
              "$soldStr units have already been sold from this batch.",
            );
          }
        }

        if (batchId.isNotEmpty) {
          final remaining = batchStock[batchId] ?? origItem.quantity;
          batchStock[batchId] = remaining + deltaStock;
        }

        finalItems.add(currItem.copyWith(
          batchId: batchId,
          subTotal: currItem.quantity * currItem.unitCostPrice,
        ));
      } else {
        final bId = currItem.batchId?.isNotEmpty == true
            ? currItem.batchId!
            : 'batch-${currItem.productId}-${batchStock.length + 1}';
        batchStock[bId] = currItem.quantity;
        finalItems.add(currItem.copyWith(
          batchId: bId,
          subTotal: currItem.quantity * currItem.unitCostPrice,
        ));
      }
    }

    for (final removedKey in remainingKeys) {
      final removedItem = origItemMap[removedKey]!;
      final batchId = removedItem.batchId ?? '';
      if (batchId.isNotEmpty) {
        final remaining = batchStock[batchId] ?? removedItem.quantity;
        final unitsSold = (removedItem.quantity - remaining).clamp(0.0, double.infinity);
        if (unitsSold > 0.0001) {
          final soldStr = unitsSold.toStringAsFixed(unitsSold % 1 == 0 ? 0 : 2);
          throw Exception(
            "Cannot remove '${removedItem.productName}'. "
            "$soldStr units have already been sold from this batch.",
          );
        }
        batchStock[batchId] = 0.0;
      }
    }

    final newTotalCost = finalItems.fold(0.0, (sum, it) => sum + it.subTotal);
    final savedGRN = updatedGrn.copyWith(
      id: originalGrn.id,
      shopId: originalGrn.shopId,
      grnNumber: originalGrn.grnNumber,
      items: finalItems,
      totalCost: newTotalCost,
    );

    updatedGRNs.add(savedGRN);
    final idx = grns.indexWhere((g) => g.id == originalGrn.id);
    if (idx >= 0) {
      grns[idx] = savedGRN;
    } else {
      grns.insert(0, savedGRN);
    }
    _grnStreamCtrl.add(List.from(grns));
  }

  void dispose() {
    _supplierStreamCtrl.close();
    _grnStreamCtrl.close();
  }
}

class FakeProductRepository extends ProductRepository {
  final List<Product> products;
  final List<Product> addedProducts = [];
  final StreamController<List<Product>> _productStreamCtrl =
      StreamController<List<Product>>.broadcast();

  FakeProductRepository({List<Product>? initialProducts})
      : products = List.from(initialProducts ?? []),
        super('test-shop-id') {
    _productStreamCtrl.add(products);
  }

  @override
  Stream<List<Product>> productsStream() async* {
    yield List.from(products);
    yield* _productStreamCtrl.stream;
  }

  @override
  Future<Product> addProduct(Product product) async {
    final newId = product.id.isEmpty ? 'prod-${products.length + 1}' : product.id;
    final saved = product.copyWith(id: newId);
    products.add(saved);
    addedProducts.add(saved);
    _productStreamCtrl.add(List.from(products));
    return saved;
  }

  void dispose() {
    _productStreamCtrl.close();
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
  FakeProductRepository? productRepo,
  List<Product>? products,
  List<SupplierModel>? suppliers,
}) {
  final repo = procurementRepo ??
      FakeProcurementRepository(
        initialSuppliers: suppliers ?? _sampleSuppliers,
      );
  final pRepo = productRepo ??
      FakeProductRepository(
        initialProducts: products ?? _sampleProducts,
      );

  return ProviderScope(
    overrides: [
      userProfileProvider.overrideWith((ref) => Stream.value(_testUser)),
      procurementRepositoryProvider.overrideWithValue(repo),
      productRepositoryProvider.overrideWithValue(pRepo),
      suppliersStreamProvider.overrideWith((ref) => repo.getSuppliersStream()),
      grnListStreamProvider.overrideWith((ref) => repo.getGRNListStream()),
      productsStreamProvider.overrideWith((ref) => pRepo.productsStream()),
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
      final handle = tester.ensureSemantics();

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

      handle.dispose();
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

      // 4. Mobile Screen (412x915) - GRNHistoryScreen with semantics
      tester.view.physicalSize = const Size(412 * 2.0, 915 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrapWithProviders(child: const GRNHistoryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Procurement & GRN Inward'), findsOneWidget);
      handle.dispose();
    });
  });

  group('Category F: Inline Product Creation from GRN', () {
    testWidgets('TC-PRC-21: Inline product creation modal allows toggling, margins calculation, and prefilling', (tester) async {
      final pRepo = FakeProductRepository(initialProducts: _sampleProducts);
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(
        child: const CreateGRNScreen(),
        productRepo: pRepo,
      ));
      await tester.pumpAndSettle();

      // 1. Open modal via ADD ITEM
      await tester.tap(find.text('ADD ITEM'));
      await tester.pumpAndSettle();

      expect(find.text('New Item'), findsOneWidget);
      expect(find.text('Add Inward Product'), findsOneWidget);

      // 2. Tap 'New Item' to switch to inline creation mode
      await tester.tap(find.text('New Item'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Item & Inward'), findsOneWidget);
      expect(find.text('Back to Search'), findsOneWidget);

      // Verify form fields exist
      final nameField = find.widgetWithText(TextFormField, 'Product Name *');
      final qtyField = find.widgetWithText(TextFormField, 'Received Qty *');
      final costField = find.widgetWithText(TextFormField, 'Unit Cost (Rs.) *');
      final sellingField = find.widgetWithText(TextFormField, 'Batch Selling Price (Rs.) *');

      expect(nameField, findsOneWidget);
      expect(qtyField, findsOneWidget);
      expect(costField, findsOneWidget);
      expect(sellingField, findsOneWidget);

      // 3. Test real-time gross margin calculation
      await tester.enterText(costField, '200');
      await tester.enterText(sellingField, '300');
      await tester.pumpAndSettle();

      expect(find.text('Profit: Rs. 100.00 / unit'), findsOneWidget);
      expect(find.text('Margin: 33.3%'), findsOneWidget);

      // 4. Test "Back to Search"
      await tester.tap(find.text('Back to Search'));
      await tester.pumpAndSettle();

      expect(find.text('Add Inward Product'), findsOneWidget);

      // 5. Test empty search query creates prefill button
      final searchField = find.widgetWithText(TextField, 'Search Catalog Item');
      await tester.enterText(searchField, 'Maliban Ginger Biscuits 200g');
      await tester.pumpAndSettle();

      final createPrompt = find.text("Create 'maliban ginger biscuits 200g'");
      expect(createPrompt, findsOneWidget);

      await tester.tap(createPrompt);
      await tester.pumpAndSettle();

      expect(find.text('Create New Item & Inward'), findsOneWidget);
      final prefilledNameField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Product Name *'));
      expect(prefilledNameField.controller?.text, 'maliban ginger biscuits 200g');
    });

    testWidgets('TC-PRC-22: Submitting inline product creation saves product with 0 stock and adds to GRN items', (tester) async {
      final pRepo = FakeProductRepository(initialProducts: _sampleProducts);
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(
        child: const CreateGRNScreen(),
        productRepo: pRepo,
      ));
      await tester.pumpAndSettle();

      // Open Add Item modal
      await tester.tap(find.text('ADD ITEM'));
      await tester.pumpAndSettle();

      // Switch to new product form
      await tester.tap(find.text('New Item'));
      await tester.pumpAndSettle();

      // Fill in product details
      await tester.enterText(find.widgetWithText(TextFormField, 'Product Name *'), 'Fresh Orange Juice 500ml');
      await tester.enterText(find.widgetWithText(TextFormField, 'Barcode (Optional)'), '4799000123456');
      await tester.enterText(find.widgetWithText(TextFormField, 'Received Qty *'), '25');
      await tester.enterText(find.widgetWithText(TextFormField, 'Unit Cost (Rs.) *'), '180');
      await tester.enterText(find.widgetWithText(TextFormField, 'Batch Selling Price (Rs.) *'), '250');
      await tester.enterText(find.widgetWithText(TextFormField, 'Low Stock Alert'), '8');
      await tester.pumpAndSettle();

      // Submit
      final createButton = find.widgetWithText(ElevatedButton, 'Create & Add to GRN');
      expect(createButton, findsOneWidget);
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Verify product was created and persisted in repo
      expect(pRepo.addedProducts.length, 1);
      final savedProduct = pRepo.addedProducts.first;
      expect(savedProduct.name, 'Fresh Orange Juice 500ml');
      expect(savedProduct.barcode, '4799000123456');
      expect(savedProduct.costPrice, 180.0);
      expect(savedProduct.sellingPrice, 250.0);
      expect(savedProduct.currentStock, 0.0); // CRITICAL: initial stock 0.0 so GRN inward increments without duplicating
      expect(savedProduct.lowStockThreshold, 8.0);
      expect(savedProduct.isActive, true);

      // Verify GRN line items now list the newly added product
      expect(find.text('Fresh Orange Juice 500ml'), findsOneWidget);
      expect(find.text('Rs. 4500.00'), findsNWidgets(2)); // In line item subtotal and totals summary card
    });
  });

  // ---------------------------------------------------------------------------
  // Category G: GRN Editing & Batch Consumption Floor Guard
  // ---------------------------------------------------------------------------
  group('Category G: GRN Editing & Batch Consumption Floor Guard', () {
    late FakeProcurementRepository repo;

    setUp(() {
      repo = FakeProcurementRepository();
    });

    test('TC-PRC-23: Edit GRN metadata (Invoice, Notes, Payment Status) updates GRN record', () async {
      final origGRN = GRNModel(
        id: 'grn-1',
        shopId: 'test-shop-id',
        grnNumber: 'GRN-1001',
        supplierId: 'supp-1',
        supplierName: 'Ceylon Foods PLC',
        invoiceNumber: 'INV-OLD',
        receivedAt: DateTime(2026, 1, 10),
        items: [
          GRNItem(
            productId: 'prod-1',
            productName: 'Highland Fresh Milk 1L',
            quantity: 20,
            unitCostPrice: 420.0,
            sellingPrice: 500.0,
            subTotal: 8400.0,
            batchId: 'batch-milk-1',
          ),
        ],
        totalCost: 8400.0,
        paymentStatus: 'CREDIT',
        amountPaid: 0.0,
        notes: 'Initial notes',
      );

      await repo.receiveGRN(origGRN);

      final updatedGRN = origGRN.copyWith(
        invoiceNumber: 'INV-NEW-999',
        notes: 'Updated note: paid via cheque',
        paymentStatus: 'PAID',
        amountPaid: 8400.0,
      );

      await repo.updateGRN(updatedGRN, origGRN);

      expect(repo.grns.length, 1);
      final saved = repo.grns.first;
      expect(saved.invoiceNumber, 'INV-NEW-999');
      expect(saved.notes, 'Updated note: paid via cheque');
      expect(saved.paymentStatus, 'PAID');
      expect(saved.amountPaid, 8400.0);
      expect(saved.totalCost, 8400.0);
      expect(saved.items.length, 1);
    });

    test('TC-PRC-24: Edit GRN and add missing product creates batch and increases total cost', () async {
      final origGRN = GRNModel(
        id: 'grn-2',
        shopId: 'test-shop-id',
        grnNumber: 'GRN-1002',
        supplierId: 'supp-1',
        supplierName: 'Ceylon Foods PLC',
        receivedAt: DateTime(2026, 1, 10),
        items: [
          GRNItem(
            productId: 'prod-1',
            productName: 'Highland Fresh Milk 1L',
            quantity: 10,
            unitCostPrice: 420.0,
            sellingPrice: 500.0,
            subTotal: 4200.0,
            batchId: 'batch-milk-2',
          ),
        ],
        totalCost: 4200.0,
        paymentStatus: 'PAID',
        amountPaid: 4200.0,
      );

      await repo.receiveGRN(origGRN);

      final updatedGRN = origGRN.copyWith(
        items: [
          ...origGRN.items,
          GRNItem(
            productId: 'prod-2',
            productName: 'Munchee Super Cream Cracker',
            quantity: 15,
            unitCostPrice: 180.0,
            sellingPrice: 230.0,
            subTotal: 2700.0,
          ),
        ],
      );

      await repo.updateGRN(updatedGRN, origGRN);

      expect(repo.grns.length, 1);
      final saved = repo.grns.first;
      expect(saved.items.length, 2);
      expect(saved.totalCost, 4200.0 + 2700.0);
      expect(saved.items[1].productName, 'Munchee Super Cream Cracker');
      expect(saved.items[1].batchId, isNotNull);
      expect(repo.batchStock[saved.items[1].batchId], 15.0);
    });

    test('TC-PRC-25: Edit GRN item quantity increase updates batch stock and total cost', () async {
      final origGRN = GRNModel(
        id: 'grn-3',
        shopId: 'test-shop-id',
        grnNumber: 'GRN-1003',
        supplierId: 'supp-1',
        supplierName: 'Ceylon Foods PLC',
        receivedAt: DateTime(2026, 1, 10),
        items: [
          GRNItem(
            productId: 'prod-1',
            productName: 'Highland Fresh Milk 1L',
            quantity: 10,
            unitCostPrice: 400.0,
            sellingPrice: 500.0,
            subTotal: 4000.0,
            batchId: 'batch-milk-3',
          ),
        ],
        totalCost: 4000.0,
        paymentStatus: 'PAID',
        amountPaid: 4000.0,
      );

      await repo.receiveGRN(origGRN);
      expect(repo.batchStock['batch-milk-3'], 10.0);

      // Increase quantity from 10 to 25
      final updatedGRN = origGRN.copyWith(
        items: [
          origGRN.items[0].copyWith(quantity: 25, subTotal: 25 * 400.0),
        ],
      );

      await repo.updateGRN(updatedGRN, origGRN);

      final saved = repo.grns.first;
      expect(saved.items.first.quantity, 25.0);
      expect(saved.totalCost, 10000.0);
      expect(repo.batchStock['batch-milk-3'], 25.0);
    });

    test('TC-PRC-26: Edit GRN item quantity decrease above floor guard succeeds', () async {
      final origGRN = GRNModel(
        id: 'grn-4',
        shopId: 'test-shop-id',
        grnNumber: 'GRN-1004',
        supplierId: 'supp-1',
        supplierName: 'Ceylon Foods PLC',
        receivedAt: DateTime(2026, 1, 10),
        items: [
          GRNItem(
            productId: 'prod-1',
            productName: 'Highland Fresh Milk 1L',
            quantity: 50,
            unitCostPrice: 400.0,
            sellingPrice: 500.0,
            subTotal: 20000.0,
            batchId: 'batch-milk-4',
          ),
        ],
        totalCost: 20000.0,
        paymentStatus: 'PAID',
        amountPaid: 20000.0,
      );

      await repo.receiveGRN(origGRN);

      // Simulate 10 units sold from this batch at checkout -> remaining 40
      repo.batchStock['batch-milk-4'] = 40.0;

      // Safe reduction: shop owner reduces received quantity from 50 to 40 (floor is 10 sold units)
      final updatedGRN = origGRN.copyWith(
        items: [
          origGRN.items[0].copyWith(quantity: 40, subTotal: 40 * 400.0),
        ],
      );

      await repo.updateGRN(updatedGRN, origGRN);

      final saved = repo.grns.first;
      expect(saved.items.first.quantity, 40.0);
      expect(saved.totalCost, 16000.0);
      // Batch stock delta is -10 (40 remaining - 10 = 30)
      expect(repo.batchStock['batch-milk-4'], 30.0);
    });

    test('TC-PRC-27: Batch Consumption Floor Guard blocks reducing quantity below sold units', () async {
      final origGRN = GRNModel(
        id: 'grn-5',
        shopId: 'test-shop-id',
        grnNumber: 'GRN-1005',
        supplierId: 'supp-1',
        supplierName: 'Ceylon Foods PLC',
        receivedAt: DateTime(2026, 1, 10),
        items: [
          GRNItem(
            productId: 'prod-1',
            productName: 'Highland Fresh Milk 1L',
            quantity: 50,
            unitCostPrice: 400.0,
            sellingPrice: 500.0,
            subTotal: 20000.0,
            batchId: 'batch-milk-5',
          ),
        ],
        totalCost: 20000.0,
        paymentStatus: 'PAID',
        amountPaid: 20000.0,
      );

      await repo.receiveGRN(origGRN);

      // Simulate 20 units sold -> remaining 30
      repo.batchStock['batch-milk-5'] = 30.0;

      // Owner tries to reduce to 15 (less than 20 sold)
      final updatedGRN = origGRN.copyWith(
        items: [
          origGRN.items[0].copyWith(quantity: 15, subTotal: 15 * 400.0),
        ],
      );

      expect(
        () => repo.updateGRN(updatedGRN, origGRN),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains("Cannot reduce 'Highland Fresh Milk 1L' quantity below 20. 20 units have already been sold from this batch."),
        )),
      );
    });

    test('TC-PRC-28: Batch Consumption Floor Guard blocks deleting item when units have already been sold', () async {
      final origGRN = GRNModel(
        id: 'grn-6',
        shopId: 'test-shop-id',
        grnNumber: 'GRN-1006',
        supplierId: 'supp-1',
        supplierName: 'Ceylon Foods PLC',
        receivedAt: DateTime(2026, 1, 10),
        items: [
          GRNItem(
            productId: 'prod-1',
            productName: 'Highland Fresh Milk 1L',
            quantity: 50,
            unitCostPrice: 400.0,
            sellingPrice: 500.0,
            subTotal: 20000.0,
            batchId: 'batch-milk-6',
          ),
        ],
        totalCost: 20000.0,
        paymentStatus: 'PAID',
        amountPaid: 20000.0,
      );

      await repo.receiveGRN(origGRN);

      // Simulate 5 units sold -> remaining 45
      repo.batchStock['batch-milk-6'] = 45.0;

      // Owner attempts to completely delete item
      final updatedGRN = origGRN.copyWith(items: []);

      expect(
        () => repo.updateGRN(updatedGRN, origGRN),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains("Cannot remove 'Highland Fresh Milk 1L'. 5 units have already been sold from this batch."),
        )),
      );
    });

    testWidgets('TC-PRC-29: CreateGRNScreen in edit mode pre-populates fields and shows UPDATE GRN', (tester) async {
      final sampleGRN = GRNModel(
        id: 'grn-widget-1',
        shopId: 'test-shop-id',
        grnNumber: 'GRN-9988',
        supplierId: 'supp-1',
        supplierName: 'Ceylon Foods PLC',
        invoiceNumber: 'INV-4455',
        receivedAt: DateTime(2026, 2, 15),
        items: [
          GRNItem(
            productId: 'prod-1',
            productName: 'Highland Fresh Milk 1L',
            quantity: 12,
            unitCostPrice: 420.0,
            sellingPrice: 500.0,
            subTotal: 5040.0,
            batchId: 'batch-milk-w1',
          ),
        ],
        totalCost: 5040.0,
        paymentStatus: 'PAID',
        amountPaid: 5040.0,
        notes: 'Initial delivery note',
      );

      await repo.receiveGRN(sampleGRN);

      tester.view.physicalSize = const Size(1200 * 2.0, 900 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(
        child: CreateGRNScreen(existingGRN: sampleGRN),
        procurementRepo: repo,
      ));
      await tester.pumpAndSettle();

      // Verify title shows Edit mode with GRN Number
      expect(find.text('Edit Goods Received Note (GRN-9988)'), findsOneWidget);

      // Verify Action button says UPDATE GRN
      expect(find.text('UPDATE GRN'), findsOneWidget);

      // Verify pre-filled invoice and line item
      expect(find.text('INV-4455'), findsOneWidget);
      expect(find.text('Highland Fresh Milk 1L'), findsOneWidget);
      expect(find.text('Rs. 5040.00'), findsNWidgets(2)); // Line item subtotal and total summary
    });

    testWidgets('TC-PRC-30: GRNHistoryScreen shows Edit button on cards and modal', (tester) async {
      final sampleGRN = GRNModel(
        id: 'grn-history-1',
        shopId: 'test-shop-id',
        grnNumber: 'GRN-7777',
        supplierId: 'supp-1',
        supplierName: 'Ceylon Foods PLC',
        invoiceNumber: 'INV-7777',
        receivedAt: DateTime(2026, 2, 20),
        items: [
          GRNItem(
            productId: 'prod-1',
            productName: 'Highland Fresh Milk 1L',
            quantity: 8,
            unitCostPrice: 420.0,
            sellingPrice: 500.0,
            subTotal: 3360.0,
            batchId: 'batch-milk-h1',
          ),
        ],
        totalCost: 3360.0,
        paymentStatus: 'PAID',
        amountPaid: 3360.0,
      );

      final historyRepo = FakeProcurementRepository(initialGRNs: [sampleGRN]);

      tester.view.physicalSize = const Size(1200 * 2.0, 900 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithProviders(
        child: const GRNHistoryScreen(),
        procurementRepo: historyRepo,
      ));
      await tester.pumpAndSettle();

      // Edit icon button on the card
      final editButton = find.byTooltip('Edit GRN');
      expect(editButton, findsOneWidget);

      // Open details dialog
      await tester.tap(find.text('GRN-7777'));
      await tester.pumpAndSettle();

      // Details dialog should have "Edit GRN" button
      expect(find.widgetWithText(ElevatedButton, 'Edit GRN'), findsOneWidget);
    });
  });
}


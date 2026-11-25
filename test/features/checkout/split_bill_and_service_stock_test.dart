import 'package:flutter_test/flutter_test.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/reports/sale_model.dart';

void main() {
  group('TC-SPLIT: Split Bill Payment & Model Calculation Tests', () {
    test('TC-SPLIT-01: Sale model correctly serializes and deserializes splitPayments', () {
      final sale = Sale(
        id: 'sale_split_001',
        timestamp: DateTime(2026, 10, 8, 12, 0),
        totalAmount: 300.0,
        paymentMethod: 'SPLIT',
        customerId: 'cust_abc',
        amountPaid: 200.0,
        isFullyPaid: false,
        splitPayments: {
          'CASH': 200.0,
          'CREDIT': 100.0,
          'CARD': 0.0,
          'CASH_TENDERED': 500.0,
        },
      );

      final map = sale.toMap();
      expect(map['paymentMethod'], 'SPLIT');
      expect(map['totalAmount'], 300.0);
      expect(map['splitPayments'], isNotNull);
      expect(map['splitPayments']['CASH'], 200.0);
      expect(map['splitPayments']['CREDIT'], 100.0);

      final restored = Sale.fromMap(map);
      expect(restored.paymentMethod, 'SPLIT');
      expect(restored.totalAmount, 300.0);
      expect(restored.amountPaid, 200.0);
      expect(restored.isFullyPaid, false);
      expect(restored.splitPayments?['CASH'], 200.0);
      expect(restored.splitPayments?['CREDIT'], 100.0);
      expect(restored.splitPayments?['CASH_TENDERED'], 500.0);
    });

    test('TC-SPLIT-02: Change Due correctly calculates extra cash handed on split cash portion', () {
      // Bill of Rs. 300: 100 Credit, 200 Cash. Customer hands a 500 note for the 200 cash portion.
      final saleWithExtraCash = Sale(
        id: 'sale_split_002',
        timestamp: DateTime.now(),
        totalAmount: 300.0,
        paymentMethod: 'SPLIT',
        amountPaid: 200.0,
        splitPayments: {
          'CASH': 200.0,
          'CREDIT': 100.0,
          'CARD': 0.0,
          'CASH_TENDERED': 500.0,
        },
      );

      expect(saleWithExtraCash.cashTendered, 500.0);
      expect(saleWithExtraCash.changeDue, 300.0); // 500 tendered - 200 cash portion = 300 change due
    });

    test('TC-SPLIT-03: Change Due is 0 when exact cash is tendered on split bill', () {
      final saleExactCash = Sale(
        id: 'sale_split_003',
        timestamp: DateTime.now(),
        totalAmount: 300.0,
        paymentMethod: 'SPLIT',
        amountPaid: 200.0,
        splitPayments: {
          'CASH': 200.0,
          'CREDIT': 100.0,
          'CARD': 0.0,
          'CASH_TENDERED': 200.0,
        },
      );

      expect(saleExactCash.cashTendered, 200.0);
      expect(saleExactCash.changeDue, 0.0);
    });

    test('TC-SPLIT-04: Split without credit (Cash + Card) is marked fully paid', () {
      final saleCashCard = Sale(
        id: 'sale_split_004',
        timestamp: DateTime.now(),
        totalAmount: 500.0,
        paymentMethod: 'SPLIT',
        amountPaid: 500.0,
        isFullyPaid: true,
        splitPayments: {
          'CASH': 250.0,
          'CARD': 250.0,
          'CREDIT': 0.0,
        },
      );

      expect(saleCashCard.isFullyPaid, true);
      expect(saleCashCard.amountPaid, 500.0);
      expect(saleCashCard.totalAmount, 500.0);
    });
  });

  group('TC-SVC: Service Items & Stock Floor Protection Tests', () {
    test('TC-SVC-01: Product.isService identifies both productType=SERVICE and stockType=service', () {
      final physicalProduct = Product(
        id: 'p1',
        name: 'Anchor Milk',
        sellingPrice: 1150.0,
        productType: 'PHYSICAL',
        stockType: 'unit',
        createdAt: DateTime.now(),
      );

      final serviceProduct1 = Product(
        id: 's1',
        name: 'Haircut Service',
        sellingPrice: 800.0,
        productType: 'SERVICE',
        stockType: 'service',
        createdAt: DateTime.now(),
      );

      final serviceProduct2 = Product(
        id: 's2',
        name: 'Custom Tailoring Fee',
        sellingPrice: 1500.0,
        productType: 'SERVICE',
        stockType: 'unit',
        createdAt: DateTime.now(),
      );

      expect(physicalProduct.isService, false);
      expect(serviceProduct1.isService, true);
      expect(serviceProduct2.isService, true);
    });

    test('TC-SVC-02: GRN catalog filter safely excludes service items from inward receiving', () {
      final catalog = [
        Product(
          id: 'p1',
          name: 'Sugar 1kg',
          sellingPrice: 280.0,
          currentStock: 10.0,
          productType: 'PHYSICAL',
          stockType: 'weight',
          createdAt: DateTime.now(),
        ),
        Product(
          id: 's1',
          name: 'Delivery Fee',
          sellingPrice: 350.0,
          currentStock: 0.0,
          productType: 'SERVICE',
          stockType: 'service',
          createdAt: DateTime.now(),
        ),
        Product(
          id: 'p2',
          name: 'Dhal 500g',
          sellingPrice: 190.0,
          currentStock: 25.0,
          productType: 'PHYSICAL',
          stockType: 'weight',
          createdAt: DateTime.now(),
        ),
      ];

      // Replicating create_grn_screen filteredProducts logic
      final filteredForGRN = catalog.where((p) {
        if (!p.isActive) return false;
        if (p.isService) return false;
        return true;
      }).toList();

      expect(filteredForGRN.length, 2);
      expect(filteredForGRN.any((p) => p.name == 'Delivery Fee'), false);
      expect(filteredForGRN.map((p) => p.name), containsAll(['Sugar 1kg', 'Dhal 500g']));
    });
  });
}

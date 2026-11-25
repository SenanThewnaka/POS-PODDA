import 'package:flutter_test/flutter_test.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/services/barcode_sticker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProduct1 = Product(
    id: 'prod-1',
    name: 'Atlas CR 80pg Single Rule Book',
    sellingPrice: 160.0,
    costPrice: 130.0,
    barcode: '4792039011012',
    stockType: 'unit',
    currentStock: 25.0,
    createdAt: DateTime.now(),
  );

  final testProduct2 = Product(
    id: 'prod-2',
    name: 'White Sugar (සීනි 1kg)',
    sellingPrice: 280.0,
    costPrice: 250.0,
    barcode: '299912345678',
    stockType: 'unit',
    currentStock: 50.0,
    createdAt: DateTime.now(),
  );

  group('BarcodeLabelFormatExtension Tests', () {
    test('all formats have non-empty display names and descriptions', () {
      for (final format in BarcodeLabelFormat.values) {
        expect(format.displayName, isNotEmpty);
        expect(format.description, isNotEmpty);
      }
    });

    test('isSheet and isContinuousRoll flags accurately classify formats', () {
      expect(BarcodeLabelFormat.a4Grid30.isSheet, isTrue);
      expect(BarcodeLabelFormat.a4Grid24.isSheet, isTrue);
      expect(BarcodeLabelFormat.thermal50x30.isSheet, isFalse);

      expect(BarcodeLabelFormat.roll58.isContinuousRoll, isTrue);
      expect(BarcodeLabelFormat.roll80.isContinuousRoll, isTrue);
      expect(BarcodeLabelFormat.roll58.isSheet, isFalse);
    });
  });

  group('BarcodeLabelItem Tests', () {
    test('fromProduct converts standard unit product correctly', () {
      final item = BarcodeLabelItem.fromProduct(testProduct1, quantity: 5);
      expect(item.productId, 'prod-1');
      expect(item.productName, 'Atlas CR 80pg Single Rule Book');
      expect(item.barcode, '4792039011012');
      expect(item.price, 160.0);
      expect(item.unitText, isNull);
      expect(item.quantity, 5);
    });

    test('fromProduct formats measurable product price per kg', () {
      final measurableProd = Product(
        id: 'prod-sugar',
        name: 'Bulk Sugar',
        sellingPrice: 0.28, // 0.28 per gram = 280 per kg
        costPrice: 0.24,
        barcode: '299988881234',
        stockType: 'weight',
        baseUnit: 'g',
        currentStock: 50000.0,
        createdAt: DateTime.now(),
      );

      final item = BarcodeLabelItem.fromProduct(measurableProd);
      expect(item.price, 280.0);
      expect(item.unitText, '/kg');
    });
  });

  group('BarcodeStickerService PDF Generation Tests', () {
    test('generates valid 50x30mm thermal sticker PDF with multiple pages', () async {
      final items = [
        BarcodeLabelItem.fromProduct(testProduct1, quantity: 3),
        BarcodeLabelItem.fromProduct(testProduct2, quantity: 2),
      ];

      final config = const BarcodeLabelConfig(
        format: BarcodeLabelFormat.thermal50x30,
        storeName: 'KANDY SUPER MART',
        showStoreName: true,
        showPrice: true,
        showProductName: true,
        showBarcodeText: true,
      );

      final doc = await BarcodeStickerService.generatePdf(items: items, config: config);
      expect(doc.document.pdfPageList.pages.length, 5); // 3 + 2 = 5 single sticker pages

      final bytes = await doc.save();
      expect(bytes.length, greaterThan(1000));
    });

    test('generates valid 40x30mm mini sticker PDF', () async {
      final items = [
        BarcodeLabelItem.fromProduct(testProduct1, quantity: 2),
      ];

      final config = const BarcodeLabelConfig(
        format: BarcodeLabelFormat.thermal40x30,
        storeName: 'STATIONERY HUB',
      );

      final doc = await BarcodeStickerService.generatePdf(items: items, config: config);
      expect(doc.document.pdfPageList.pages.length, 2);

      final bytes = await doc.save();
      expect(bytes.length, greaterThan(1000));
    });

    test('generates valid 58mm and 80mm continuous thermal roll PDF', () async {
      final items = [
        BarcodeLabelItem.fromProduct(testProduct1, quantity: 5),
      ];

      final doc58 = await BarcodeStickerService.generatePdf(
        items: items,
        config: const BarcodeLabelConfig(format: BarcodeLabelFormat.roll58),
      );
      expect(doc58.document.pdfPageList.pages.length, greaterThanOrEqualTo(1));

      final doc80 = await BarcodeStickerService.generatePdf(
        items: items,
        config: const BarcodeLabelConfig(format: BarcodeLabelFormat.roll80),
      );
      expect(doc80.document.pdfPageList.pages.length, greaterThanOrEqualTo(1));
    });

    test('generates A4 30-label sheet grid with automatic multi-page overflow', () async {
      // 35 labels -> Should span 2 pages (30 on page 1, 5 on page 2)
      final items = [
        BarcodeLabelItem.fromProduct(testProduct1, quantity: 20),
        BarcodeLabelItem.fromProduct(testProduct2, quantity: 15),
      ];

      final config = const BarcodeLabelConfig(
        format: BarcodeLabelFormat.a4Grid30,
        storeName: 'CITY GROCERY',
        showDate: true,
      );

      final doc = await BarcodeStickerService.generatePdf(items: items, config: config);
      expect(doc.document.pdfPageList.pages.length, 2);

      final bytes = await doc.save();
      expect(bytes.length, greaterThan(2000));
    });

    test('generates A4 24-label sheet grid correctly', () async {
      final items = [
        BarcodeLabelItem.fromProduct(testProduct1, quantity: 24),
      ];

      final config = const BarcodeLabelConfig(
        format: BarcodeLabelFormat.a4Grid24,
      );

      final doc = await BarcodeStickerService.generatePdf(items: items, config: config);
      expect(doc.document.pdfPageList.pages.length, 1);

      final bytes = await doc.save();
      expect(bytes.length, greaterThan(2000));
    });

    test('gracefully handles empty labels without throwing', () async {
      final doc = await BarcodeStickerService.generatePdf(
        items: [],
        config: const BarcodeLabelConfig(),
      );
      expect(doc.document.pdfPageList.pages.length, 1);

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}

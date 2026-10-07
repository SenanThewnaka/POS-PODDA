import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sme_buddy/features/inventory/data/sri_lanka_products_catalog.dart';
import 'package:sme_buddy/features/inventory/services/barcode_lookup_service.dart';

void main() {
  group('SriLankaProductsCatalog Unit Tests', () {
    test('contains rich catalog of Sri Lankan retail goods', () {
      expect(SriLankaProductsCatalog.items.length, greaterThanOrEqualTo(50));
      expect(SriLankaProductsCatalog.categories, containsAll([
        'All',
        'Biscuits & Bakery',
        'Dairy & Beverages',
        'Grocery & Cooking',
        'Personal Care & Cleaning',
        'Health & Stationery',
      ]));
    });

    test('findByBarcode matches Sri Lankan products faithfully', () {
      final munchee = SriLankaProductsCatalog.findByBarcode('4792022011210');
      expect(munchee, isNotNull);
      expect(munchee!.name, contains('Munchee Super Cream Cracker'));
      expect(munchee.brand, 'Munchee');
      expect(munchee.sellingPrice, 420.0);
      expect(munchee.costPrice, 380.0);

      final anchor = SriLankaProductsCatalog.findByBarcode('9414200115014');
      expect(anchor, isNotNull);
      expect(anchor!.name, contains('Anchor'));
      expect(anchor.brand, 'Anchor');

      final sunlight = SriLankaProductsCatalog.findByBarcode('8901030701015');
      expect(sunlight, isNotNull);
      expect(sunlight!.name, contains('Sunlight'));

      final nonExistent = SriLankaProductsCatalog.findByBarcode('0000000000000');
      expect(nonExistent, isNull);
    });

    test('search filters items by name, barcode, and brand', () {
      final resultsByName = SriLankaProductsCatalog.search('Cream Cracker');
      expect(resultsByName.isNotEmpty, true);
      expect(resultsByName.any((i) => i.brand == 'Munchee'), true);
      expect(resultsByName.any((i) => i.brand == 'Maliban'), true);

      final resultsByBrand = SriLankaProductsCatalog.search('Elephant House');
      expect(resultsByBrand.length, greaterThanOrEqualTo(4));

      final resultsByBarcode = SriLankaProductsCatalog.search('4792011011016');
      expect(resultsByBarcode.length, 1);
      expect(resultsByBarcode.first.name, contains('Ginger Beer'));
    });

    test('getByCategory filters catalog items accurately', () {
      final biscuits = SriLankaProductsCatalog.getByCategory('Biscuits & Bakery');
      expect(biscuits.every((i) => i.category == 'Biscuits & Bakery'), true);
      expect(biscuits.length, greaterThanOrEqualTo(10));

      final all = SriLankaProductsCatalog.getByCategory('All');
      expect(all.length, SriLankaProductsCatalog.items.length);
    });

    test('PreloadCatalogItem.toProduct converts to valid Product with stock', () {
      final item = SriLankaProductsCatalog.findByBarcode('4792022011210')!;
      final product = item.toProduct(initialStock: 25.0);

      expect(product.name, item.name);
      expect(product.barcode, item.barcode);
      expect(product.sellingPrice, item.sellingPrice);
      expect(product.costPrice, item.costPrice);
      expect(product.currentStock, 25.0);
      expect(product.productType, 'PHYSICAL');
      expect(product.isActive, true);
    });
  });

  group('BarcodeLookupService Unit Tests', () {
    test('instant lookup resolves local Sri Lankan catalog offline without HTTP call', () async {
      // Mock client that throws if called
      final mockClient = MockClient((request) async {
        throw Exception('Network should not be contacted for local catalog match');
      });

      final service = BarcodeLookupService(client: mockClient);
      final result = await service.lookup('4792022011210');

      expect(result, isNotNull);
      expect(result!.barcode, '4792022011210');
      expect(result.name, contains('Munchee Super Cream Cracker'));
      expect(result.brand, 'Munchee');
      expect(result.suggestedPrice, 420.0);
      expect(result.source, 'Sri Lanka Catalog');
    });

    test('queries Open Food Facts API when barcode is not in local catalog', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/api/v2/product/7622210449283.json'));
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {
              'product_name': 'Oreo Original',
              'brands': 'Mondelez',
              'quantity': '154g',
              'categories': 'Biscuits, Cookies',
            }
          }),
          200,
        );
      });

      final service = BarcodeLookupService(client: mockClient);
      final result = await service.lookup('7622210449283');

      expect(result, isNotNull);
      expect(result!.barcode, '7622210449283');
      expect(result.name, contains('Oreo Original'));
      expect(result.brand, 'Mondelez');
      expect(result.source, 'Open Food Facts');
      expect(result.category, 'Biscuits');
    });

    test('returns null when Open Food Facts reports product not found (status: 0)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'status': 0, 'product': null}), 200);
      });

      final service = BarcodeLookupService(client: mockClient);
      final result = await service.lookup('9999999999999');

      expect(result, isNull);
    });

    test('handles network exceptions gracefully and returns null without crashing', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network down');
      });

      final service = BarcodeLookupService(client: mockClient);
      final result = await service.lookup('9999999999999');

      expect(result, isNull);
    });
  });
}

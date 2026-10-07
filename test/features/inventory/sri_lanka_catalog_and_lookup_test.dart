import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sme_buddy/features/inventory/data/sri_lanka_products_catalog.dart';
import 'package:sme_buddy/features/inventory/services/barcode_lookup_service.dart';

void main() {
  group('SriLankaProductsCatalog Unit Tests', () {
    test('contains rich catalog of Sri Lankan retail goods across FMCG, Stationery, Hardware', () {
      expect(SriLankaProductsCatalog.items.length, greaterThanOrEqualTo(100));
      expect(SriLankaProductsCatalog.categories, containsAll([
        'All',
        'Biscuits & Bakery',
        'Dairy & Beverages',
        'Grocery & Cooking',
        'Personal Care & Cleaning',
        'Stationery & Bookshop',
        'Hardware & Electrical',
        'Pharmacy & Health',
      ]));
    });

    test('storePresets contain distinct presets for retail verticals', () {
      expect(SriLankaProductsCatalog.storePresets.length, greaterThanOrEqualTo(5));
      final presetIds = SriLankaProductsCatalog.storePresets.map((p) => p.id).toList();
      expect(presetIds, containsAll(['all', 'grocery', 'stationery', 'hardware', 'pharmacy']));
    });

    test('findByBarcode matches Sri Lankan FMCG products faithfully', () {
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

    test('findByBarcode matches Sri Lankan Stationery products faithfully', () {
      final atlasCR = SriLankaProductsCatalog.findByBarcode('4792039011012');
      expect(atlasCR, isNotNull);
      expect(atlasCR!.name, contains('Atlas CR Single Rule Book'));
      expect(atlasCR.category, 'Stationery & Bookshop');
      expect(atlasCR.brand, 'Atlas');

      final chootyPen = SriLankaProductsCatalog.findByBarcode('4792039013016');
      expect(chootyPen, isNotNull);
      expect(chootyPen!.name, contains('Atlas Chooty Ballpoint Pen'));

      final doubleAPaper = SriLankaProductsCatalog.findByBarcode('8851234011019');
      expect(doubleAPaper, isNotNull);
      expect(doubleAPaper!.name, contains('Double A A4 Copier Paper'));
    });

    test('findByBarcode matches Sri Lankan Hardware & Electrical products faithfully', () {
      final orangeBulb = SriLankaProductsCatalog.findByBarcode('4792018011015');
      expect(orangeBulb, isNotNull);
      expect(orangeBulb!.name, contains('Orange Electric 9W LED Bulb'));
      expect(orangeBulb.category, 'Hardware & Electrical');
      expect(orangeBulb.brand, 'Orange Electric');

      final slonCement = SriLankaProductsCatalog.findByBarcode('4792047011011');
      expect(slonCement, isNotNull);
      expect(slonCement!.name, contains('S-Lon PVC Solvent Cement'));
      expect(slonCement.brand, 'S-Lon');

      final wd40 = SriLankaProductsCatalog.findByBarcode('5032227100018');
      expect(wd40, isNotNull);
      expect(wd40!.name, contains('WD-40'));

      final alteco = SriLankaProductsCatalog.findByBarcode('4901234011017');
      expect(alteco, isNotNull);
      expect(alteco!.name, contains('Alteco 110 Super Glue'));
    });

    test('search filters items by name, barcode, and brand', () {
      final resultsByName = SriLankaProductsCatalog.search('Cream Cracker');
      expect(resultsByName.isNotEmpty, true);
      expect(resultsByName.any((i) => i.brand == 'Munchee'), true);
      expect(resultsByName.any((i) => i.brand == 'Maliban'), true);

      final resultsByBrand = SriLankaProductsCatalog.search('Orange Electric');
      expect(resultsByBrand.length, greaterThanOrEqualTo(5));

      final resultsByStationery = SriLankaProductsCatalog.search('Atlas');
      expect(resultsByStationery.length, greaterThanOrEqualTo(10));

      final resultsByBarcode = SriLankaProductsCatalog.search('4792011011016');
      expect(resultsByBarcode.length, 1);
      expect(resultsByBarcode.first.name, contains('Ginger Beer'));
    });

    test('getByCategory filters catalog items accurately', () {
      final biscuits = SriLankaProductsCatalog.getByCategory('Biscuits & Bakery');
      expect(biscuits.every((i) => i.category == 'Biscuits & Bakery'), true);
      expect(biscuits.length, greaterThanOrEqualTo(10));

      final stationery = SriLankaProductsCatalog.getByCategory('Stationery & Bookshop');
      expect(stationery.every((i) => i.category == 'Stationery & Bookshop'), true);
      expect(stationery.length, greaterThanOrEqualTo(20));

      final hardware = SriLankaProductsCatalog.getByCategory('Hardware & Electrical');
      expect(hardware.every((i) => i.category == 'Hardware & Electrical'), true);
      expect(hardware.length, greaterThanOrEqualTo(30));

      final all = SriLankaProductsCatalog.getByCategory('All');
      expect(all.length, SriLankaProductsCatalog.items.length);
    });

    test('getByCategories returns items matching multiple categories', () {
      final combined = SriLankaProductsCatalog.getByCategories([
        'Stationery & Bookshop',
        'Hardware & Electrical',
      ]);
      expect(combined.any((i) => i.category == 'Stationery & Bookshop'), true);
      expect(combined.any((i) => i.category == 'Hardware & Electrical'), true);
      expect(combined.every((i) => i.category == 'Stationery & Bookshop' || i.category == 'Hardware & Electrical'), true);
    });

    test('PreloadCatalogItem.toProduct converts to valid Product with stock', () {
      final item = SriLankaProductsCatalog.findByBarcode('4792018011015')!;
      final product = item.toProduct(initialStock: 15.0);

      expect(product.name, item.name);
      expect(product.barcode, item.barcode);
      expect(product.sellingPrice, item.sellingPrice);
      expect(product.costPrice, item.costPrice);
      expect(product.currentStock, 15.0);
      expect(product.productType, 'PHYSICAL');
      expect(product.isActive, true);
    });
  });

  group('BarcodeLookupService Unit Tests', () {
    test('instant lookup resolves local Sri Lankan catalog offline without HTTP call', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network should not be contacted for local catalog match');
      });

      final service = BarcodeLookupService(client: mockClient);
      final result = await service.lookup('4792018011015');

      expect(result, isNotNull);
      expect(result!.barcode, '4792018011015');
      expect(result.name, contains('Orange Electric 9W LED Bulb'));
      expect(result.brand, 'Orange Electric');
      expect(result.suggestedPrice, 490.0);
      expect(result.source, 'Sri Lanka Catalog');
    });

    test('instant lookup resolves local Sri Lankan stationery offline', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network should not be contacted for local catalog match');
      });

      final service = BarcodeLookupService(client: mockClient);
      final result = await service.lookup('4792039011012');

      expect(result, isNotNull);
      expect(result!.barcode, '4792039011012');
      expect(result.name, contains('Atlas CR Single Rule Book'));
      expect(result.brand, 'Atlas');
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

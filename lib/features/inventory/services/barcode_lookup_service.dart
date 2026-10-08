import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../data/sri_lanka_products_catalog.dart';

class BarcodeProductResult {
  final String barcode;
  final String name;
  final String? brand;
  final String? category;
  final double? suggestedPrice;
  final double? suggestedCost;
  final String source; // 'Sri Lanka Catalog' or 'Open Food Facts'

  const BarcodeProductResult({
    required this.barcode,
    required this.name,
    this.brand,
    this.category,
    this.suggestedPrice,
    this.suggestedCost,
    required this.source,
  });
}

class BarcodeLookupService {
  final http.Client? _client;
  BarcodeLookupService({http.Client? client}) : _client = client;

  Future<BarcodeProductResult?> lookup(String rawBarcode) async {
    final barcode = rawBarcode.trim();
    if (barcode.isEmpty) return null;

    // 1. Instant check in Sri Lanka Offline Master Catalog (0ms, offline-safe)
    final localMatch = SriLankaProductsCatalog.findByBarcode(barcode);
    if (localMatch != null) {
      return BarcodeProductResult(
        barcode: barcode,
        name: localMatch.name,
        brand: localMatch.brand,
        category: localMatch.category,
        suggestedPrice: localMatch.sellingPrice,
        suggestedCost: localMatch.costPrice,
        source: 'Sri Lanka Catalog',
      );
    }

    // 2. Live Open Food Facts API query
    try {
      final client = _client ?? http.Client();
      final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
      final response = await client.get(
        url,
        headers: {
          'User-Agent': 'POSPodda/1.4.1 (contact: synthora.dev@gmail.com; lang: en)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 1 && data['product'] != null) {
          final prod = data['product'] as Map<String, dynamic>;

          final rawName = (prod['product_name'] ?? prod['product_name_en'] ?? '').toString().trim();
          final brand = (prod['brands'] ?? '').toString().trim();
          final quantity = (prod['quantity'] ?? '').toString().trim();

          String title = rawName;
          if (title.isEmpty && brand.isNotEmpty) {
            title = brand;
          } else if (brand.isNotEmpty && !title.toLowerCase().contains(brand.toLowerCase())) {
            title = '$brand $title';
          }
          if (quantity.isNotEmpty && !title.toLowerCase().contains(quantity.toLowerCase())) {
            title = '$title $quantity';
          }

          if (title.isNotEmpty) {
            String? category;
            final categories = prod['categories'];
            if (categories is String && categories.isNotEmpty) {
              category = categories.split(',').first.trim();
            }

            return BarcodeProductResult(
              barcode: barcode,
              name: title,
              brand: brand.isNotEmpty ? brand : null,
              category: category,
              source: 'Open Food Facts',
            );
          }
        }
      }
    } catch (_) {
      // Timeout, offline, or network error - fail silently without blocking the UI
    }

    return null;
  }
}

final barcodeLookupServiceProvider = Provider<BarcodeLookupService>((ref) {
  return BarcodeLookupService();
});

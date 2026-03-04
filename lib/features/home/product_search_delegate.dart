import 'package:flutter/material.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';

class ProductSearchDelegate extends SearchDelegate<Product?> {
  final List<Product> allProducts;

  ProductSearchDelegate(this.allProducts);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final cleanQuery = query.toLowerCase().trim();
    
    if (cleanQuery.isEmpty) {
       return const Center(child: Text("Type to search items..."));
    }

    // Filter logic
    final results = allProducts.where((p) {
      final nameMatch = p.name.toLowerCase().contains(cleanQuery);
      final barcodeMatch = p.barcode?.contains(cleanQuery) ?? false;
      return nameMatch || barcodeMatch;
    }).toList();

    if (results.isEmpty) {
      return const Center(child: Text("No items found."));
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final product = results[index];
        return ListTile(
          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Rs. ${product.sellingPrice} • Stock: ${product.currentStock}"),
          trailing: const Icon(Icons.add_shopping_cart, color: Colors.cyanAccent),
          onTap: () {
            close(context, product);
          },
        );
      },
    );
  }
}

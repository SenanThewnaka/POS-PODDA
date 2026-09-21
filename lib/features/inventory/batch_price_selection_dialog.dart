import 'package:flutter/material.dart';
import '../../features/inventory/product_model.dart';
import '../../features/inventory/stock_batch_model.dart';

class BatchPriceSelectionDialog extends StatelessWidget {
  final Product product;
  final List<StockBatch> batches;

  const BatchPriceSelectionDialog({
    super.key,
    required this.product,
    required this.batches,
  });

  static Future<double?> show(BuildContext context, Product product, List<StockBatch> batches) {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BatchPriceSelectionDialog(product: product, batches: batches),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group batches by price to show remaining stock for each price
    Map<double, double> priceStockMap = {};
    for (var b in batches) {
       priceStockMap[b.sellingPrice] = (priceStockMap[b.sellingPrice] ?? 0) + b.currentStock;
    }
    
    final prices = priceStockMap.keys.toList()..sort();

    return AlertDialog(
      title: Text("Select Price: ${product.name}"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: prices.map((price) {
          final qty = priceStockMap[price]!;
          
          // Determine Display Price (High Unit)
          double displayPrice = price;
          String unitLabel = "";
          
          if (product.baseUnit == 'g') {
             displayPrice = price * 1000;
             unitLabel = "/kg";
          } else if (product.baseUnit == 'kg') {
             unitLabel = "/kg";
          } else if (product.baseUnit == 'ml') {
             displayPrice = price * 1000;
             unitLabel = "/L";
          } else if (product.baseUnit == 'l') {
             unitLabel = "/L";
          } else if (product.baseUnit == 'cm') {
             displayPrice = price * 100;
             unitLabel = "/m";
          } else if (product.baseUnit == 'm') {
             unitLabel = "/m";
          }

          // Format Qty Label
          String qtyLabel = "Qty: ${qty.toInt()}";
          if (product.stockType != 'unit') {
             qtyLabel = UnitFormatter.format(qty, product.baseUnit);
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50,
                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blue.shade900,
                  elevation: 0,
                  side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent.withValues(alpha: 0.5) : Colors.blue.shade100),
                ),
                onPressed: () {
                  Navigator.pop(context, price);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           "Rs. ${displayPrice.toStringAsFixed(2)}", 
                           style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                         ),
                         if (unitLabel.isNotEmpty) 
                           Text(unitLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                       ],
                     ),
                     Text(
                       qty > 0 ? qtyLabel : 'Out', 
                       style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)
                     ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null), 
          child: const Text("CANCEL")
        )
      ],
    );
  }
}

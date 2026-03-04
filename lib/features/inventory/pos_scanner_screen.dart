import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/stock_batch_model.dart';
import 'package:sme_buddy/features/home/cart_provider.dart';
import 'package:sme_buddy/features/home/add_to_cart_sheet.dart';
import 'package:sme_buddy/features/inventory/batch_price_selection_dialog.dart';
class POSScannerScreen extends ConsumerStatefulWidget {
  const POSScannerScreen({super.key});

  @override
  ConsumerState<POSScannerScreen> createState() => _POSScannerScreenState();
}

class _POSScannerScreenState extends ConsumerState<POSScannerScreen> {
  // Controller to manage camera state (start/stop)
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  bool _isProcessing = false; // Prevent double scans while modal is open

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return; // Ignore if busy

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _handleBarcode(barcode.rawValue!);
        break; // Only handle first code
      }
    }
  }

  void _handleBarcode(String code) async {
    setState(() => _isProcessing = true);
    
    try {
      // 1. Fetch Product
      final product = await ref.read(productRepositoryProvider).getProductByBarcode(code);

      if (mounted) {
        if (product != null) {
          // 2. Multi-Batch Logic
          final batches = await ref.read(productRepositoryProvider).getActiveBatches(product.id);
          
          if (batches.isEmpty) {
             // Fallback to Product Price (Fast Path)
             await _addToCart(product, product.sellingPrice);
          } else {
             // Group by Price
             final uniquePrices = batches.map((b) => b.sellingPrice).toSet().toList();
             
             if (uniquePrices.length == 1) {
                // Scenario A: Single Price Match (Fast Path)
                await _addToCart(product, uniquePrices.first);
             } else {
                // Scenario B: Multi-Price Conflict (Dialog)
                await _showPriceSelectionDialog(product, batches);
             }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Product not found for code: $code"), duration: const Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _addToCart(Product product, double price) async {
    // OLD: Direct Add
    /*
    ref.read(cartProvider.notifier).addToCart(product, quantity: 1, overridePrice: price);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(...);
    */

    // NEW: Open Sheet
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Full height capability
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: AddToCartSheet(product: product, overridePrice: price),
        );
      },
    );
  }

  Future<void> _showPriceSelectionDialog(Product product, List<StockBatch> batches) async {
    final selectedPrice = await BatchPriceSelectionDialog.show(context, product, batches);
    if (selectedPrice != null) {
      await _addToCart(product, selectedPrice);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("POS Scanner"),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay Guide
          Center(
            child: Container(
              width: 300,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Helper Text
          const Positioned(
            bottom: 50,
            left: 0, 
            right: 0,
            child: Text(
              "Point at Barcode", 
              textAlign: TextAlign.center, 
              style: TextStyle(color: Colors.white, fontSize: 18, backgroundColor: Colors.black54)
            ),
          )
        ],
      ),
    );
  }
}

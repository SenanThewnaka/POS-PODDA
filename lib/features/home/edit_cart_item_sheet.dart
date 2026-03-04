import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/home/cart_provider.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/utils/quantity_parser.dart';
import 'package:sme_buddy/utils/unit_formatter.dart';
import 'package:sme_buddy/utils/glass_card.dart';

class EditCartItemSheet extends ConsumerStatefulWidget {
  final CartItem cartItem;
  final String cartItemId; // Changed from productId to cartItemId (UUID)

  const EditCartItemSheet({super.key, required this.cartItem, required this.cartItemId});

  @override
  ConsumerState<EditCartItemSheet> createState() => _EditCartItemSheetState();
}

class _EditCartItemSheetState extends ConsumerState<EditCartItemSheet> {
  late double _quantity;
  final _smartInputController = TextEditingController();
  final _overridePriceController = TextEditingController();
  final _descriptionController = TextEditingController(); // Description Editor
  String _parsedFeedback = "";

  @override
  void initState() {
    super.initState();
    _quantity = widget.cartItem.quantity;
    
    // Init Description
    _descriptionController.text = widget.cartItem.description ?? "";

    // Init Total Price
    double currentTotal = widget.cartItem.subTotal;
    _overridePriceController.text = currentTotal.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
  }

  void _parseInput(String val) {
    if (widget.cartItem.product.stockType == 'unit') return;
    
    double qty = QuantityParser.parse(val, widget.cartItem.product.baseUnit!);
    setState(() {
      _quantity = qty;
      _parsedFeedback = _quantity > 0 ? "New Qty: ${UnitFormatter.format(_quantity, widget.cartItem.product.baseUnit)}" : "";
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Financials based on CURRENT Input state
    double standardTotal = widget.cartItem.product.sellingPrice * _quantity;
    double totalCost = widget.cartItem.product.costPrice * _quantity;

    // 2. Check Override (Total Price)
    double? overrideTotal = double.tryParse(_overridePriceController.text);
    
    double finalTotalSelling = standardTotal;
    
    if (overrideTotal != null && overrideTotal >= 0) {
      finalTotalSelling = overrideTotal;
    }

    // Effective Unit Price for Cart Update
    double? effectiveUnitPrice;
    if (_quantity > 0) {
       effectiveUnitPrice = finalTotalSelling / _quantity;
    }
    
    double profit = finalTotalSelling - totalCost;

    return Container(
      padding: EdgeInsets.only(
        top: 24, 
        left: 24, 
        right: 24, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 24
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             // Handle
            Center(
              child: Container(
                width: 50, height: 5,
                decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                     "Edit ${widget.cartItem.product.name}", 
                     style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    // Update: Remove by CartItemId
                    ref.read(cartProvider.notifier).removeFromCart(widget.cartItemId);
                    Navigator.pop(context);
                  },
                )
              ],
            ),
            
            Text(
              "Current Stock: ${UnitFormatter.format(widget.cartItem.product.currentStock, widget.cartItem.product.baseUnit)}", 
               style: const TextStyle(color: Colors.grey),
            ),
            const Divider(height: 32),

            // INPUT SECTION
            if (widget.cartItem.product.stockType == 'unit' || widget.cartItem.product.productType == 'SERVICE') 
              _buildUnitCounter()
            else 
              _buildSmartInput(),
            
            const SizedBox(height: 16),
            
            // TOTAL PRICE OVERRIDE
             // TOTAL PRICE OVERRIDE
             TextField(
              controller: _overridePriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (val) => setState((){}), 
              onTap: () => _overridePriceController.selection = TextSelection(baseOffset: 0, extentOffset: _overridePriceController.text.length),
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Total Bill Amount (Override)",
                labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                hintText: "Standard: Rs. ${standardTotal.toStringAsFixed(2)}",
                prefixText: "Rs. ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent)),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                helperText: "Modify the final price for this quantity",
                helperStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
              ),
            ),
            
            // DESCRIPTION EDITOR (New for Services)
            if (widget.cartItem.product.productType == 'SERVICE') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: "Description / Notes",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  prefixIcon: const Icon(Icons.description),
                ),
              ),
            ],

            const SizedBox(height: 24),
            
            // Financials Preview
            // Financials Preview
             Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 2)
                ]
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("New Total:", style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
                      Text("Rs. ${finalTotalSelling.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total Cost:", style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey)), 
                      Text("Rs. ${totalCost.toStringAsFixed(2)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Profit Margin:", style: TextStyle(fontSize: 14, color: Colors.greenAccent)),
                      Text("Rs. ${profit.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ACTION BUTTONS
            ElevatedButton(
              onPressed: _quantity > 0 ? () {
                // Remove Stock Check for Service
                if (widget.cartItem.product.productType != 'SERVICE') {
                   if (_quantity > widget.cartItem.product.currentStock) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Only ${UnitFormatter.format(widget.cartItem.product.currentStock, widget.cartItem.product.baseUnit)} in stock!"),
                        backgroundColor: Colors.red,
                      ));
                      return;
                   }
                }

                // UPDATE CART ITEM (Using new updateItemDetails)
                ref.read(cartProvider.notifier).updateItemDetails(
                   widget.cartItemId,
                   newQuantity: _quantity,
                   newPrice: effectiveUnitPrice,
                   newDescription: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null
                );
                
                Navigator.pop(context);
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent,
                foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 10,
                shadowColor: (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
              ),
              child: const Text("UPDATE CART", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildUnitCounter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 24),
        Text("${_quantity.toInt()}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(width: 24),
        IconButton.filledTonal(
          onPressed: () => setState(() => _quantity++),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _buildSmartInput() {
    return Column(
      children: [
        TextField(
          controller: _smartInputController,
          onChanged: _parseInput,
          onTap: () => _smartInputController.selection = TextSelection(baseOffset: 0, extentOffset: _smartInputController.text.length),
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            labelText: "New Quantity (e.g. 2kg)",
            labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
            hintText: "Current: ${UnitFormatter.format(widget.cartItem.quantity, widget.cartItem.product.baseUnit)}",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent)),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            prefixIcon: Icon(Icons.scale, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent),
          ),
        ),
        if (_parsedFeedback.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_parsedFeedback, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

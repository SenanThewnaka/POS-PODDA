import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/unit_formatter.dart';

class BreakBulkScreen extends ConsumerStatefulWidget {
  const BreakBulkScreen({super.key});

  @override
  ConsumerState<BreakBulkScreen> createState() => _BreakBulkScreenState();
}

class _BreakBulkScreenState extends ConsumerState<BreakBulkScreen> {
  Product? _sourceProduct;
  Product? _targetProduct;
  
  final _sourceQtyController = TextEditingController(text: "1");
  final _targetQtyController = TextEditingController();

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      appBar: AppBar(
        title: Text("Stock Converter (Break Bulk)", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err', style: TextStyle(color: Colors.red))),
        data: (products) {
          // Filter out Services (Cannot break bulk services)
          final tangibleProducts = products.where((p) => p.productType != 'SERVICE').toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 24),

                // SOURCE CARD
                _buildSelectionCard(
                  title: "FROM (Source)",
                  icon: Icons.upload_rounded,
                  isSource: true,
                  isDark: isDark,
                  products: tangibleProducts,
                  selected: _sourceProduct,
                  onChanged: (val) => setState(() {
                    _sourceProduct = val;
                    if (_sourceProduct?.id == _targetProduct?.id) _targetProduct = null;
                  }),
                ),
                
                const SizedBox(height: 16),
                Center(child: Icon(Icons.arrow_downward_rounded, size: 32, color: Colors.cyanAccent.withValues(alpha: 0.8))),
                const SizedBox(height: 16),

                // TARGET CARD
                _buildSelectionCard(
                  title: "TO (Target)",
                  icon: Icons.download_rounded,
                  isSource: false,
                  isDark: isDark,
                  products: tangibleProducts.where((p) => p.id != _sourceProduct?.id).toList(),
                  selected: _targetProduct,
                  onChanged: (val) => setState(() => _targetProduct = val),
                  enabled: _sourceProduct != null,
                ),

                const SizedBox(height: 24),

                // RATIO INPUT
                if (_sourceProduct != null && _targetProduct != null)
                  _buildRatioSection(isDark),

                const SizedBox(height: 32),

                // ACTION BUTTON
                _buildConvertButton(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Convert stock from one form to another.\nExample: 1 Sack -> 50 Packets, or 1 Bundle -> 500 Sheets.",
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required IconData icon,
    required bool isSource,
    required bool isDark,
    required List<Product> products,
    required Product? selected,
    required Function(Product?) onChanged,
    bool enabled = true,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      border: Border.all(color: isSource ? Colors.orangeAccent.withValues(alpha: 0.3) : Colors.greenAccent.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isSource ? Colors.orangeAccent : Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Product>(
            isExpanded: true,
            decoration: InputDecoration(
              labelText: isSource ? "Select Bulk Item" : "Select Unit Item",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              enabled: enabled,
            ),
            value: selected,
            items: products.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text(
                  "${p.name} (Stock: ${UnitFormatter.format(p.currentStock, p.baseUnit)})",
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: enabled ? onChanged : null,
            dropdownColor: isDark ? Colors.grey[900] : Colors.white,
          ),
          if (selected != null) ...[
             const SizedBox(height: 8),
             Text(
               "Current Price: Rs. ${selected.sellingPrice}", 
               style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[700]),
             ),
          ]
        ],
      ),
    );
  }

  Widget _buildRatioSection(bool isDark) {
     return GlassCard(
       padding: const EdgeInsets.all(20),
       borderRadius: 24,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text("Conversion Ratio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
           const SizedBox(height: 16),
           Row(
             children: [
                Expanded(
                  child: Column(
                    children: [
                      Text("Take (Source)", style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _sourceQtyController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.orange.withValues(alpha: 0.1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          suffixText: _sourceProduct?.baseUnit ?? 'Unit'
                        ),
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                  child: Icon(Icons.arrow_forward, color: isDark ? Colors.white24 : Colors.black26),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text("Create (Target)", style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _targetQtyController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: "???",
                          filled: true,
                          fillColor: Colors.green.withValues(alpha: 0.1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          suffixText: _targetProduct?.baseUnit ?? 'Unit'
                        ),
                      )
                    ],
                  ),
                ),
             ],
           ),
         ],
       ),
     );
  }

  Widget _buildConvertButton(BuildContext context) {
    bool isValid = _sourceProduct != null && _targetProduct != null && 
                   _sourceQtyController.text.isNotEmpty && _targetQtyController.text.isNotEmpty;

    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: (isValid && !_isLoading) ? _executeConversion : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyanAccent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: Colors.cyanAccent.withValues(alpha: 0.4),
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.black)
          : const Text("CONVERT STOCK NOW", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
    );
  }

  Future<void> _executeConversion() async {
     setState(() => _isLoading = true);
     try {
       double srcQty = double.parse(_sourceQtyController.text);
       double tgtQty = double.parse(_targetQtyController.text);

       if (srcQty <= 0 || tgtQty <= 0) throw "Quantities must be greater than 0";

       await ref.read(productRepositoryProvider).breakBulk(
         _sourceProduct!.id,
         _targetProduct!.id,
         srcQty,
         tgtQty
       );

       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Conversion Successful! Stock Updated."), backgroundColor: Colors.green)
         );
         Navigator.pop(context);
       }

     } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error: ${e.toString().replaceAll("Exception: ", "")}"), backgroundColor: Colors.red)
         );
         setState(() => _isLoading = false);
       }
     }
  }
}

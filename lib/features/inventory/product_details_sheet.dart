import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/stock_batch_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/utils/unit_formatter.dart';
import 'package:sme_buddy/utils/quantity_parser.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/features/reports/sales_repository.dart';
import 'package:sme_buddy/utils/glass_card.dart';

class ProductDetailsSheet extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailsSheet({super.key, required this.product});

  @override
  ConsumerState<ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends ConsumerState<ProductDetailsSheet> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  late TextEditingController _lowStockController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    // For measurable, detailed sheets typically show 'Price per Unit'.
    // If we want to support 'Price per KG' editing here, we need to do the math interactively or just show base price.
    // Let's stick to Base Price for simplicity in this V1 detail view, or detect if measurable and show appropriate label.
    // Actually, if I show raw base price for 'g', it's 0.03.
    // It is better to detect unit and multipy.
    
    double initialPrice = widget.product.sellingPrice;
    double initialCost = widget.product.costPrice;
    double? initialLowStock = widget.product.lowStockThreshold;
    
    if (widget.product.baseUnit == 'g' || widget.product.baseUnit == 'ml') {
       initialPrice *= 1000;
       initialCost *= 1000;
       // initialLowStock handled below
    } else if (widget.product.baseUnit == 'cm') {
       initialPrice *= 100;
       initialCost *= 100;
       // initialLowStock handled below
    }

    String initialLowStockText = "";
    if (widget.product.lowStockThreshold != null && widget.product.lowStockThreshold! > 0) {
       if (widget.product.stockType == 'unit') {
          initialLowStockText = widget.product.lowStockThreshold!.toStringAsFixed(0);
       } else {
          initialLowStockText = UnitFormatter.format(widget.product.lowStockThreshold!, widget.product.baseUnit);
       }
    }

    _priceController = TextEditingController(text: initialPrice.toStringAsFixed(2));
    _costController = TextEditingController(text: initialCost.toStringAsFixed(2));
    _lowStockController = TextEditingController(text: initialLowStockText);
  }

  @override
  Widget build(BuildContext context) {
    String unitLabel = "Item";
    if (widget.product.baseUnit == 'g') unitLabel = "KG";
    if (widget.product.baseUnit == 'ml') unitLabel = "L";
    if (widget.product.baseUnit == 'cm') unitLabel = "M";

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
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 50, height: 5,
                  decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(10)),
                ),
              ),
            const SizedBox(height: 20),
            
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Edit Product Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                   icon: const Icon(Icons.close),
                   onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            const SizedBox(height: 20),

            // Edit Fields
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Product Name", border: OutlineInputBorder()),
              onTap: () => _nameController.selection = TextSelection(baseOffset: 0, extentOffset: _nameController.text.length),
            ),
            const SizedBox(height: 16),
            const Text("Pricing & Inventory", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            
            if (widget.product.isVariablePrice)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(child: Text("Variable Price Product. Price and Cost are entered at checkout.", style: TextStyle(fontSize: 12))),
                  ],
                ),
              )
            else ...[
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                   labelText: "Selling Price",
                   prefixText: "Rs. ",
                   border: OutlineInputBorder(),
                ),
                onTap: () => _priceController.selection = TextSelection(baseOffset: 0, extentOffset: _priceController.text.length),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                   labelText: "Cost Price",
                   prefixText: "Rs. ",
                   border: OutlineInputBorder(),
                ),
                onTap: () => _costController.selection = TextSelection(baseOffset: 0, extentOffset: _costController.text.length),
              ),
              const SizedBox(height: 16),
            ],

            if (widget.product.productType != 'SERVICE') 
              TextField(
                controller: _lowStockController,
                keyboardType: TextInputType.text, // Allow "5kg"
                decoration: InputDecoration(
                   labelText: "Low Stock Alert ($unitLabel)",
                   hintText: widget.product.stockType == 'unit' ? "e.g. 5" : "e.g. 1kg",
                   border: const OutlineInputBorder(),
                ),
                onTap: () => _lowStockController.selection = TextSelection(baseOffset: 0, extentOffset: _lowStockController.text.length),
              ),
            const SizedBox(height: 20),

            // Barcode Actions
            if (widget.product.barcode != null) ...[
               const Text("Barcode Actions", style: TextStyle(fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               Card(
                 child: ListTile(
                   leading: Icon(Icons.qr_code, color: Theme.of(context).iconTheme.color),
                   title: Text(widget.product.barcode!),
                   subtitle: const Text("Tap to Print/Share"),
                   trailing: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       IconButton(
                         icon: const Icon(Icons.print, color: Colors.blue),
                         onPressed: _printBarcode,
                       ),
                       IconButton(
                         icon: const Icon(Icons.share, color: Colors.green),
                         onPressed: _shareBarcode,
                       ),
                     ],
                   ),
                 ),
               ),
               const SizedBox(height: 20),
            ],

            // Save Button
            // Permissions Check
            Consumer(builder: (context, ref, child) {
              final user = ref.watch(userProfileProvider).value;
              if (user == null) return const SizedBox();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // DELETE BUTTON (If permitted)
                   if (user.hasPermission(AppPermissions.canDeleteProducts))
                   Padding(
                     padding: const EdgeInsets.only(bottom: 16),
                     child: OutlinedButton.icon(
                       onPressed: _deleteProduct,
                       icon: const Icon(Icons.delete, color: Colors.red),
                       label: const Text("DELETE PRODUCT", style: TextStyle(color: Colors.red)),
                       style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                     ),
                   ),

                   // SAVE BUTTON (If permitted)
                   if (user.hasPermission(AppPermissions.canAddProducts)) // Assuming Add implies Edit
                   SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        child: const Text("SAVE CHANGES", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                   ) else 
                   const Center(child: Text("Read Only Access", style: TextStyle(color: Colors.grey))),
                ],
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
    );
  }

  void _saveChanges() {
     // Parse Values
     final name = _nameController.text;
     double sellingPrice = double.tryParse(_priceController.text) ?? 0.0;
     double costPrice = double.tryParse(_costController.text) ?? 0.0;
     double? lowStock;

     // Handle Unit Conversion for Measurables
     if (widget.product.baseUnit == 'g' || widget.product.baseUnit == 'ml') {
        sellingPrice /= 1000;
        costPrice /= 1000;
        if (_lowStockController.text.isNotEmpty) {
           lowStock = QuantityParser.parse(_lowStockController.text, widget.product.baseUnit!);
        }
     } else if (widget.product.baseUnit == 'cm') {
        sellingPrice /= 100;
        costPrice /= 100;
        if (_lowStockController.text.isNotEmpty) {
           lowStock = QuantityParser.parse(_lowStockController.text, widget.product.baseUnit!);
        }
     } else {
        // Standard Unit
        if (_lowStockController.text.isNotEmpty) {
           lowStock = double.tryParse(_lowStockController.text);
        }
     }

     final updatedProduct = widget.product.copyWith(
       name: name,
       sellingPrice: sellingPrice,
       costPrice: costPrice,
       lowStockThreshold: lowStock,
     );

     ref.read(productRepositoryProvider).updateProduct(updatedProduct);
     if (mounted) Navigator.pop(context);
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Updated!")));
  }

  void _deleteProduct() async {
     // 1. Check for Sales History
     final hasSales = await ref.read(salesRepositoryProvider).hasSalesForProduct(widget.product.id);
     
     if (hasSales) {
        if (!mounted) return;
        showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
            title: const Text("Cannot Delete Product"),
            content: const Text("This product has sales records associated with it. For audit purposes, you cannot delete it.\n\nPlease deactivate it instead."),
            actions: [
              TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("OK")),
            ],
          )
        );
        return;
     }

     if (!mounted) return;
     final confirm = await showDialog<bool>(
       context: context, 
       builder: (_) => AlertDialog(
         title: const Text("Delete Product?"),
         content: Text("Are you sure you want to delete ${widget.product.name}?"),
         actions: [
           TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text("CANCEL")),
           TextButton(onPressed: ()=>Navigator.pop(context, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
         ],
       )
     );
     
     if (confirm == true) {
        await ref.read(productRepositoryProvider).deleteProduct(widget.product.id);
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Deleted")));
     }
  }

  Future<void> _printBarcode() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (pw.Context context) {
        return pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
               pw.Text(widget.product.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
               pw.SizedBox(height: 5),
               pw.BarcodeWidget(
                 data: widget.product.barcode!,
                 barcode: pw.Barcode.code128(),
                 width: 150, height: 50
               ),
               pw.Text(widget.product.barcode!, style: const pw.TextStyle(fontSize: 8)),
            ],
          )
        );
      }
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _shareBarcode() async {
    final pdf = pw.Document();
    // Same PDF generation
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (pw.Context context) {
        return pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
               pw.Text(widget.product.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
               pw.SizedBox(height: 5),
               pw.BarcodeWidget(
                 data: widget.product.barcode!,
                 barcode: pw.Barcode.code128(),
                 width: 150, height: 50
               ),
               pw.Text(widget.product.barcode!, style: const pw.TextStyle(fontSize: 8)),
            ],
          )
        );
      }
    ));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'barcode_${widget.product.name}.pdf');
  }


}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/stock_batch_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/inventory/simple_scanner_screen.dart';
import 'package:sme_buddy/utils/unit_formatter.dart';
import 'package:sme_buddy/utils/quantity_parser.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/features/reports/sales_repository.dart';
import 'dart:math';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/barcode_utils.dart';

class ProductDashboardScreen extends ConsumerStatefulWidget {
  final Product product;
  const ProductDashboardScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDashboardScreen> createState() => _ProductDashboardScreenState();
}

class _ProductDashboardScreenState extends ConsumerState<ProductDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  
  // Batch Editing State
  bool _isEditingBatch = false;

  @override
  late TextEditingController _lowStockController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController(text: widget.product.name);
    _barcodeController = TextEditingController(text: widget.product.barcode ?? "");
    
    // Initialize Low Stock Controller with smart formatting
    String initialLowStockText = "";
    if (widget.product.lowStockThreshold != null && widget.product.lowStockThreshold! > 0) {
       if (widget.product.stockType == 'unit') {
          initialLowStockText = widget.product.lowStockThreshold!.toStringAsFixed(0);
       } else {
          initialLowStockText = UnitFormatter.format(widget.product.lowStockThreshold!, widget.product.baseUnit);
       }
    }
    _lowStockController = TextEditingController(text: initialLowStockText);
    
    _tabController.addListener(() {
      setState(() {}); // Rebuild to toggle FAB
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(productRepositoryProvider);

    return StreamBuilder<Product>(
      stream: repo.getProductStream(widget.product.id),
      initialData: widget.product,
      builder: (context, snapshot) {
        // Use the latest product data, fallback to widget.product if loading/error
          final product = snapshot.data ?? widget.product;
        final isService = product.stockType == 'service';

        return GlassScaffold(
          appBar: AppBar(
            title: Text(product.name, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
            backgroundColor: Colors.transparent,
            bottom: isService ? null : TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent,
              labelColor: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent,
              unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54,
              tabs: const [
                Tab(text: "Stock Batches"),
                Tab(text: "Edit Details"),
              ],
            ),
          ),
          body: isService 
             ? _buildProductEditForm(product)
             : TabBarView(
                controller: _tabController,
                children: [
                  _buildBatchList(product),
                  _buildProductEditForm(product),
                ],
              ),
          floatingActionButton: (!isService && _tabController.index == 0) 
            ? FloatingActionButton.extended(
                onPressed: () => _showRestockDialog(product), 
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                icon: const Icon(Icons.add), 
                label: const Text("Receive Stock", style: TextStyle(fontWeight: FontWeight.bold))
              )
            : null,
        );
      }
    );
  }


  // --- TAB 1: STOCK BATCHES ---
  
  Widget _buildBatchList(Product product) {
    return FutureBuilder<List<StockBatch>>(
      future: ref.watch(productRepositoryProvider).getActiveBatches(product.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
        
        final batches = snapshot.data ?? [];
        
        // Only show "No Stock" if truly empty (No batches AND No Legacy Stock)
        if (batches.isEmpty && product.currentStock <= 0) {
           return Center(child: Text("No Active Stock Batches", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)));
        }

        // Show total stock summary at top
        double totalStock = batches.fold(0, (sum, b) => sum + b.currentStock);
        
        return Column(
          children: [
            // HUD - TOTAL STOCK
            Container(
               margin: const EdgeInsets.only(bottom: 16),
               decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  boxShadow: [
                     BoxShadow(
                       color: (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent).withValues(alpha: 0.2), 
                       blurRadius: 20, 
                       spreadRadius: -5,
                       offset: const Offset(0, 10)
                     )
                  ]
               ),
               child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  borderRadius: 24,
                  margin: EdgeInsets.zero,
                  border: Border.all(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent).withValues(alpha: 0.3),
                    width: 1.5
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Row(
                         children: [
                           Icon(Icons.inventory_2_outlined, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent),
                           const SizedBox(width: 12),
                           Text("ACTIVE STOCK", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7))),
                         ],
                       ),
                       Text(
                         UnitFormatter.format(totalStock, product.baseUnit),
                         style: TextStyle(
                           fontSize: 24, 
                           fontWeight: FontWeight.bold, 
                           color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                           shadows: [
                              Shadow(color: (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent).withValues(alpha: 0.5), blurRadius: 10)
                           ]
                         ),
                       )
                    ],
                  ),
               ),
            ),

             // LEGACY STOCK MIGRATION
             if (batches.isEmpty && product.currentStock > 0)
               GlassCard(
                 margin: const EdgeInsets.all(16),
                 padding: const EdgeInsets.all(12),
                 border: Border.all(color: Colors.orangeAccent),
                 child: Column(
                   children: [
                      const Text("Legacy Stock Detected", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                      Text("This product has stock but no batch history. Convert it to a batch to manage it.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _migrateLegacyStock(product.currentStock), 
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                        child: const Text("CONVERT TO BATCH")
                      )
                   ],
                 ),
               ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 200), // Increased bottom padding for FAB to 200 (Aggressive fix)
                itemCount: batches.length,
                separatorBuilder: (_,__) => const SizedBox(height: 12),
    // List Builder Item
    itemBuilder: (context, index) {
       final batch = batches[index];
       return Container(
         margin: const EdgeInsets.only(bottom: 12),
         decoration: BoxDecoration(
           borderRadius: BorderRadius.circular(16),
           boxShadow: batch.isActive ? [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
           ] : null,
         ),
         child: GlassCard(
           borderRadius: 16,
           padding: const EdgeInsets.all(16),
           border: batch.isActive 
              ? Border.all(color: Colors.white.withValues(alpha: 0.1))
              : Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         DateFormat('MMM dd, yyyy').format(batch.createdAt),
                         style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
                       ),
                       if (!batch.isActive)
                         const Text("INACTIVE", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                     ],
                   ),
                     IconButton(
                     icon: const Icon(Icons.edit, size: 20, color: Colors.blueAccent),
                     visualDensity: VisualDensity.compact,
                     onPressed: () => _showEditBatchDialog(batch, product),
                   )
                ],
              ),
              Divider(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text("Selling Price", style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
                        Text("Rs. ${_formatPrice(batch.sellingPrice)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                     ],
                   ),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text("Cost Price", style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
                        Text("Rs. ${_formatPrice(batch.costPrice)}", style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
                     ],
                   ),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                        Text("Stock Left", style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
                        Text(
                          UnitFormatter.format(batch.currentStock, product.baseUnit),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                        ),
                     ],
                   ),
                ],
              )
           ],
         ),
        ), 
       );
    },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatPrice(double val) {
    if (widget.product.baseUnit == 'g' || widget.product.baseUnit == 'ml') {
       return (val * 1000).toStringAsFixed(2);
    }
    return val.toStringAsFixed(2);
  }

  void _showRestockDialog(Product product) {
    try {
      final qtyController = TextEditingController();
      // Default to last known price or product price
      double initialPrice = product.sellingPrice;
      double initialCost = product.costPrice;
      
      // Convert to display unit
      if (product.baseUnit == 'g' || product.baseUnit == 'ml') {
         initialPrice *= 1000;
         initialCost *= 1000;
      }
      
      final priceController = TextEditingController(text: initialPrice.toStringAsFixed(2));
      final costController = TextEditingController(text: initialCost.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        String? error;
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text("Receive New Stock"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Enter details for the new batch/shipment."),
                  const SizedBox(height: 16),
                  if (error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(error!, style: TextStyle(color: Colors.red[900], fontSize: 13))),
                        ],
                      ),
                    ),
                  TextField(
                    controller: qtyController,
                    decoration: InputDecoration(
                      labelText: "Quantity Received", 
                      hintText: product.stockType == 'unit' ? "e.g. 10" : "e.g. 50kg",
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                       if (error != null) setStateSB(() => error = null);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Selling Price", border: OutlineInputBorder()),
                          onTap: () {
                             if (priceController.text == '0.00' || priceController.text == '0') priceController.clear();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: costController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Cost Price", border: OutlineInputBorder()),
                          onTap: () {
                            if (costController.text == '0.00' || costController.text == '0') costController.clear();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text("CANCEL")
                ),
                  ElevatedButton(
                  onPressed: () {
                    final pVal = double.tryParse(priceController.text) ?? 0;
                    final cVal = double.tryParse(costController.text) ?? 0;

                    void executeSave() {
                      // 1. Close Dialog
                      Navigator.of(ctx).pop();
                      
                      // 2. Run Background Task
                      Future(() async {
                        try {
                          // Parse Logic
                          String baseUnit = product.baseUnit ?? 'unit';
                          
                          // Validate Unit
                          if (product.stockType != 'unit' && !_validateUnitCompatibility(qtyController.text, baseUnit)) {
                             throw "Invalid Unit! Do not mix Volume (L) with Weight (Kg).";
                          }
                          
                          double qty = 0.0;
                          if (product.stockType == 'unit') {
                             qty = double.tryParse(qtyController.text) ?? 0;
                          } else {
                             qty = QuantityParser.parse(qtyController.text, baseUnit);
                          }
  
                          if (qty <= 0) throw "Invalid Quantity.";
                          
                          double price = double.tryParse(priceController.text) ?? 0;
                          double cost = double.tryParse(costController.text) ?? 0;
  
                           // Convert Price/Cost
                          if (baseUnit == 'g' || baseUnit == 'ml') {
                             price /= 1000;
                             cost /= 1000;
                          } else if (baseUnit == 'cm') {
                             price /= 100;
                             cost /= 100;
                          }
  
                          final batch = StockBatch(
                            id: '', 
                            productId: product.id,
                            costPrice: cost,
                            sellingPrice: price,
                            currentStock: qty,
                            createdAt: DateTime.now(),
                          );
  
                          // Optimistic SnackBar
                          if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Adding stock...")));
                          }
  
                          await ref.read(productRepositoryProvider).addStockBatch(product.id, batch);
                          
                          if (mounted) {
                             ScaffoldMessenger.of(context).hideCurrentSnackBar();
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stock Added Successfully!"), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                           if (mounted) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                               // Show error safely
                              showDialog(context: context, builder: (c) => AlertDialog(
                                 title: const Text("Error Adding Stock"),
                                 content: Text(e.toString().replaceAll("Exception: ", "")),
                                 actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]
                              ));
                           }
                        }
                      });
                    }

                    // VALIDATION CHECKS
                    if (pVal < cVal) {
                       showDialog(
                         context: context,
                         builder: (c) => AlertDialog(
                           title: const Text("Check Pricing"),
                           content: const Text("The Selling Price is lower than the Cost Price.\nDo you want to continue?"),
                           actions: [
                             TextButton(onPressed: () => Navigator.pop(c), child: const Text("EDIT")),
                             ElevatedButton(
                               onPressed: () {
                                 Navigator.pop(c); // Close warning
                                 executeSave(); // Proceed
                               }, 
                               child: const Text("CONTINUE")
                             ),
                           ],
                         )
                       );
                    } else {
                       executeSave();
                    }
                  },
                  child: const Text("ADD STOCK"),
                )
              ],
            );
          }
        );
      }
    );
    } catch (e) {
       // Only fallback if Dialog fails to OPEN (rare)
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("System Error: $e"), backgroundColor: Colors.red));
    }
  }

  void _showEditBatchDialog(StockBatch batch, Product product) {
    // Determine display multipliers
    double multiplier = 1.0;
    if (widget.product.baseUnit == 'g' || widget.product.baseUnit == 'ml') multiplier = 1000.0;
    
    final priceCtrl = TextEditingController(text: (batch.sellingPrice * multiplier).toStringAsFixed(2));
    final costCtrl  = TextEditingController(text: (batch.costPrice * multiplier).toStringAsFixed(2));
    
    // For Stock, if Measurable, show in readable format (e.g. 5kg) or just base units? 
    // Editing stock is dangerous/complex (affects aggregate). Let's allow simple number edit for now but warn.
    // Or just use UnitFormatter logic reverse? 
    // Let's stick to simple numeric input for Stock (in base units / multiplier specific? No, stock is stored in base).
    // Let's allow editing Qty in "Display Unit" (e.g. KG)
    
    final qtyCtrl = TextEditingController(text: (batch.currentStock / (multiplier == 1000 ? 1000 : 1)).toStringAsFixed(3)); 

    
    // We need StatefulBuilder to toggle the Switch
    showDialog(
      context: context,
      builder: (ctx) {
        bool isActive = batch.isActive;
        String? error;
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
             title: const Text("Edit Batch Details"),
             content: SingleChildScrollView(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    if (error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(error!, style: TextStyle(color: Colors.red[900], fontSize: 13))),
                          ],
                        ),
                      ),
                    SwitchListTile(
                      title: const Text("Active Status"),
                      subtitle: Text(isActive ? "Available for Sale" : "Hidden from Sales"),
                      value: isActive,
                      onChanged: (val) => setStateSB(() => isActive = val),
                    ),
                    const Divider(),
                      TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Selling Price"),
                      onTap: () => priceCtrl.selection = TextSelection(baseOffset: 0, extentOffset: priceCtrl.text.length),
                    ),
                    TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Cost Price"),
                      onTap: () => costCtrl.selection = TextSelection(baseOffset: 0, extentOffset: costCtrl.text.length),
                    ),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: widget.product.stockType == 'unit' ? TextInputType.number : TextInputType.text,
                      decoration: InputDecoration(
                         labelText: "Current Stock (${widget.product.baseUnit == 'g' ? 'KG' : (widget.product.baseUnit == 'ml' ? 'L' : 'Units')})",
                         helperText: "Modify only if physically correcting",
                      ),
                      onChanged: (_) {
                         if (error != null) setStateSB(() => error = null);
                      },
                      onTap: () => qtyCtrl.selection = TextSelection(baseOffset: 0, extentOffset: qtyCtrl.text.length),
                    ),
                 ],
               ),
             ),
             actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx), 
                  child: const Text("CANCEL")
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    setStateSB(() {
                       error = null;
                       isLoading = true;
                    });
                    
                    try {
                      double p = double.tryParse(priceCtrl.text) ?? 0;
                      double c = double.tryParse(costCtrl.text) ?? 0;
                      
                      // Validate Unit Compatibility
                      if (widget.product.stockType != 'unit' && !_validateUnitCompatibility(qtyCtrl.text, widget.product.baseUnit ?? 'unit')) {
                         throw "Invalid Unit! Do not mix Volume (L/ml) with Weight (kg/g).";
                      }
    
                      // Smart Parse for Qty
                      double q = 0.0;
                      if (widget.product.stockType == 'unit') {
                         q = double.tryParse(qtyCtrl.text) ?? 0;
                      } else {
                         q = QuantityParser.parse(qtyCtrl.text, widget.product.baseUnit ?? 'unit');
                      }
                      
                      // Check if parsing failed
                      if (q == 0 && qtyCtrl.text.trim() != '0' && qtyCtrl.text.trim() != '0.0') {
                         throw "Invalid Quantity format.";
                      }
                      
                      if (multiplier > 1) {
                         p /= multiplier;
                         c /= multiplier;
                      }
                      
                      final updated = batch.copyWith(
                        sellingPrice: p,
                        costPrice: c,
                        currentStock: q,
                        isActive: isActive,
                      );
                      
                      await ref.read(productRepositoryProvider).updateStockBatch(product.id, updated, oldStock: batch.currentStock);
                      
                      // Auto-Deactivate Check (Manual)
                      // Current (Live) Stock - Old Batch Stock + New Batch Stock
                      double predictedStock = product.currentStock - batch.currentStock + updated.currentStock;
                      
                      if (predictedStock <= 0) {
                         await ref.read(productRepositoryProvider).deactivateProduct(product.id);
                         if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Auto-Deactivated (Stock is 0)"), backgroundColor: Colors.orange));
                         }
                      } else {
                         if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Batch Updated!")));
                         }
                      }

                      if (ctx.mounted) {
                         Navigator.of(ctx).pop();
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                         setStateSB(() {
                            error = e.toString().replaceAll("Exception: ", "");
                            isLoading = false;
                         });
                      }
                    }
                  },
                  child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text("SAVE"),
                )
             ],
            );
          }
        );
      }
    );
  }

  Future<void> _migrateLegacyStock(double amount) async {
     final batch = StockBatch(
       id: '',
       productId: widget.product.id,
       costPrice: widget.product.costPrice,
       sellingPrice: widget.product.sellingPrice,
       currentStock: amount,
       createdAt: DateTime.now(),
     );
     // We define a special "migration" method or just add batch? 
     // If we use addStockBatch, it ADDS to aggregate. But aggregate is ALREADY there.
     // So we need a way to "Initialize" batch without touching aggregate.
     // OR, we just add the batch and then manually correct the aggregate back?
     // Better: `addStockBatch` handles aggregate update.
     // If we use it, `currentStock` will double (Legacy + New Batch).
     // WE NEED A NEW REPO METHOD: `createBatchForExistingStock`.
     // OR: We just construct it here? 
     // Repository layer is safer. Let's add `migrateLegacyStock` to repo.
     await ref.read(productRepositoryProvider).migrateLegacyStock(widget.product.id, batch);
     setState((){});
  }

  // --- TAB 2: EDIT DETAILS ---
  
  Widget _buildProductEditForm(Product product) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text("Base Details", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.5))),
               const SizedBox(height: 8),
               Container(
                 decoration: BoxDecoration(
                   color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.1))
                 ),
                 child: TextField(
                   controller: _nameController, 
                   style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                   decoration: InputDecoration(
                     labelText: "Product Name", 
                     labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black45),
                     border: InputBorder.none,
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                     prefixIcon: Icon(Icons.tag, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent)
                   ),
                 ),
               ),
             ],
           ),
           const SizedBox(height: 24),
           
           GlassCard(
             padding: const EdgeInsets.all(16),
             border: Border.all(color: Colors.white12),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  const Text("Barcode Management", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                       Expanded(
                         child: Container(
                           decoration: BoxDecoration(
                             color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: TextField(
                             controller: _barcodeController,
                             style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, letterSpacing: 1.2),
                             decoration: InputDecoration(
                               hintText: "No Barcode",
                               hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white30 : Colors.black26),
                               border: InputBorder.none,
                               contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                             ),
                           ),
                         ),
                       ),
                       const SizedBox(width: 8),
                       IconButton.filledTonal(
                         icon: const Icon(Icons.autorenew),
                         onPressed: _generateBarcode,
                         tooltip: "Generate New",
                       ),
                       const SizedBox(width: 8),
                       IconButton.filledTonal(
                         icon: const Icon(Icons.camera_alt),
                         onPressed: _scanBarcode,
                         tooltip: "Scan",
                       )
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_barcodeController.text.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _printBarcode(_barcodeController.text),
                      icon: const Icon(Icons.print),
                      label: const Text("Print Label"),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.cyanAccent, side: const BorderSide(color: Colors.cyanAccent)),
                    ),
                  )
               ],
             ),
           ),
           
           const SizedBox(height: 24),
           
           // INVENTORY SETTINGS (Hide for Services)
           if (product.stockType != 'service')
           GlassCard(
             padding: const EdgeInsets.all(16),
             border: Border.all(color: Colors.white12),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  const Text("Inventory Settings", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                       color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.1))
                    ),
                    child: TextField(
                      controller: _lowStockController,
                      keyboardType: TextInputType.text,
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                         labelText: "Low Stock Alert Level",
                         labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black45),
                         hintText: product.stockType == 'unit' ? "e.g. 5" : "e.g. 1kg",
                         hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white30 : Colors.black26),
                         helperText: "Notify when total stock drops below this amount",
                         helperStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38),
                         border: InputBorder.none,
                         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                         prefixIcon: Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent)
                      ),
                    ),
                  ),
               ],
             ),
           ),
           
           const SizedBox(height: 32),
           const SizedBox(height: 32),
           Container(
             height: 56,
             decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(16),
               gradient: LinearGradient(
                 colors: [
                   Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade900 : Colors.blueAccent,
                   Theme.of(context).brightness == Brightness.dark ? Colors.purple.shade900 : Colors.lightBlueAccent,
                 ]
               ),
               boxShadow: [
                 BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))
               ]
             ),
             child: ElevatedButton(
               onPressed: _saveProductDetails,
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.transparent, 
                 shadowColor: Colors.transparent,
                 foregroundColor: Colors.white,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
               ),
               child: const Text("UPDATE PRODUCT INFO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
             ),
           ),
            
            const SizedBox(height: 48),
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: product.isActive ? _deactivateProduct : _activateProduct,
                icon: Icon(product.isActive ? Icons.archive : Icons.unarchive, color: Colors.orange), 
                label: Text(product.isActive ? "DEACTIVATE PRODUCT" : "ACTIVATE PRODUCT", style: const TextStyle(color: Colors.orange)),
              ),
            ),
            const SizedBox(height: 12),
            
            // CONDITIONAL DELETE
            Consumer(builder: (context, ref, child) {
               final user = ref.watch(userProfileProvider).value;
               if (user != null && user.hasPermission(AppPermissions.canDeleteProducts)) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: _deleteProduct,
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text("DELETE PERMANENTLY", style: TextStyle(color: Colors.red)),
                    ),
                  );
               }
               return const SizedBox();
            }),
            const SizedBox(height: 24),
        ],
      ),
    );
  }

  bool _validateUnitCompatibility(String input, String baseUnit) {
    input = input.toLowerCase();
    
    // Weight (g) - Reject Volume/Length
    if (baseUnit == 'g') {
      if (input.contains(RegExp(r'(^|[\d\s])(l|ml|liters?|m|cm|meters?|ft|feet)\b', caseSensitive: false))) return false;
    }
    // Volume (ml) - Reject Weight/Length
    if (baseUnit == 'ml') {
      if (input.contains(RegExp(r'(^|[\d\s])(kg|g|kilograms?|grams?|m|cm|meters?|ft|feet)\b', caseSensitive: false))) return false;
    }
    // Length (cm) - Reject Weight/Volume
    if (baseUnit == 'cm') {
      if (input.contains(RegExp(r'(^|[\d\s])(kg|g|kilograms?|grams?|l|ml|liters?)\b', caseSensitive: false))) return false;
    }
    
    return true;
  }

  void _generateBarcode() {
    final user = ref.read(userProfileProvider).value;
    setState(() {
      _barcodeController.text = BarcodeUtils.generateStoreBarcode(user?.shopId);
    });
  }
  
  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const SimpleScannerScreen()));
    if (result != null) setState(() => _barcodeController.text = result);
  }
  
  Future<void> _printBarcode(String barcodeData) async {
     final pdf = pw.Document();
     pdf.addPage(
       pw.Page(
         pageFormat: PdfPageFormat.roll80, 
         build: (pw.Context context) {
           return pw.Center(
             child: pw.Column(
               mainAxisSize: pw.MainAxisSize.min,
               children: [
                 pw.Text(widget.product.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                 pw.SizedBox(height: 5),
                 pw.BarcodeWidget(
                   data: barcodeData,
                   barcode: pw.Barcode.code128(),
                   width: 150,
                   height: 50,
                 ),
                 pw.SizedBox(height: 5),
                 pw.Text(barcodeData, style: const pw.TextStyle(fontSize: 8)),
               ],
             )
           );
         }
       )
     );
     await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _saveProductDetails() async {
     double? lowStock;
     
     // Parse Low Stock
     if (_lowStockController.text.isNotEmpty) {
        if (widget.product.stockType == 'unit') {
           lowStock = double.tryParse(_lowStockController.text);
        } else {
           // Smart Parse
           lowStock = QuantityParser.parse(_lowStockController.text, widget.product.baseUnit ?? 'unit');
        }
     }

     final updated = widget.product.copyWith(
       name: _nameController.text,
       barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
       lowStockThreshold: lowStock,
     );
     await ref.read(productRepositoryProvider).updateProduct(updated);
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Details Updated")));
  }
  
  Future<void> _deleteProduct() async {
     // 1. Check for Sales History
     final hasSales = await ref.read(salesRepositoryProvider).hasSalesForProduct(widget.product.id);
     
     if (hasSales) {
        if (!mounted) return;
        showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
            title: const Text("Cannot Delete Product"),
            content: const Text("This product has sales records associated with it. To preserve sales history, you cannot delete it.\n\nPlease deactivate it instead."),
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
         content: Text("Are you sure you want to delete ${widget.product.name} permanently?"),
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

  Future<void> _deactivateProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Deactivate Product?"),
        content: const Text("This will hide the product from POS and sales, but keep it in your database."),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(ctx, false), child: const Text("CANCEL")),
          ElevatedButton(onPressed:()=>Navigator.pop(ctx, true), child: const Text("DEACTIVATE")),
        ],
      )
    );

    if (confirm == true) {
       await ref.read(productRepositoryProvider).deactivateProduct(widget.product.id);
       if (mounted) {
         Navigator.pop(context); // Exit Dashboard
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Deactivated")));
       }
    }
  }

  Future<void> _activateProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Activate Product?"),
        content: const Text("This will make the product visible in POS and available for sales again."),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(ctx, false), child: const Text("CANCEL")),
          ElevatedButton(onPressed:()=>Navigator.pop(ctx, true), child: const Text("ACTIVATE")),
        ],
      )
    );

    if (confirm == true) {
       await ref.read(productRepositoryProvider).activateProduct(widget.product.id);
       if (mounted) {
         Navigator.pop(context); // Exit Dashboard
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Activated")));
       }
    }
  }
}

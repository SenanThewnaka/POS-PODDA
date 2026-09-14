import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/inventory/add_product_screen.dart';
import 'package:sme_buddy/features/inventory/break_bulk_screen.dart';
import 'package:sme_buddy/features/inventory/break_bulk_sheet.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/inventory/product_details_sheet.dart';
import 'package:sme_buddy/features/inventory/product_dashboard_screen.dart';
import 'package:sme_buddy/utils/unit_formatter.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/features/procurement/grn_history_screen.dart';
import 'package:sme_buddy/features/procurement/suppliers_screen.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/shimmer_skeletons.dart';
import 'package:sme_buddy/features/inventory/simple_scanner_screen.dart'; // Add Scanner

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _categoryFilter = 'All'; 
  String _statusFilter = 'All'; 

  Future<void> _scanAndFindProduct() async {
    final barcode = await Navigator.push<String>(
      context, 
      MaterialPageRoute(builder: (_) => const SimpleScannerScreen())
    );

    if (barcode != null && barcode.isNotEmpty && mounted) {
      final product = await ref.read(productRepositoryProvider).getProductByBarcode(barcode);
      if (mounted) {
        if (product != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDashboardScreen(product: product)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("No product found for barcode: $barcode"), backgroundColor: Colors.orange)
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent to show Dashboard Gradient
      appBar: AppBar(
        title: const Text("Inventory", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode',
            onPressed: _scanAndFindProduct,
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'GRN Inward Stocking',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GRNHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.business_outlined),
            tooltip: 'Suppliers Directory',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SuppliersScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Break Bulk',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BreakBulkScreen()), // BreakBulk might need Glass updates too later
            ),
          ),
        ],
      ),
      body: Column(
        children: [
            // Quick ERP Access (Mobile & Desktop)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GRNHistoryScreen()),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.35),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 18, color: Colors.cyanAccent),
                            SizedBox(width: 8),
                            Text(
                              "GRN Inward",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.cyanAccent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SuppliersScreen()),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black12,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_outlined, size: 18, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                            const SizedBox(width: 8),
                            Text(
                              "Suppliers",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // FILTERS (Glass Card)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GlassCard(
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Category Dropdown
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _categoryFilter,
                          isDense: true,
                          dropdownColor: Theme.of(context).cardColor, // Adaptive dropdown bg
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent),
                          items: ['All', 'Unit', 'Measurable', 'Service'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
                          onChanged: (v) => setState(() => _categoryFilter = v!),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 24, color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12), // Separator
                    const SizedBox(width: 16),
                    // Status Dropdown
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          isDense: true,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                          icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent),
                          items: ['All', 'Available', 'Low Stock', 'Out of Stock', 'Inactive'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
                          onChanged: (v) => setState(() => _statusFilter = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Expanded(
              child: productsAsync.when(
                loading: () => GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 180),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12, mainAxisSpacing: 12,
                  ),
                  itemCount: 8,
                  itemBuilder: (_, i) => ShimmerProductGrid.singleCard(context),
                ),
                error: (err, st) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text("Failed to load inventory", style: TextStyle(color: Colors.red.shade300, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text("Check your connection.", style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
                data: (products) {
                  // ... (Filtering logic same as before) ...
                  final filtered = products.where((p) {
                     // 1. Category Filter
                     bool categoryMatch = true;
                     if (_categoryFilter == 'Unit') categoryMatch = p.stockType == 'unit' && p.productType != 'SERVICE';
                     else if (_categoryFilter == 'Measurable') categoryMatch = p.stockType == 'weight' && p.productType != 'SERVICE';
                     else if (_categoryFilter == 'Service') categoryMatch = p.productType == 'SERVICE';

                     // 2. Status Filter
                     // A. Inactive Check
                     if (_statusFilter == 'Inactive') {
                        return !p.isActive;
                     }
                     if (!p.isActive && _statusFilter != 'All') return false; 

                     bool statusMatch = true;
                     if (p.productType == 'SERVICE') {
                        if (_statusFilter == 'Low Stock' || _statusFilter == 'Out of Stock') statusMatch = false; 
                     } else {
                        double limit = p.lowStockThreshold ?? 5.0;
                        if (p.stockType == 'weight') limit = p.lowStockThreshold ?? 0.500; 

                        if (_statusFilter == 'Available') statusMatch = p.currentStock > limit;
                        else if (_statusFilter == 'Low Stock') statusMatch = p.currentStock <= limit && p.currentStock > 0;
                        else if (_statusFilter == 'Out of Stock') statusMatch = p.currentStock <= 0;
                     }

                     return categoryMatch && statusMatch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 80, color: Colors.white30),
                          const SizedBox(height: 16),
                          const Text("No Items Found", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text("Try adjusting your filters.", style: TextStyle(color: Colors.white.withValues(alpha: 0.38))),
                        ],
                      ),
                    );
                  }
                  
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 180), // Increased to clear lifted FAB
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200, // Responsive: ~2 cols on phone, 4+ on tablet
                      childAspectRatio: 0.75, 
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      
                      // Status Logic
                      bool isLow = false;
                      if (product.productType != 'SERVICE') {
                         double limit = product.lowStockThreshold ?? 5.0;
                         if (product.stockType == 'weight') limit = product.lowStockThreshold ?? 0.500;
                         isLow = product.currentStock <= limit;
                      }
                      bool isOut = product.productType != 'SERVICE' && product.currentStock <= 0;

                      // Pricing Logic
                      double price = product.sellingPrice;
                      String unit = "unit";
                      if (product.stockType == 'weight') {
                         if (product.baseUnit == 'g') { price *= 1000; unit = "Kg"; }
                         else if (product.baseUnit == 'ml') { price *= 1000; unit = "L"; }
                         else if (product.baseUnit == 'cm') { price *= 100; unit = "M"; }
                      }

                      return GlassCard(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ProductDashboardScreen(product: product)),
                          );
                        },
                        border: !product.isActive 
                           ? Border.all(color: Colors.red.withValues(alpha: 0.3)) 
                           : (isOut ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5)) : (isLow ? Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)) : null)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             // HEADER: Status / Icon
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    child: Icon(
                                      product.productType == 'SERVICE' ? Icons.cleaning_services : (product.stockType == 'weight' ? Icons.scale : Icons.inventory_2),
                                      size: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54
                                    ),
                                  ),
                                  if (!product.isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                      child: const Text("INACTIVE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                    )
                                  else if (isOut)
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18)
                                  else if (isLow)
                                    const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18)
                               ],
                             ),
                             const Spacer(),
                             
                             // BODY: Name & Price
                             Text(
                               product.name, 
                               maxLines: 2, 
                               overflow: TextOverflow.ellipsis,
                               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)
                             ),
                             const SizedBox(height: 4),
                             if (product.isVariablePrice && product.productType == 'SERVICE')
                               const Text("Variable", style: TextStyle(fontSize: 11, color: Colors.orangeAccent))
                             else
                               Text("Rs. ${price.toStringAsFixed(0)}", style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                             
                             const Spacer(),
                             
                             // FOOTER: STOCK Actions
                             if (!product.isActive)
                               SizedBox(
                                 width: double.infinity,
                                 height: 32,
                                 child: OutlinedButton(
                                   onPressed: () => ref.read(productRepositoryProvider).activateProduct(product.id),
                                   style: OutlinedButton.styleFrom(
                                     padding: EdgeInsets.zero,
                                     foregroundColor: Colors.greenAccent, 
                                     side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.5))
                                   ),
                                   child: const Text("RESTORE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                 ),
                               )
                             else 
                                Row(
                                  children: [
                                    // Stock Display
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isOut ? Colors.red.withValues(alpha: 0.1) : (isLow ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1)),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: isOut ? Colors.redAccent.withValues(alpha: 0.3) : (isLow ? Colors.orangeAccent.withValues(alpha: 0.3) : Colors.greenAccent.withValues(alpha: 0.3)))
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          product.productType == 'SERVICE' ? "SERVICE" : UnitFormatter.format(product.currentStock, product.baseUnit),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 16,
                                            color: isOut ? Colors.redAccent : (isLow ? Colors.orangeAccent : Colors.greenAccent)
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Split Button (Physical Only)
                                    if (product.productType != 'SERVICE') ...[
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (_) => BreakBulkSheet(sourceProduct: product)
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3))
                                          ),
                                          child: const Icon(Icons.call_split, size: 20, color: Colors.blueAccent),
                                        ),
                                      )
                                    ]
                                  ],
                                )
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: ref.watch(userProfileProvider).when(
        data: (user) {
          if (user != null && user.hasPermission(AppPermissions.canAddProducts)) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 80), // Raise above Bottom Nav
              child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const AddProductScreen()),
                );
              },
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              label: const Text("Add Item", style: TextStyle(fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.add),
            ));
          }
          return null; 
        },
        loading: () => null,
        error: (_,__) => null,
      ),
    );
  }


}

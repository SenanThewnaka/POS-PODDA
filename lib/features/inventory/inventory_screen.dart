import 'package:sme_buddy/utils/responsive_layout.dart';
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
import 'package:sme_buddy/features/inventory/services/barcode_lookup_service.dart';
import 'package:sme_buddy/features/inventory/sri_lanka_catalog_sheet.dart';
import 'package:sme_buddy/features/inventory/barcode_print_screen.dart';

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
      if (!mounted) return;

      if (product != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDashboardScreen(product: product)));
      } else {
        // Live auto-lookup in Sri Lanka catalog and Open Food Facts API
        final lookupResult = await ref.read(barcodeLookupServiceProvider).lookup(barcode);
        if (!mounted) return;

        if (lookupResult != null) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.cyanAccent),
                  SizedBox(width: 8),
                  Text("Found in Catalog"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lookupResult.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.qr_code, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(barcode, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey)),
                    ],
                  ),
                  if (lookupResult.brand != null) ...[
                    const SizedBox(height: 4),
                    Text("Brand: ${lookupResult.brand}", style: const TextStyle(fontSize: 13)),
                  ],
                  if (lookupResult.suggestedPrice != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Suggested MRP: Rs. ${lookupResult.suggestedPrice!.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 13, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text("This product is not in your store yet. Would you like to add it to your inventory?"),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("CANCEL"),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddProductScreen(
                          initialBarcode: lookupResult.barcode,
                          initialName: lookupResult.name,
                          initialPrice: lookupResult.suggestedPrice,
                          initialCost: lookupResult.suggestedCost,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("ADD TO STORE"),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No product found for barcode: $barcode"),
              action: SnackBarAction(
                label: "ADD NEW",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddProductScreen(initialBarcode: barcode),
                    ),
                  );
                },
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  void _showInventoryToolsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Inventory Tools & Operations",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Procurement, labeling, repacking & suppliers",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white60 : Colors.black54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tool Items
                _buildToolItem(
                  context: ctx,
                  isDark: isDark,
                  icon: Icons.receipt_long,
                  iconColor: const Color(0xFF06B6D4),
                  title: "GRN Inward Stocking",
                  subtitle: "Receive stock shipments from suppliers and update cost prices",
                  badgeText: "ERP",
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GRNHistoryScreen()));
                  },
                ),
                const SizedBox(height: 10),
                _buildToolItem(
                  context: ctx,
                  isDark: isDark,
                  icon: Icons.business_outlined,
                  iconColor: const Color(0xFF6366F1),
                  title: "Suppliers Directory",
                  subtitle: "View vendor contacts, outstanding payables, and order history",
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen()));
                  },
                ),
                const SizedBox(height: 10),
                _buildToolItem(
                  context: ctx,
                  isDark: isDark,
                  icon: Icons.label_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: "Barcode Stickers",
                  subtitle: "Generate and print thermal barcode labels for items and shelves",
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodePrintScreen()));
                  },
                ),
                const SizedBox(height: 10),
                _buildToolItem(
                  context: ctx,
                  isDark: isDark,
                  icon: Icons.compare_arrows,
                  iconColor: const Color(0xFFA855F7),
                  title: "Break Bulk",
                  subtitle: "Convert bulk sacks or cartons into individual retail units",
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BreakBulkScreen()));
                  },
                ),
                const SizedBox(height: 10),
                _buildToolItem(
                  context: ctx,
                  isDark: isDark,
                  icon: Icons.storefront_outlined,
                  iconColor: const Color(0xFF10B981),
                  title: "Sri Lanka Starter Catalog",
                  subtitle: "Browse and import pre-configured local retail items & barcodes",
                  badgeText: "Quick Setup",
                  onTap: () {
                    Navigator.pop(ctx);
                    SriLankaCatalogSheet.show(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolItem({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);

    return GlassScaffold(
      appBar: AppBar(
        title: const Text("Inventory", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode',
            onPressed: _scanAndFindProduct,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: InkWell(
                onTap: () => _showInventoryToolsSheet(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: primaryAccent.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: primaryAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Tools",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: primaryAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
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
                      Text("Check your connection.", style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
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
                    if (products.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 72, color: Colors.cyanAccent.withValues(alpha: 0.6)),
                              const SizedBox(height: 16),
                              Text(
                                "Your Inventory is Empty",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Start quickly by preloading the Sri Lanka Starter Pack (Munchee, Maliban, Anchor, Sunlight, etc.) with real barcodes in 1 tap!",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => SriLankaCatalogSheet.show(context),
                                icon: const Icon(Icons.storefront),
                                label: const Text("PRELOAD SRI LANKA STARTER PACK"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 80, color: isDark ? Colors.white30 : Colors.black26),
                          const SizedBox(height: 16),
                          Text("No Items Found", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                          const SizedBox(height: 8),
                          Text("Try adjusting your filters.", style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                        ],
                      ),
                    );
                  }
                  
                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, context.isTabletOrDesktop ? 24 : 180),
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
                         else if (product.baseUnit == 'kg') { unit = "Kg"; }
                         else if (product.baseUnit == 'ml') { price *= 1000; unit = "L"; }
                         else if (product.baseUnit == 'l') { unit = "L"; }
                         else if (product.baseUnit == 'cm') { price *= 100; unit = "M"; }
                         else if (product.baseUnit == 'm') { unit = "M"; }
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
                                  else
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!product.isTaxable)
                                          Container(
                                            margin: const EdgeInsets.only(right: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.teal.withValues(alpha: 0.4), width: 0.8),
                                            ),
                                            child: const Text("EXEMPT", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                                          ),
                                        if (isOut)
                                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18)
                                        else if (isLow)
                                          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18)
                                      ],
                                    )
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
                                          product.isService ? "SERVICE" : UnitFormatter.format(product.currentStock < 0 ? 0.0 : product.currentStock, product.baseUnit),
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

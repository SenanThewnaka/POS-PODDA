import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/sri_lanka_products_catalog.dart';
import 'product_model.dart';
import 'product_repository.dart';
import 'package:sme_buddy/features/subscription/subscription_guard.dart';
import 'package:sme_buddy/utils/glass_card.dart';

class SriLankaCatalogSheet extends ConsumerStatefulWidget {
  const SriLankaCatalogSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SriLankaCatalogSheet(),
    );
  }

  @override
  ConsumerState<SriLankaCatalogSheet> createState() => _SriLankaCatalogSheetState();
}

class _SriLankaCatalogSheetState extends ConsumerState<SriLankaCatalogSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedPresetId = 'all';
  String _selectedCategory = 'All';
  final Set<String> _selectedBarcodes = {};
  bool _isImporting = false;
  double _initialStock = 10.0; // Default 10 units of initial inventory

  @override
  void initState() {
    super.initState();
    // Default: select all items in catalog
    _selectedBarcodes.addAll(SriLankaProductsCatalog.items.map((i) => i.barcode));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectPreset(StorePreset preset) {
    setState(() {
      _selectedPresetId = preset.id;
      _selectedCategory = 'All';
      final matchingItems = SriLankaProductsCatalog.getByCategories(preset.categories);
      _selectedBarcodes.clear();
      _selectedBarcodes.addAll(matchingItems.map((i) => i.barcode));
    });
  }

  List<String> get _availableCategories {
    final activePreset = SriLankaProductsCatalog.storePresets.firstWhere(
      (p) => p.id == _selectedPresetId,
      orElse: () => SriLankaProductsCatalog.storePresets.first,
    );
    if (activePreset.categories.contains('All')) {
      return SriLankaProductsCatalog.categories;
    }
    return ['All', ...activePreset.categories];
  }

  List<PreloadCatalogItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    final activePreset = SriLankaProductsCatalog.storePresets.firstWhere(
      (p) => p.id == _selectedPresetId,
      orElse: () => SriLankaProductsCatalog.storePresets.first,
    );

    return SriLankaProductsCatalog.items.where((item) {
      final matchesPreset = activePreset.categories.contains('All') || activePreset.categories.contains(item.category);
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.barcode.contains(query) ||
          item.brand.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
      return matchesPreset && matchesCategory && matchesQuery;
    }).toList();
  }

  Future<void> _importSelected() async {
    if (_selectedBarcodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one product to import."), backgroundColor: Colors.orange),
      );
      return;
    }

    // Subscription check
    final allowed = await SubscriptionGuard.check(context, ref, SubscriptionAction.addItem);
    if (!allowed) return;

    setState(() => _isImporting = true);

    try {
      final selectedItems = SriLankaProductsCatalog.items
          .where((i) => _selectedBarcodes.contains(i.barcode))
          .map((i) => i.toProduct(initialStock: _initialStock))
          .toList();

      final count = await ref.read(productRepositoryProvider).batchAddProducts(selectedItems);

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  count > 0
                      ? "Preloaded $count Sri Lankan products into your inventory!"
                      : "All selected products already exist in your store.",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredItems;
    final totalSelected = _selectedBarcodes.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
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
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storefront, color: Colors.cyanAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Sri Lanka Starter Pack",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            "Preload Sri Lankan retail goods (FMCG, Stationery, Hardware)",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Store Type Presets Row
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: SriLankaProductsCatalog.storePresets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final preset = SriLankaProductsCatalog.storePresets[idx];
                    final isSelected = _selectedPresetId == preset.id;
                    return InkWell(
                      onTap: () => _selectPreset(preset),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.cyanAccent.withValues(alpha: 0.2)
                              : (isDark ? const Color(0xFF1E293B) : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.cyanAccent : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              preset.icon,
                              size: 16,
                              color: isSelected ? Colors.cyanAccent : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              preset.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.cyanAccent : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Search Atlas, Orange, S-Lon, Munchee, barcodes...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Category Filter Chips
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _availableCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final cat = _availableCategories[idx];
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                      selectedColor: Colors.cyanAccent,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Selection & Stock Controls Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  borderRadius: 12,
                  child: Row(
                    children: [
                      Checkbox(
                        value: filtered.isNotEmpty && filtered.every((i) => _selectedBarcodes.contains(i.barcode)),
                        tristate: filtered.any((i) => _selectedBarcodes.contains(i.barcode)) &&
                            !filtered.every((i) => _selectedBarcodes.contains(i.barcode)),
                        activeColor: Colors.cyanAccent,
                        checkColor: Colors.black,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedBarcodes.addAll(filtered.map((i) => i.barcode));
                            } else {
                              for (final f in filtered) {
                                _selectedBarcodes.remove(f.barcode);
                              }
                            }
                          });
                        },
                      ),
                      Text(
                        "$totalSelected of ${SriLankaProductsCatalog.items.length} selected",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      // Stock Selector
                      PopupMenuButton<double>(
                        initialValue: _initialStock,
                        tooltip: "Initial Stock",
                        onSelected: (val) => setState(() => _initialStock = val),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 0.0, child: Text("0 units (Add stock later via GRN)")),
                          PopupMenuItem(value: 5.0, child: Text("5 units each")),
                          PopupMenuItem(value: 10.0, child: Text("10 units each (Recommended)")),
                          PopupMenuItem(value: 20.0, child: Text("20 units each")),
                          PopupMenuItem(value: 50.0, child: Text("50 units each")),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.cyanAccent),
                              const SizedBox(width: 4),
                              Text(
                                "Stock: ${_initialStock.toInt()} units",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 16, color: Colors.cyanAccent),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Product List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final isChecked = _selectedBarcodes.contains(item.barcode);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isChecked ? Colors.cyanAccent.withValues(alpha: 0.5) : Colors.transparent,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isChecked,
                        activeColor: Colors.cyanAccent,
                        checkColor: Colors.black,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedBarcodes.add(item.barcode);
                            } else {
                              _selectedBarcodes.remove(item.barcode);
                            }
                          });
                        },
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.brand,
                                      style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.category,
                                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
                                    ),
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      const Icon(Icons.qr_code, size: 12, color: Colors.grey),
                                      const SizedBox(width: 3),
                                      Text(
                                        item.barcode,
                                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    "Cost: Rs. ${item.costPrice.toStringAsFixed(0)}",
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "MRP: Rs. ${item.sellingPrice.toStringAsFixed(0)}",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Action Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isImporting || totalSelected == 0 ? null : _importSelected,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    child: _isImporting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
                              SizedBox(width: 12),
                              Text("Preloading Products...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          )
                        : Text(
                            "PRELOAD $totalSelected PRODUCTS INTO STORE",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

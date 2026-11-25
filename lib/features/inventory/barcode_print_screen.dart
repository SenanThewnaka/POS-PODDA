import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/inventory/services/barcode_sticker_service.dart';
import 'package:sme_buddy/features/settings/printer_settings_service.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/utils/barcode_utils.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/responsive_layout.dart';

class BarcodePrintScreen extends ConsumerStatefulWidget {
  final List<Product>? initialProducts;
  final Map<String, int>? initialQuantities;
  final List<BarcodeLabelItem>? initialItems;
  final int defaultQuantity;
  final String? initialBarcode;

  const BarcodePrintScreen({
    super.key,
    this.initialProducts,
    this.initialQuantities,
    this.initialItems,
    this.defaultQuantity = 1,
    this.initialBarcode,
  });

  @override
  ConsumerState<BarcodePrintScreen> createState() => _BarcodePrintScreenState();
}

class _BarcodePrintScreenState extends ConsumerState<BarcodePrintScreen> {
  final List<BarcodeLabelItem> _items = [];
  late BarcodeLabelConfig _config;
  late TextEditingController _storeNameCtrl;
  int _previewIndex = 0;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _storeNameCtrl = TextEditingController();

    _config = const BarcodeLabelConfig(
      format: BarcodeLabelFormat.thermal50x30,
      showStoreName: true,
      showProductName: true,
      showPrice: true,
      showBarcodeText: true,
      showDate: false,
    );

    // Populate initial items or products
    if (widget.initialItems != null && widget.initialItems!.isNotEmpty) {
      _items.addAll(widget.initialItems!);
    } else if (widget.initialProducts != null && widget.initialProducts!.isNotEmpty) {
      for (final prod in widget.initialProducts!) {
        String bc = prod.barcode ?? widget.initialBarcode ?? '';
        final qty = widget.initialQuantities?[prod.id] ?? widget.defaultQuantity;
        _items.add(BarcodeLabelItem.fromProduct(prod, quantity: qty).copyWith(
          barcode: bc,
        ));
      }
    }

    // Set store name from shop owner once loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(shopOwnerProfileProvider).value ?? ref.read(userProfileProvider).value;
      if (user?.shopName != null && user!.shopName!.isNotEmpty) {
        setState(() {
          _storeNameCtrl.text = user.shopName!;
          _config = _config.copyWith(storeName: user.shopName);
        });
      }
    });
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    super.dispose();
  }

  int get _totalLabelsCount {
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }

  void _generateBarcodeForItem(int index) {
    final user = ref.read(shopOwnerProfileProvider).value ?? ref.read(userProfileProvider).value;
    final newBc = BarcodeUtils.generateStoreBarcode(user?.shopId);
    setState(() {
      _items[index] = _items[index].copyWith(barcode: newBc);
    });

    // If item has a backing product, update in repo
    final product = _items[index].product;
    if (product != null) {
      ref.read(productRepositoryProvider).updateProduct(product.copyWith(barcode: newBc));
    }
  }

  void _showAddProductPicker() {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final productsAsync = ref.watch(productsStreamProvider);

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Add Products to Print Queue",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: "Search products by name or barcode...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: productsAsync.when(
                      data: (products) {
                        final query = searchCtrl.text.toLowerCase().trim();
                        final filtered = products.where((p) {
                          if (query.isEmpty) return true;
                          return p.name.toLowerCase().contains(query) ||
                              (p.barcode != null && p.barcode!.contains(query));
                        }).toList();

                        if (filtered.isEmpty) {
                          return const Center(child: Text("No matching products found."));
                        }

                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final prod = filtered[i];
                            final alreadyAdded = _items.any((item) => item.productId == prod.id);

                            return ListTile(
                              title: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                "${prod.barcode != null ? 'Barcode: ${prod.barcode}' : 'No Barcode'} • Rs. ${prod.sellingPrice.toStringAsFixed(2)} • Stock: ${prod.currentStock.toInt()}",
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: alreadyAdded ? Colors.grey : Colors.cyanAccent,
                                  foregroundColor: Colors.black,
                                ),
                                icon: Icon(alreadyAdded ? Icons.check : Icons.add, size: 16),
                                label: Text(alreadyAdded ? "Added" : "Add"),
                                onPressed: alreadyAdded
                                    ? null
                                    : () {
                                        setState(() {
                                          _items.add(BarcodeLabelItem.fromProduct(prod, quantity: 1));
                                        });
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Added ${prod.name} to print queue"),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text("Error: $err")),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleDirectPrint() async {
    if (_items.isEmpty || _totalLabelsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add items to print")),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final doc = await BarcodeStickerService.generatePdf(
        items: _items,
        config: _config,
      );

      final success = await ref.read(printerSettingsProvider.notifier).printDocument(
            doc: doc,
            name: 'barcode_stickers_${DateTime.now().millisecondsSinceEpoch}',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Labels sent to printer!" : "Print cancelled or unavailable"),
            backgroundColor: success ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Print error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _handleSystemPrint() async {
    if (_items.isEmpty || _totalLabelsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add items to print")),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final doc = await BarcodeStickerService.generatePdf(
        items: _items,
        config: _config,
      );

      final bytes = await doc.save();
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'barcode_stickers_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening print dialog: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _handleSharePdf() async {
    if (_items.isEmpty || _totalLabelsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add items to print")),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final doc = await BarcodeStickerService.generatePdf(
        items: _items,
        config: _config,
      );

      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'barcode_stickers_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sharing PDF: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = context.isTabletOrDesktop;

    return GlassScaffold(
      appBar: AppBar(
        title: const Text("Barcode Sticker Studio", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: "Add Products",
            onPressed: _showAddProductPicker,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Expanded(
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Pane: Product Queue & Quantities
                          Expanded(
                            flex: 5,
                            child: _buildQueueAndSettingsPane(isDark),
                          ),
                          const VerticalDivider(width: 1),
                          // Right Pane: Live Sticker Preview & Layout Selector
                          Expanded(
                            flex: 4,
                            child: _buildPreviewPane(isDark),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        children: [
                          _buildPreviewCard(isDark),
                          const SizedBox(height: 16),
                          _buildFormatSelector(isDark),
                          const SizedBox(height: 16),
                          _buildContentToggles(isDark),
                          const SizedBox(height: 16),
                          _buildQueueList(isDark),
                        ],
                      ),
              ),

              // Sticky Bottom Action Bar
              _buildBottomActionBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueAndSettingsPane(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildFormatSelector(isDark),
        const SizedBox(height: 16),
        _buildContentToggles(isDark),
        const SizedBox(height: 20),
        _buildQueueList(isDark),
      ],
    );
  }

  Widget _buildPreviewPane(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPreviewCard(isDark),
          const SizedBox(height: 16),
          _buildPaperSpecInfo(isDark),
        ],
      ),
    );
  }

  Widget _buildFormatSelector(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.aspect_ratio, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              const Text("Sticker & Paper Format", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BarcodeLabelFormat.values.map((fmt) {
              final isSelected = _config.format == fmt;
              return ChoiceChip(
                label: Text(fmt.displayName),
                selected: isSelected,
                selectedColor: Colors.cyanAccent,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (_) {
                  setState(() {
                    _config = _config.copyWith(format: fmt);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _config.format.description,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildContentToggles(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              const Text("Label Content & Info", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _storeNameCtrl,
            decoration: InputDecoration(
              labelText: "Store Name Header",
              hintText: "e.g. CITY SUPER MART",
              prefixIcon: const Icon(Icons.storefront, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            onChanged: (val) {
              setState(() {
                _config = _config.copyWith(storeName: val.trim());
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text("Store Name"),
                selected: _config.showStoreName,
                onSelected: (val) => setState(() => _config = _config.copyWith(showStoreName: val)),
              ),
              FilterChip(
                label: const Text("Product Name"),
                selected: _config.showProductName,
                onSelected: (val) => setState(() => _config = _config.copyWith(showProductName: val)),
              ),
              FilterChip(
                label: const Text("Selling Price"),
                selected: _config.showPrice,
                onSelected: (val) => setState(() => _config = _config.copyWith(showPrice: val)),
              ),
              FilterChip(
                label: const Text("Barcode Numbers"),
                selected: _config.showBarcodeText,
                onSelected: (val) => setState(() => _config = _config.copyWith(showBarcodeText: val)),
              ),
              FilterChip(
                label: const Text("Packed Date"),
                selected: _config.showDate,
                onSelected: (val) => setState(() => _config = _config.copyWith(showDate: val)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(bool isDark) {
    final hasItems = _items.isNotEmpty;
    if (_previewIndex >= _items.length) {
      _previewIndex = 0;
    }
    final activeItem = hasItems ? _items[_previewIndex] : null;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.remove_red_eye_outlined, color: Colors.cyanAccent, size: 20),
                  const SizedBox(width: 8),
                  const Text("Live Sticker Preview", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              if (hasItems && _items.length > 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _previewIndex > 0 ? () => setState(() => _previewIndex--) : null,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${_previewIndex + 1}/${_items.length}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _previewIndex < _items.length - 1 ? () => setState(() => _previewIndex++) : null,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Render simulated physical sticker
          Center(
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: activeItem == null
                  ? const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text("Add products below to preview", style: TextStyle(color: Colors.black45)),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Store Name
                        if (_config.showStoreName && _config.storeName != null && _config.storeName!.isNotEmpty)
                          Text(
                            _config.storeName!.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        if (_config.showStoreName && _config.storeName != null && _config.storeName!.isNotEmpty)
                          const SizedBox(height: 2),

                        // Product Name
                        if (_config.showProductName)
                          Text(
                            activeItem.productName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 6),

                        // Barcode Representation
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            children: [
                              CustomPaint(
                                size: const Size(180, 36),
                                painter: _BarcodeSimulationPainter(data: activeItem.barcode),
                              ),
                              if (_config.showBarcodeText) ...[
                                const SizedBox(height: 2),
                                Text(
                                  activeItem.barcode.isNotEmpty ? activeItem.barcode : "NO BARCODE",
                                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Bottom Row (Price & Date)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_config.showPrice)
                              Text(
                                "${_config.currencySymbol}${activeItem.price.toStringAsFixed(2)}${activeItem.unitText != null ? ' ${activeItem.unitText}' : ''}",
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                            if (_config.showDate) ...[
                              if (_config.showPrice) const SizedBox(width: 6),
                              Text(
                                "• ${DateFormat('yyyy-MM-dd').format(DateTime.now())}",
                                style: const TextStyle(fontSize: 9, color: Colors.black54),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperSpecInfo(bool isDark) {
    String paperDetail;
    switch (_config.format) {
      case BarcodeLabelFormat.thermal50x30:
        paperDetail = "Direct thermal label printer roll • 50 mm wide × 30 mm tall • Standard adhesive peel stickers";
        break;
      case BarcodeLabelFormat.thermal40x30:
        paperDetail = "Direct thermal label printer roll • 40 mm wide × 30 mm tall • Compact retail stickers";
        break;
      case BarcodeLabelFormat.roll58:
        paperDetail = "Continuous 58 mm thermal receipt printer roll • Cut / tear lines printed between stickers";
        break;
      case BarcodeLabelFormat.roll80:
        paperDetail = "Continuous 80 mm thermal receipt printer roll • Cut / tear lines printed between stickers";
        break;
      case BarcodeLabelFormat.a4Grid30:
        final sheetsNeeded = (_totalLabelsCount / 30).ceil();
        paperDetail = "A4 Sheet (3×10 Grid) • 30 labels per sheet • Requires $sheetsNeeded sheet(s) of 30-label paper";
        break;
      case BarcodeLabelFormat.a4Grid24:
        final sheetsNeeded = (_totalLabelsCount / 24).ceil();
        paperDetail = "A4 Sheet (3×8 Grid) • 24 labels per sheet • Requires $sheetsNeeded sheet(s) of 24-label paper";
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.cyanAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              paperDetail,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.checklist, color: Colors.cyanAccent, size: 20),
                  const SizedBox(width: 8),
                  Text("Print Queue (${_items.length} Products)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Add More"),
                onPressed: _showAddProductPicker,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_2, size: 48, color: Colors.white24),
                    const SizedBox(height: 8),
                    const Text("No products in print queue", style: TextStyle(color: Colors.white54)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                      icon: const Icon(Icons.add),
                      label: const Text("Add Products"),
                      onPressed: _showAddProductPicker,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final item = _items[index];
                final missingBarcode = item.barcode.isEmpty;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: missingBarcode ? Colors.orange.withValues(alpha: 0.5) : (isDark ? Colors.white10 : Colors.black12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.productName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: Colors.white54,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _items.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            "Rs. ${item.price.toStringAsFixed(2)}${item.unitText != null ? ' ${item.unitText}' : ''}",
                            style: const TextStyle(fontSize: 13, color: Colors.greenAccent, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 10),
                          if (missingBarcode) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text("No Barcode", style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _generateBarcodeForItem(index),
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text("Generate", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ] else ...[
                            Text(
                              "• ${item.barcode}",
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white60),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Quantity Stepper and Quick Chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 22),
                                onPressed: item.quantity > 1
                                    ? () => setState(() => _items[index] = item.copyWith(quantity: item.quantity - 1))
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black12,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "${item.quantity}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 22),
                                onPressed: () => setState(() => _items[index] = item.copyWith(quantity: item.quantity + 1)),
                              ),
                            ],
                          ),
                          // Quick quantity chips
                          Wrap(
                            spacing: 4,
                            children: [
                              _quickQtyChip(index, 1),
                              _quickQtyChip(index, 5),
                              _quickQtyChip(index, 10),
                              if (item.product != null && item.product!.currentStock > 0)
                                ActionChip(
                                  label: Text("Stock (${item.product!.currentStock.toInt()})"),
                                  padding: EdgeInsets.zero,
                                  labelStyle: const TextStyle(fontSize: 11),
                                  onPressed: () => setState(() => _items[index] = item.copyWith(quantity: item.product!.currentStock.toInt())),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _quickQtyChip(int index, int qty) {
    return ActionChip(
      label: Text("$qty"),
      padding: EdgeInsets.zero,
      labelStyle: const TextStyle(fontSize: 11),
      onPressed: () => setState(() => _items[index] = _items[index].copyWith(quantity: qty)),
    );
  }

  Widget _buildBottomActionBar(bool isDark) {
    final totalCount = _totalLabelsCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Total Stickers: $totalCount",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "${_items.length} Products • ${_config.format.displayName}",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                ),
              ],
            ),
          ),
          if (_isGenerating)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            IconButton(
              icon: const Icon(Icons.share, size: 20),
              tooltip: 'Share / Save PDF',
              onPressed: totalCount > 0 ? _handleSharePdf : null,
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print Dialog'),
              onPressed: totalCount > 0 ? _handleSystemPrint : null,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.print, size: 20),
              label: const Text('Print Now', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: totalCount > 0 ? _handleDirectPrint : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// Simple painter to render a realistic preview of Code128 barcode bars
class _BarcodeSimulationPainter extends CustomPainter {
  final String data;
  _BarcodeSimulationPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.square;

    final barWidth = size.width / 50;
    // Generate pseudo-random bar widths seeded by data string
    int hash = data.hashCode;
    double currentX = 4.0;

    while (currentX < size.width - 8) {
      hash = (hash * 31 + 17) & 0x7FFFFFFF;
      final isSpace = (hash % 3 == 0);
      final thickness = (hash % 3 + 1).toDouble();

      if (!isSpace) {
        paint.strokeWidth = thickness * (barWidth / 2);
        canvas.drawLine(
          Offset(currentX, 0),
          Offset(currentX, size.height),
          paint,
        );
      }
      currentX += thickness * barWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodeSimulationPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

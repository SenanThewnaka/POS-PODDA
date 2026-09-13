import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/procurement/procurement_repository.dart';
import 'package:sme_buddy/features/procurement/supplier_model.dart';
import 'package:sme_buddy/features/procurement/grn_model.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/responsive_layout.dart';

class CreateGRNScreen extends ConsumerStatefulWidget {
  const CreateGRNScreen({super.key});

  @override
  ConsumerState<CreateGRNScreen> createState() => _CreateGRNScreenState();
}

class _CreateGRNScreenState extends ConsumerState<CreateGRNScreen> {
  final TextEditingController _invoiceCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _amountPaidCtrl = TextEditingController(text: '0');

  SupplierModel? _selectedSupplier;
  DateTime _receivedDate = DateTime.now();
  String _paymentStatus = 'PAID'; // 'PAID', 'CREDIT', 'PARTIAL'
  bool _isSubmitting = false;

  // Working list of items in this GRN
  final List<GRNItem> _items = [];

  @override
  void dispose() {
    _invoiceCtrl.dispose();
    _notesCtrl.dispose();
    _amountPaidCtrl.dispose();
    super.dispose();
  }

  double get _totalCost => _items.fold(0.0, (sum, item) => sum + item.subTotal);
  double get _totalRetailValue =>
      _items.fold(0.0, (sum, item) => sum + (item.quantity * item.sellingPrice));
  double get _expectedProfit => _totalRetailValue - _totalCost;
  double get _overallMargin =>
      _totalRetailValue > 0 ? (_expectedProfit / _totalRetailValue) * 100 : 0.0;

  void _addItemDialog([List<Product>? passedProducts]) {
    final products = passedProducts ?? ref.read(productsStreamProvider).valueOrNull ?? [];

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No products found in inventory. Please add products first.")),
      );
      return;
    }

    Product? selectedProduct;
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController();
    final sellingCtrl = TextEditingController();
    String searchProductQuery = '';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filteredProducts = products.where((p) {
            if (!p.isActive) return false;
            if (searchProductQuery.isEmpty) return true;
            return p.name.toLowerCase().contains(searchProductQuery) ||
                (p.barcode != null && p.barcode!.toLowerCase().contains(searchProductQuery));
          }).toList();

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            title: const Text("Add Inward Product",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product selector / search
                      if (selectedProduct == null) ...[
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Search Catalog Item",
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (val) {
                            setModalState(() => searchProductQuery = val.trim().toLowerCase());
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredProducts.length,
                            itemBuilder: (ctx, idx) {
                              final p = filteredProducts[idx];
                              return ListTile(
                                dense: true,
                                title: Text(p.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                                subtitle: Text(
                                  "Stock: ${p.currentStock} | Cost: Rs. ${p.costPrice.toStringAsFixed(2)} | Sell: Rs. ${p.sellingPrice.toStringAsFixed(2)}",
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                ),
                                onTap: () {
                                  setModalState(() {
                                    selectedProduct = p;
                                    costCtrl.text = p.costPrice > 0 ? p.costPrice.toStringAsFixed(2) : '';
                                    sellingCtrl.text = p.sellingPrice > 0 ? p.sellingPrice.toStringAsFixed(2) : '';
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        // Selected Product Banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2, color: Color(0xFF818CF8)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedProduct!.name,
                                      style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Text(
                                      "Current Stock: ${selectedProduct!.currentStock} (${selectedProduct!.stockType})",
                                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.change_circle_outlined, color: Colors.white70),
                                tooltip: "Change Product",
                                onPressed: () {
                                  setModalState(() => selectedProduct = null);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: qtyCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: "Received Qty *",
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (v) {
                                  final numVal = double.tryParse(v ?? '');
                                  if (numVal == null || numVal <= 0) return "Valid qty required";
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: costCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: "Unit Cost (Rs.) *",
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (v) {
                                  final numVal = double.tryParse(v ?? '');
                                  if (numVal == null || numVal < 0) return "Cost required";
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: sellingCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Batch Selling Price (Rs.) *",
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (v) {
                            final numVal = double.tryParse(v ?? '');
                            if (numVal == null || numVal <= 0) return "Selling price required";
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
              ),
              if (selectedProduct != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final qty = double.parse(qtyCtrl.text.trim());
                    final unitCost = double.parse(costCtrl.text.trim());
                    final selling = double.parse(sellingCtrl.text.trim());

                    setState(() {
                      _items.add(GRNItem(
                        productId: selectedProduct!.id,
                        productName: selectedProduct!.name,
                        quantity: qty,
                        unitCostPrice: unitCost,
                        sellingPrice: selling,
                        subTotal: qty * unitCost,
                      ));
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text("Add to GRN", style: TextStyle(color: Colors.white)),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitGRN() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one item to receive stock.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final grn = GRNModel(
        id: '',
        shopId: '',
        grnNumber: '',
        supplierId: _selectedSupplier?.id,
        supplierName: _selectedSupplier?.name,
        invoiceNumber: _invoiceCtrl.text.trim().isEmpty ? null : _invoiceCtrl.text.trim(),
        receivedAt: _receivedDate,
        items: _items,
        totalCost: _totalCost,
        paymentStatus: _paymentStatus,
        amountPaid: double.tryParse(_amountPaidCtrl.text.trim()) ?? 0.0,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await ref.read(procurementRepositoryProvider).receiveGRN(grn);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Goods Received Note processed! Batches created & stock updated."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting GRN: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return GlassScaffold(
      appBar: AppBar(
        title: const Text("New Goods Received Note (GRN)", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: _items.isEmpty || _isSubmitting ? null : _submitGRN,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
            label: Text(
              _isSubmitting ? "PROCESSING..." : "CONFIRM & INWARD",
              style: TextStyle(
                color: _items.isEmpty ? Colors.white38 : Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Supplier & Receiving Details
                SizedBox(
                  width: 380,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildDetailsCard(suppliersAsync),
                  ),
                ),
                // Right Column: Items Table & Financial Totals
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: Column(
                      children: [
                        _buildItemsHeader(productsAsync.valueOrNull),
                        const SizedBox(height: 12),
                        Expanded(child: _buildItemsList(productsAsync.valueOrNull)),
                        const SizedBox(height: 12),
                        _buildTotalsSummary(),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailsCard(suppliersAsync),
                  const SizedBox(height: 16),
                  _buildItemsHeader(productsAsync.valueOrNull),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 320,
                    child: _buildItemsList(productsAsync.valueOrNull),
                  ),
                  const SizedBox(height: 16),
                  _buildTotalsSummary(),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _items.isEmpty || _isSubmitting ? null : _submitGRN,
                    icon: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.inventory, color: Colors.white),
                    label: Text(
                      _isSubmitting ? "PROCESSING..." : "CONFIRM & INWARD STOCK",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailsCard(AsyncValue<List<SupplierModel>> suppliersAsync) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("GRN Information",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          // Supplier dropdown
          suppliersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text("Error loading suppliers", style: TextStyle(color: Colors.redAccent)),
            data: (suppliers) {
              return DropdownButtonFormField<SupplierModel>(
                isExpanded: true,
                value: _selectedSupplier,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Supplier (Optional)",
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  prefixIcon: const Icon(Icons.business, color: Color(0xFF6366F1)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  const DropdownMenuItem<SupplierModel>(
                    value: null,
                    child: Text(
                      "Direct / No Supplier",
                      style: TextStyle(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...suppliers.map(
                    (s) => DropdownMenuItem<SupplierModel>(
                      value: s,
                      child: Text(
                        s.name,
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedSupplier = val),
              );
            },
          ),
          const SizedBox(height: 12),
          // Supplier Invoice Reference
          TextField(
            controller: _invoiceCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Supplier Invoice / Bill #",
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              prefixIcon: const Icon(Icons.receipt_long, color: Color(0xFF6366F1)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          // Received Date
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _receivedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 7)),
              );
              if (picked != null) setState(() => _receivedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Date: ${DateFormat('yyyy-MM-dd').format(_receivedDate)}",
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white54),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Payment Status
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _paymentStatus,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Payment Status",
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              prefixIcon: const Icon(Icons.payment, color: Color(0xFF6366F1)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: const [
              DropdownMenuItem(value: 'PAID', child: Text("Paid in Full", overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'CREDIT', child: Text("Credit / On Account", overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'PARTIAL', child: Text("Partial Payment", overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (val) => setState(() => _paymentStatus = val ?? 'PAID'),
          ),
          if (_paymentStatus != 'CREDIT') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _amountPaidCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Amount Paid (Rs.)",
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.attach_money, color: Colors.greenAccent),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Notes / Receiving Remarks",
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              prefixIcon: const Icon(Icons.note_outlined, color: Color(0xFF6366F1)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsHeader([List<Product>? products]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Flexible(
                child: Text(
                  "Inward Line Items",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${_items.length} items",
                  style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () => _addItemDialog(products),
          icon: const Icon(Icons.add, color: Colors.white, size: 16),
          label: const Text("ADD ITEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildItemsList([List<Product>? products]) {
    if (_items.isEmpty) {
      return GlassCard(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
              const SizedBox(height: 12),
              Text(
                "No items added to this GRN yet",
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _addItemDialog(products),
                icon: const Icon(Icons.add, color: Color(0xFF818CF8)),
                label: const Text("Add Product Now", style: TextStyle(color: Color(0xFF818CF8))),
              ),
            ],
          ),
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(8),
      child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
        itemBuilder: (ctx, idx) {
          final item = _items[idx];
          final margin = item.sellingPrice > 0
              ? ((item.sellingPrice - item.unitCostPrice) / item.sellingPrice) * 100
              : 0.0;

          return ListTile(
            dense: true,
            title: Text(
              item.productName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              "Qty: ${item.quantity}  ×  Cost: Rs. ${item.unitCostPrice.toStringAsFixed(2)}  •  Selling: Rs. ${item.sellingPrice.toStringAsFixed(2)}  (Margin: ${margin.toStringAsFixed(1)}%)",
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Rs. ${item.subTotal.toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () {
                    setState(() => _items.removeAt(idx));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalsSummary() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "Total Purchase Cost (Payable):",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Rs. ${_totalCost.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "Expected Retail Value:",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Rs. ${_totalRetailValue.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "Projected Gross Profit & Margin:",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Rs. ${_expectedProfit.toStringAsFixed(2)} (${_overallMargin.toStringAsFixed(1)}%)",
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

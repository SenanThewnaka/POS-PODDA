import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/procurement/grn_model.dart';
import 'package:sme_buddy/features/procurement/procurement_repository.dart';
import 'package:sme_buddy/features/procurement/create_grn_screen.dart';
import 'package:sme_buddy/features/procurement/suppliers_screen.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/responsive_layout.dart';

class GRNHistoryScreen extends ConsumerStatefulWidget {
  const GRNHistoryScreen({super.key});

  @override
  ConsumerState<GRNHistoryScreen> createState() => _GRNHistoryScreenState();
}

class _GRNHistoryScreenState extends ConsumerState<GRNHistoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showGRNDetails(GRNModel grn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(grn.grnNumber,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(grn.receivedAt),
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
            _buildStatusChip(grn.paymentStatus),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (grn.supplierName != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.business, size: 16, color: Color(0xFF818CF8)),
                      const SizedBox(width: 6),
                      Text("Supplier: ${grn.supplierName}",
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (grn.invoiceNumber != null && grn.invoiceNumber!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, size: 16, color: Colors.white54),
                      const SizedBox(width: 6),
                      Text("Invoice Ref: ${grn.invoiceNumber}",
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const Divider(color: Colors.white12),
                const Text("Received Items",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...grn.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName,
                                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                                Text(
                                  "${item.quantity} units @ Rs. ${item.unitCostPrice.toStringAsFixed(2)}",
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "Rs. ${item.subTotal.toStringAsFixed(2)}",
                            style: const TextStyle(
                                color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    )),
                const Divider(color: Colors.white12, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Inward Cost:",
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    Text(
                      "Rs. ${grn.totalCost.toStringAsFixed(2)}",
                      style: const TextStyle(
                          color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                if (grn.amountPaid > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Amount Paid:", style: TextStyle(color: Colors.white54, fontSize: 13)),
                      Text(
                        "Rs. ${grn.amountPaid.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
                if (grn.notes != null && grn.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text("Notes: ${grn.notes!}",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text("Edit GRN"),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateGRNScreen(existingGRN: grn)),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color text;
    String label = status;

    switch (status) {
      case 'PAID':
        bg = Colors.green.withOpacity(0.2);
        text = Colors.greenAccent;
        label = "PAID";
        break;
      case 'CREDIT':
        bg = Colors.red.withOpacity(0.2);
        text = Colors.redAccent;
        label = "CREDIT";
        break;
      case 'PARTIAL':
        bg = Colors.amber.withOpacity(0.2);
        text = Colors.amberAccent;
        label = "PARTIAL";
        break;
      default:
        bg = Colors.white12;
        text = Colors.white70;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grnAsync = ref.watch(grnListStreamProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return GlassScaffold(
      appBar: AppBar(
        title: const Text("Procurement & GRN Inward", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen()));
            },
            icon: const Icon(Icons.people_outline),
            tooltip: "Suppliers Directory",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGRNScreen()));
        },
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text("NEW GRN (INWARD)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Top search & action banner
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search by GRN #, Supplier, or Invoice #...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen()));
                  },
                  icon: const Icon(Icons.business, color: Color(0xFF818CF8), size: 18),
                  label: const Text("Suppliers", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),

          // GRN List / Grid
          Expanded(
            child: grnAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
              error: (err, _) => Center(
                child: Text("Error: $err", style: const TextStyle(color: Colors.redAccent)),
              ),
              data: (grnList) {
                final filtered = grnList.where((g) {
                  if (_searchQuery.isEmpty) return true;
                  final matchGrn = g.grnNumber.toLowerCase().contains(_searchQuery);
                  final matchSupplier = g.supplierName?.toLowerCase().contains(_searchQuery) ?? false;
                  final matchInv = g.invoiceNumber?.toLowerCase().contains(_searchQuery) ?? false;
                  return matchGrn || matchSupplier || matchInv;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? "No GRN records yet" : "No GRN records match '$_searchQuery'",
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGRNScreen()));
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text("Receive First Shipment", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }

                if (isDesktop) {
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 450,
                      mainAxisExtent: 180,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _buildGRNCard(filtered[i]),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildGRNCard(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGRNCard(GRNModel grn) {
    return InkWell(
      onTap: () => _showGRNDetails(grn),
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory, color: Color(0xFF818CF8), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              grn.grnNumber,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              DateFormat('MMM dd, yyyy').format(grn.receivedAt),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(grn.paymentStatus),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                  tooltip: "Edit GRN",
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CreateGRNScreen(existingGRN: grn)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.business, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    grn.supplierName ?? "Direct / Internal",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (grn.invoiceNumber != null && grn.invoiceNumber!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    "Inv: ${grn.invoiceNumber}",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                  ),
                ],
              ],
            ),
            const Divider(color: Colors.white12, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "${grn.items.length} items received",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Rs. ${grn.totalCost.toStringAsFixed(2)}",
                  style: const TextStyle(
                      color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

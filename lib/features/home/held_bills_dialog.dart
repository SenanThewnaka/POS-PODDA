import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/home/cart_provider.dart';
import 'package:sme_buddy/features/home/held_bills_provider.dart';

class HeldBillsDialog extends ConsumerWidget {
  const HeldBillsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const HeldBillsDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heldBills = ref.watch(heldBillsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = screenSize.width > 600 ? 550.0 : screenSize.width * 0.92;
    final dialogHeight = (screenSize.height * 0.78).clamp(360.0, 650.0);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pause_circle_outline, color: Colors.amber, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Held Orders",
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${heldBills.length} parked cart${heldBills.length == 1 ? '' : 's'}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (heldBills.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _confirmClearAll(context, ref),
                      icon: const Icon(Icons.delete_sweep, size: 18, color: Colors.redAccent),
                      label: const Text(
                        "Clear All",
                        style: TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // Content
              Expanded(
                child: heldBills.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.remove_shopping_cart_outlined,
                              size: 56,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "No held orders currently",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Park orders when a customer steps away or needs time",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: heldBills.length,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final bill = heldBills[index];
                          return _buildHeldBillCard(context, ref, bill, isDark);
                        },
                      ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeldBillCard(
    BuildContext context,
    WidgetRef ref,
    HeldBill bill,
    bool isDark,
  ) {
    final diff = DateTime.now().difference(bill.createdAt);
    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = "Just now";
    } else if (diff.inMinutes < 60) {
      timeAgo = "${diff.inMinutes}m ago";
    } else {
      timeAgo = "${diff.inHours}h ago";
    }

    final previewItems = bill.items.values
        .take(3)
        .map((i) => "${i.quantity.toInt()}x ${i.product.name}")
        .join(", ");
    final remainingCount = bill.items.length - 3;
    final summaryText = remainingCount > 0
        ? "$previewItems +$remainingCount more"
        : previewItems;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  bill.id,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                "${DateFormat('hh:mm a').format(bill.createdAt)} • $timeAgo",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (bill.customerName != null && bill.customerName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 14, color: Colors.cyanAccent),
                  const SizedBox(width: 4),
                  Text(
                    bill.customerName!,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),

          if (bill.note != null && bill.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "Note: ${bill.note!}",
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70),
              ),
            ),

          Text(
            summaryText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Rs. ${bill.totalAmount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: "Void Held Bill",
                    onPressed: () => _confirmDelete(context, ref, bill),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text("Resume", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => _resumeBill(context, ref, bill),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _resumeBill(BuildContext context, WidgetRef ref, HeldBill bill) async {
    final currentCart = ref.read(cartProvider);

    if (currentCart.isNotEmpty) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Current Cart Has Items"),
          content: const Text(
            "Your current cart already contains items. Would you like to replace the current cart with this held order, or merge them?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'merge'),
              child: const Text("Merge Items"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 40),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: const Text("Replace Cart"),
            ),
          ],
        ),
      );

      if (action == null || action == 'cancel') return;

      if (action == 'replace') {
        ref.read(cartProvider.notifier).replaceCart(bill.items);
      } else if (action == 'merge') {
        for (var item in bill.items.values) {
          ref.read(cartProvider.notifier).addToCart(
                item.product,
                quantity: item.quantity,
                overridePrice: item.effectivePrice,
                overrideCostPrice: item.costPrice,
                description: item.description,
              );
        }
      }
    } else {
      ref.read(cartProvider.notifier).replaceCart(bill.items);
    }

    await ref.read(heldBillsProvider.notifier).deleteHeldBill(bill.id);

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Resumed held order ${bill.id} to cart"),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, HeldBill bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Held Order?"),
        content: Text("Are you sure you want to permanently discard held order ${bill.id}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 40),
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(heldBillsProvider.notifier).deleteHeldBill(bill.id);
              Navigator.pop(ctx);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All Held Orders?"),
        content: const Text("Are you sure you want to discard all currently held orders?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 40),
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(heldBillsProvider.notifier).clearAll();
              Navigator.pop(ctx);
            },
            child: const Text("Clear All"),
          ),
        ],
      ),
    );
  }
}

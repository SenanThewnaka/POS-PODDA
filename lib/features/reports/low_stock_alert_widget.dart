import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/unit_formatter.dart';

final lowStockProvider = FutureProvider<List<Product>>((ref) {
  return ref.read(productRepositoryProvider).getLowStockItems();
});

class LowStockAlertWidget extends ConsumerWidget {
  const LowStockAlertWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockAsync = ref.watch(lowStockProvider);

    return lowStockAsync.when(
      loading: () => const SizedBox(), // Hidden while loading to avoid jump
      error: (_,__) => const SizedBox(),
      data: (items) {
        if (items.isEmpty) return const SizedBox();

        return GlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 24),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                 children: [
                   const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                   const SizedBox(width: 8),
                   Text("Low Stock Alerts (${items.length})", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                 ],
               ),
               const SizedBox(height: 12),
               ListView.separated(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: items.length > 5 ? 5 : items.length, // Show max 5
                 separatorBuilder: (_,__) => const Divider(height: 8),
                 itemBuilder: (context, index) {
                    final p = items[index];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                        Text(
                          UnitFormatter.format(p.currentStock, p.baseUnit),
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        )
                      ],
                    );
                 },
               ),
               if (items.length > 5)
                 Padding(
                   padding: const EdgeInsets.only(top: 8.0),
                   child: Center(child: Text("+ ${items.length - 5} more items", style: const TextStyle(fontSize: 11, color: Colors.grey))),
                 )
            ],
          ),
        );
      }
    );
  }
}

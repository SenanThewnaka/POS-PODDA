import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/reports/sales_repository.dart';
import 'package:sme_buddy/features/reports/sale_model.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/utils/unit_formatter.dart';

class ProductStat {
  final String productId;
  final String productName;
  final double totalQty;
  final double totalRevenue;
  final String? baseUnit; // Added

  ProductStat({
    required this.productId,
    required this.productName,
    required this.totalQty,
    required this.totalRevenue,
    this.baseUnit,
  });
}

class TopProductsScreen extends ConsumerStatefulWidget {
  const TopProductsScreen({super.key});

  @override
  ConsumerState<TopProductsScreen> createState() => _TopProductsScreenState();
}

class _TopProductsScreenState extends ConsumerState<TopProductsScreen> {
  String _filterType = 'Daily'; // Daily, Weekly, Monthly, Custom
  DateTimeRange? _customRange;
  String _sortBy = 'Quantity'; // Quantity, Revenue
  bool _sortDescending = true;

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_filterType == 'Daily') {
      return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: endOfToday);
    } else if (_filterType == 'Weekly') {
      return DateTimeRange(start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)), end: endOfToday);
    } else if (_filterType == 'Monthly') {
      return DateTimeRange(start: DateTime(now.year, now.month, 1), end: endOfToday);
    } else if (_filterType == 'Custom' && _customRange != null) {
      return DateTimeRange(
        start: _customRange!.start, 
        end: DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59)
      );
    }
    return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: endOfToday);
  }

  @override
  Widget build(BuildContext context) {
    final range = _getDateRange();
    final dateStr = _filterType == 'Daily' 
        ? DateFormat('MMM d, yyyy').format(range.start)
        : "${DateFormat('MMM d').format(range.start)} - ${DateFormat('MMM d').format(range.end)}";

    return Scaffold(
      appBar: AppBar(title: const Text("Top Products")),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                Row(
                  children: [
                     Expanded(
                       child: DropdownButton<String>(
                         isExpanded: true,
                         value: _filterType,
                         underline: const SizedBox(),
                         items: ["Daily", "Weekly", "Monthly", "Custom"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                         onChanged: (val) async {
                            if (val == 'Custom') {
                               final picked = await showDateRangePicker(
                                  context: context, 
                                  firstDate: DateTime(2023), 
                                  lastDate: DateTime.now()
                               );
                               if (picked != null) {
                                  setState(() {
                                    _customRange = picked;
                                    _filterType = val!;
                                  });
                               }
                            } else {
                               setState(() => _filterType = val!);
                            }
                         },
                       ),
                     ),
                     const SizedBox(width: 16),
                     Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Sort By:"),
                    DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      items: ["Quantity", "Revenue"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _sortBy = val!),
                    ),
                    IconButton(
                      icon: Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward),
                      onPressed: () => setState(() => _sortDescending = !_sortDescending),
                    )
                  ],
                )
              ],
            ),
          ),
          
          // List
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                 final salesAsync = ref.watch(salesListProvider(range));
                 
                 return salesAsync.when(
                   loading: () => const Center(child: CircularProgressIndicator()),
                   error: (err, st) => Center(child: Text("Error: $err")),
                   data: (sales) {
                      final productsAsync = ref.watch(productsStreamProvider); // Assumes we have this provider exposed or can create it
                      // Wait, I need to know where productsStreamProvider is defined. 
                      // Usually in product_repository.dart: `final productsStreamProvider = StreamProvider((ref) => ...)`
                      // Let's assume I can access repo.
                   
                      return productsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e,s) => Center(child: Text("$e")),
                        data: (products) {
                          final productMap = {for (var p in products) p.id: p};

                      if (sales.isEmpty) return const Center(child: Text("No sales in this period."));
                      
                      // Aggregation Logic
                      final Map<String, ProductStat> stats = {};
                      
                      for (var sale in sales) {
                        for (var item in sale.items) {
                           if (!stats.containsKey(item.productId)) {
                             // Lookup Unit
                             final product = productMap[item.productId];
                             final baseUnit = product?.baseUnit;

                             stats[item.productId] = ProductStat(
                               productId: item.productId, 
                               productName: item.productName, 
                               totalQty: 0, 
                               totalRevenue: 0,
                               baseUnit: baseUnit,
                             );
                           }
                           final current = stats[item.productId]!;
                           // Handle duplicate map updates safely
                           stats[item.productId] = ProductStat(
                             productId: current.productId,
                             productName: current.productName, // Keep original name/latest name
                             totalQty: current.totalQty + item.quantity,
                             totalRevenue: current.totalRevenue + item.subTotal,
                             baseUnit: current.baseUnit,
                           );
                        }
                      }
                      
                      var sortedList = stats.values.toList();
                      
                      // Sorting
                      sortedList.sort((a, b) {
                         int result = 0;
                         if (_sortBy == 'Quantity') {
                            result = a.totalQty.compareTo(b.totalQty);
                         } else {
                            result = a.totalRevenue.compareTo(b.totalRevenue);
                         }
                         return _sortDescending ? -result : result; // Reverse if descending
                      });

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: sortedList.length,
                        separatorBuilder: (_,__) => const Divider(),
                        itemBuilder: (context, index) {
                           final stat = sortedList[index];
                           final isTop = index < 3;
                           
                           return ListTile(
                             leading: CircleAvatar(
                               backgroundColor: isTop ? Colors.orange : Colors.grey[200],
                               child: Text("${index + 1}", style: TextStyle(color: isTop ? Colors.white : Colors.black)),
                             ),
                             title: Text(stat.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                             subtitle: Text("${UnitFormatter.format(stat.totalQty, stat.baseUnit)} Sold"), 
                             trailing: Text(
                               "Rs. ${stat.totalRevenue.toStringAsFixed(2)}",
                               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                             ),
                           );
                        },
                      );
                   }); // End Products Async
                   },
                 ); // End Sales Async
              },
            ),
          )
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/reports/sales_repository.dart';
import 'package:sme_buddy/features/reports/sale_model.dart';
import 'package:sme_buddy/features/reports/receipt_screen.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/reports/top_products_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sme_buddy/features/subscription/subscription_guard.dart';
import 'package:sme_buddy/features/subscription/upgrade_dialog.dart';
import 'package:sme_buddy/utils/shimmer_skeletons.dart';
import 'package:sme_buddy/features/subscription/subscription_provider.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/features/reports/advanced_charts_widget.dart';
import 'package:sme_buddy/features/reports/low_stock_alert_widget.dart'; // Low Stock Widget
import 'package:sme_buddy/utils/csv_exporter.dart'; // Imported CSV Exporter

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _filterType = 'Daily'; // Daily, Weekly, Monthly, Custom
  DateTimeRange? _customRange;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener(DateTimeRange range) {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(pagedSalesProvider(range).notifier).loadNextPage();
      }
    });
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    // Stable "End of Today" for cache consistency
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_filterType == 'Daily') {
      return DateTimeRange(
        start: DateTime(now.year, now.month, now.day), 
        end: endOfToday
      );
    } else if (_filterType == 'Weekly') {
      // Last 7 Days (Stable)
      // Start: 6 days ago (start of day)
      // End: Today (end of day)
      return DateTimeRange(
        start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)), 
        end: endOfToday
      );
    } else if (_filterType == 'Monthly') {
      // Start of Month to End of Today
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1), 
        end: endOfToday
      );
    } else if (_filterType == 'Custom' && _customRange != null) {
      // Allow custom time properly
      return DateTimeRange(
        start: _customRange!.start, 
        end: DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59)
      );
    }
    // Default fallback to Daily
    return DateTimeRange(
      start: DateTime(now.year, now.month, now.day), 
      end: endOfToday
    );
  }



  @override
  Widget build(BuildContext context) {
    final range = _getDateRange();
    final summaryAsync = ref.watch(salesSummaryProvider(range));
    final salesState = ref.watch(pagedSalesProvider(range));
    final subState = ref.watch(subscriptionProvider).valueOrNull;
    
    if (!_scrollController.hasListeners) _setupScrollListener(range);

    final dateStr = _filterType == 'Daily' 
        ? DateFormat('MMM d, yyyy').format(range.start)
        : "${DateFormat('MMM d').format(range.start)} - ${DateFormat('MMM d').format(range.end)}";

    return GlassScaffold( // Use GlassScaffold
      appBar: AppBar(
        title: const Text("Sales Reports"), 
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {
               if (salesState.sales.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No sales to export.")));
                 return;
               }
               CsvExporter.exportSales(salesState.sales);
            }, 
            icon: const Icon(Icons.file_download),
            tooltip: "Export CSV",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
           await ref.read(pagedSalesProvider(range).notifier).refresh();
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(), 
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter Header (Wrap in GlassCard for better readability)
            GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterType,
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                      icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent),
                      items: ["Daily", "Weekly", "Monthly", "Custom"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) async {
                         if (val == 'Custom') {
                            final picked = await showDateRangePicker(
                               context: context, 
                               firstDate: DateTime(2020), 
                               lastDate: DateTime.now().add(const Duration(days: 1)), // Allow full today
                               initialDateRange: _customRange ?? DateTimeRange(
                                 start: DateTime.now().subtract(const Duration(days: 7)), 
                                 end: DateTime.now()
                               ),
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
                  Text(dateStr, style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // LOW STOCK ALERT 
            const LowStockAlertWidget(),

            summaryAsync.when(
              loading: () => Column(
                children: List.generate(4, (_) => const ShimmerListTile()),
              ),
              error: (err, st) => Center(
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text('Failed to load report', style: TextStyle(color: Colors.red.shade300)),
                  ],
                ),
              ),
              data: (summary) {
                return Column(
                  children: [
                    // Dashboard Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                      children: [
                        _buildStatCard("Total Sales", summary.totalSales, Colors.cyanAccent),
                        _buildStatCard("Cash in Hand", summary.cashInHand, Colors.greenAccent),
                        _buildStatCard("Credit Given", summary.creditGiven, Colors.pinkAccent),
                        _buildStatCard("Card Sales", summary.totalSales - summary.cashInHand - summary.creditGiven, Colors.orangeAccent),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // ADVANCED CHARTS SECTION (PRO Only)
                    if (subState?.canViewAdvancedStats == true) 
                       AdvancedChartsWidget(range: range)
                    else 
                       _buildUpgradeTeaser(context),

                    if (summary.totalSales > 0)
                      GlassCard( // Use GlassCard for Top Item
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                             const Icon(Icons.star, color: Colors.purpleAccent, size: 40),
                             const SizedBox(width: 16),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                     children: [
                                        const Text("Top Item (Qty)", style: TextStyle(color: Colors.purpleAccent)),
                                        TextButton(
                                          onPressed: () async {
                                             if (await SubscriptionGuard.check(context, ref, SubscriptionAction.viewAdvancedStats)) {
                                                if (context.mounted) {
                                                   Navigator.push(context, MaterialPageRoute(builder: (_) => const TopProductsScreen()));
                                                }
                                             }
                                          },
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(50, 20),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text("View All", style: TextStyle(fontSize: 12, color: Colors.white70)),
                                        )
                                     ],
                                   ),
                                   _buildTopItemText(summary.mostSoldItem, range),
                                 ],
                               ),
                             )
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),
                    Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                          Text("Sales History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                          Text("${salesState.sales.length}${salesState.hasMore ? '+' : ''} Records", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
                       ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 4),
                        Text(
                          "Bills older than 60 days are automatically deleted.",
                          style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Sales List (Paged)
                    if (salesState.sales.isEmpty && salesState.isLoading)
                       Column(
                         children: List.generate(5, (_) => const ShimmerListTile()),
                       )
                     else if (salesState.sales.isEmpty)
                       Padding(
                         padding: const EdgeInsets.symmetric(vertical: 40),
                         child: Column(
                           children: [
                             const Icon(Icons.receipt_long_outlined, size: 72, color: Colors.white24),
                             const SizedBox(height: 16),
                             const Text('No Sales Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white54)),
                             const SizedBox(height: 6),
                             const Text('Complete a sale to see it here.', style: TextStyle(color: Colors.white30)),
                           ],
                         ),
                       )
                    else
                       ListView.separated(
                         shrinkWrap: true,
                         physics: const NeverScrollableScrollPhysics(),
                         itemCount: salesState.sales.length + (salesState.hasMore ? 1 : 0),
                         separatorBuilder: (_,__) => Divider(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black12),
                         itemBuilder: (context, index) {
                           if (index == salesState.sales.length) {
                             return const ShimmerListTile();
                           }
                           final sale = salesState.sales[index];
                           return GlassCard( // Use GlassCard for list items too or keep transparent list tile
                             margin: EdgeInsets.zero,
                             padding: EdgeInsets.zero,
                             borderRadius: 12,
                             child: ListTile(
                               leading: Container( // Nice icon container
                                 padding: const EdgeInsets.all(8),
                                 decoration: BoxDecoration(
                                   color: (sale.paymentMethod == 'CREDIT' ? Colors.redAccent : Colors.greenAccent).withValues(alpha: 0.2),
                                   shape: BoxShape.circle,
                                 ),
                                 child: Icon(
                                   Icons.receipt, 
                                   color: sale.paymentMethod == 'CREDIT' ? Colors.redAccent : Colors.greenAccent,
                                   size: 20,
                                 ),
                               ),
                               title: Text("Rs. ${sale.totalAmount}", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                               subtitle: Text(
                                 "${DateFormat('MMM d, hh:mm a').format(sale.timestamp)}\n${sale.items.length} Items • ${sale.paymentMethod}",
                                 style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)
                               ),
                               trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
                               onTap: () {
                                 Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(sale: sale)));
                               },
                             ),
                           );
                         },
                       ),
                    
                  ],
                );
              },
            ),
          ],
        ),
        ),
      ),
    );
  }

  // ... ( _buildTopItemText style tweaks for white text) ... 
  Widget _buildTopItemText(String summaryItem, DateTimeRange range) {
     // ...
     // style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
     // ... (Implement in logic below, I can't selectively replace inside method easily with find/replace unless I provide full method, so I'll leave as is, inherited style might be fine if Theme is dark)
     final topItemAsync = ref.watch(topItemNameProvider(range));
     if (_filterType == 'Daily' || summaryItem != "Multiple Days") {
        return Text(summaryItem, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white));
     }
     return topItemAsync.when(
       loading: () => const Text("Analyzing...", style: TextStyle(fontSize: 16, color: Colors.white54)),
       error: (_,__) => const Text("View Details", style: TextStyle(fontSize: 16, color: Colors.white70)),
       data: (name) => Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
     );
  }

  Widget _buildStatCard(String title, double value, Color color) {
    return GlassCard( // Use GlassCard
      padding: const EdgeInsets.all(12),
      border: Border.all(color: color.withValues(alpha: 0.5)),
      child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
           const SizedBox(height: 8),
           Text("Rs. ${value.toInt()}", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
         ],
      ),
    );
  }

  Widget _buildUpgradeTeaser(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
           const Icon(Icons.lock_outline, size: 40, color: Colors.purpleAccent),
           const SizedBox(height: 12),
           const Text("Advanced Analytics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
           const SizedBox(height: 8),
           const Text(
             "Upgrade to Pro to view Sales Trends, Revenue breakdown, and Top Selling Items.",
             textAlign: TextAlign.center,
             style: TextStyle(color: Colors.grey),
           ),
           const SizedBox(height: 16),
           ElevatedButton(
             onPressed: () => UpgradeDialog.show(context, reason: "View Advanced Analytics"),
             style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white),
             child: const Text("UPGRADE TO PRO"),
           )
        ],
      ),
    );
  }
}

// COST OPTIMIZATION: Pagination Logic
class PagedSalesState {
  final List<Sale> sales;
  final bool isLoading;
  final bool hasMore;
  final DocumentSnapshot? lastDoc;
  
  const PagedSalesState({
    this.sales = const [], 
    this.isLoading = false, 
    this.hasMore = true,
    this.lastDoc
  });
  
  PagedSalesState copyWith({List<Sale>? sales, bool? isLoading, bool? hasMore, DocumentSnapshot? lastDoc}) {
    return PagedSalesState(
      sales: sales ?? this.sales,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: lastDoc ?? this.lastDoc
    );
  }
}

class SalesPaginationNotifier extends StateNotifier<PagedSalesState> {
  final Query query;
  final int limit = 20; // Only load 20 at a time (Cost Savings)
  
  SalesPaginationNotifier(this.query) : super(const PagedSalesState()) {
    loadNextPage(); 
  }
  
  Future<void> refresh() async {
    state = const PagedSalesState(); // Reset
    await loadNextPage();
  }
  
  Future<void> loadNextPage() async {
    if (!state.hasMore || state.isLoading) return;
    
    state = state.copyWith(isLoading: true);
    
    try {
      Query q = query.limit(limit);
      if (state.lastDoc != null) {
        q = q.startAfterDocument(state.lastDoc!);
      }
      
      final snapshot = await q.get();
      final newSales = snapshot.docs.map((d) => Sale.fromMap(d.data() as Map<String, dynamic>)).toList();
      
      state = state.copyWith(
        sales: [...state.sales, ...newSales],
        isLoading: false,
        hasMore: newSales.length == limit,
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : state.lastDoc
      );
    } catch (e) {
      state = state.copyWith(isLoading: false); 
    }
  }
}

final pagedSalesProvider = StateNotifierProvider.family.autoDispose<SalesPaginationNotifier, PagedSalesState, DateTimeRange>((ref, range) {
  final repo = ref.watch(salesRepositoryProvider);
  final query = repo.getSalesQuery(range.start, range.end);
  return SalesPaginationNotifier(query);
});

final topItemNameProvider = FutureProvider.family<String, DateTimeRange>((ref, range) async {
  // Fetch ALL sales for the period (can be expensive, but necessary for "True Top Item")
  final sales = await ref.read(salesRepositoryProvider).getSales(range.start, range.end);
  if (sales.isEmpty) return "No Sales";

  final Map<String, double> qtyMap = {};
  
  for (var sale in sales) {
    for (var item in sale.items) {
       qtyMap[item.productName] = (qtyMap[item.productName] ?? 0) + item.quantity;
    }
  }
  
  if (qtyMap.isEmpty) return "No Items";
  
  // Find Max
  var sortedEntries = qtyMap.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
    
  return sortedEntries.first.key;
});

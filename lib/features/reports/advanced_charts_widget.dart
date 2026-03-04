import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/reports/sales_repository.dart';
import 'package:sme_buddy/utils/glass_card.dart';

class AdvancedChartsWidget extends ConsumerWidget {
  final DateTimeRange range;

  const AdvancedChartsWidget({super.key, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We can use a FutureProvider for each, or just FutureBuilder for simplicity inside this dashboard
    // Let's use FutureBuilder to decouple slightly and keep main screen clean.
    final repo = ref.watch(salesRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. SALES TREND CHART
        FutureBuilder<List<Map<String, dynamic>>>(
          future: repo.getDailySalesTrend(range.start, range.end),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
            
            final data = snapshot.data!;
            // Ensure sorted by date
            data.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
            
            return _SalesTrendBarChart(data: data);
          },
        ),

        // 2. PIE CHART (Payments) + BAR CHART (Top Items) - Side by Side on Tablet, Column on Phone
        LayoutBuilder(
          builder: (context, constraints) {
             // Basic threshold check
             bool wide = constraints.maxWidth > 600;
             var children = [
                 // PIE
                 FutureBuilder<Map<String, double>>(
                   future: repo.getPaymentBreakdown(range.start, range.end),
                   builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
                      final breakdown = snapshot.data!;
                      final total = breakdown.values.fold(0.0, (a, b) => a + b);
                      
                      final sections = breakdown.entries.map((e) {
                         final color = e.key == 'CASH' ? Colors.greenAccent : (e.key == 'CREDIT' ? Colors.redAccent : Colors.orangeAccent);
                         return PieChartSectionData(
                           color: color,
                           value: e.value,
                           title: '${(e.value / total * 100).toStringAsFixed(0)}%',
                           radius: 40,
                           titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                         );
                      }).toList();

                      return GlassCard(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text("Revenue Source", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                            SizedBox(
                              height: 150,
                              child: PieChart(
                                PieChartData(
                                  sections: sections,
                                  centerSpaceRadius: 30,
                                  sectionsSpace: 2,
                                )
                              ),
                            ),
                            // Legend
                            Wrap(
                              spacing: 8,
                              children: breakdown.keys.map((k) {
                                 final color = k == 'CASH' ? Colors.greenAccent : (k == 'CREDIT' ? Colors.redAccent : Colors.orangeAccent);
                                 return Row(mainAxisSize: MainAxisSize.min, children: [
                                   Container(width: 8, height: 8, color: color),
                                   const SizedBox(width: 4),
                                   Text(k, style: const TextStyle(fontSize: 10))
                                 ]);
                              }).toList(),
                            )
                          ],
                        ),
                      );
                   },
                 ),
                 
                 if (!wide) const SizedBox(height: 16),
                 
                 // TOP ITEMS BAR
                 FutureBuilder<List<Map<String, dynamic>>>(
                   future: repo.getTopSellingItems(range.start, range.end),
                   builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
                      final items = snapshot.data!;
                      
                      return GlassCard(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              Text("Top Products", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                              const SizedBox(height: 12),
                              ...items.map((item) {
                                 final qty = (item['qty'] as double);
                                 final maxQty = (items.first['qty'] as double); // First is max per sort
                                 final percent = qty / maxQty;
                                 
                                 return Padding(
                                   padding: const EdgeInsets.symmetric(vertical: 4),
                                   child: Row(
                                     children: [
                                       Expanded(flex: 3, child: Text(item['name'], style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                       Expanded(
                                         flex: 5,
                                         child: Stack(
                                           children: [
                                             Container(height: 8, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
                                             FractionallySizedBox(
                                               widthFactor: percent, 
                                               child: Container(height: 8, decoration: BoxDecoration(color: Colors.purpleAccent, borderRadius: BorderRadius.circular(4))),
                                             )
                                           ],
                                         ),
                                       ),
                                       const SizedBox(width: 8),
                                       Text(qty.toStringAsFixed(0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                     ],
                                   ),
                                 );
                              }).toList()
                           ],
                        ),
                      );
                   },
                 )
             ];

             if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 16),
                    Expanded(child: children[1]), // If child[1] exists
                  ],
                );
             } else {
               return Column(children: children);
             }
          } 
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _SalesTrendBarChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  const _SalesTrendBarChart({required this.data});

  @override
  State<_SalesTrendBarChart> createState() => _SalesTrendBarChartState();
}

class _SalesTrendBarChartState extends State<_SalesTrendBarChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox();

    // Default to last item if nothing touched
    final showIndex = touchedIndex == -1 ? widget.data.length - 1 : touchedIndex;
    final selectedItem = widget.data[showIndex];
    
    // Calculate Max Y for scale
    final maxY = widget.data.fold(0.0, (p, e) => (e['amount'] as double) > p ? (e['amount'] as double) : p) * 1.2;

    // Sort check is already done by parent but good to be safe if reused
    // widget.data is final so we assume sorted orders.

    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text("Sales Trend", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                   borderRadius: BorderRadius.circular(8)
                 ),
                 child: Text("Interactive", style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
               )
            ],
          ),
          const SizedBox(height: 8),
          
          // DYNAMIC SUMMARY (Instant Clarity)
          Row(
             crossAxisAlignment: CrossAxisAlignment.end,
             children: [
                Text(
                  "Rs. ${NumberFormat('#,##0').format(selectedItem['amount'])}", 
                  style: TextStyle(
                    fontSize: 24, // Big Font
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black
                  )
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    "on ${DateFormat('MMMM d').format(selectedItem['date'] as DateTime)}",
                    style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)
                  ),
                ),
             ],
          ),
          
          const SizedBox(height: 16),
          
          // BAR CHART
          SizedBox(
            height: 220, // Taller
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                     getTooltipColor: (_) => Colors.black87,
                     getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          DateFormat('MMM d').format(widget.data[group.x.toInt()]['date']),
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          children: [
                             TextSpan(text: '\nRs. ${(rod.toY).toStringAsFixed(0)}')
                          ]
                        );
                     }
                  ),
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide Y Axis numbers (cleaner)
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30, // Space for labels
                      getTitlesWidget: (val, meta) {
                         int idx = val.toInt();
                         if (idx >= 0 && idx < widget.data.length) {
                             // Smart Labeling
                             if (widget.data.length > 20 && idx % 5 != 0) return const SizedBox();
                             if (widget.data.length > 10 && idx % 2 != 0) return const SizedBox();
                             
                             final date = widget.data[idx]['date'] as DateTime;
                             return Padding(
                               padding: const EdgeInsets.only(top: 8.0),
                               child: Text(DateFormat('d/M').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                             );
                         }
                         return const SizedBox();
                      }
                    )
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barGroups: widget.data.asMap().entries.map((e) {
                   final index = e.key;
                   final amount = (e.value['amount'] as double);
                   final isTouched = index == showIndex; // Highlight selected
                   
                   return BarChartGroupData(
                     x: index,
                     barRods: [
                       BarChartRodData(
                         toY: amount,
                         // Gradient or Solid? Gradient looks nicer
                         gradient: LinearGradient(
                           colors: isTouched 
                             ? [Colors.cyanAccent, Colors.blueAccent]
                             : [Colors.cyan.withValues(alpha: 0.5), Colors.blue.withValues(alpha: 0.5)],
                           begin: Alignment.bottomCenter,
                           end: Alignment.topCenter
                         ),
                         width: widget.data.length > 15 ? 8 : 16, // Dynamic width
                         borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                         backDrawRodData: BackgroundBarChartRodData(
                           show: true,
                           toY: maxY,
                           color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), 
                         )
                       )
                     ]
                   );
                }).toList(),
              )
            ),
          )
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/reports/profit_repository.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/responsive_layout.dart';

class ProfitLossScreen extends ConsumerStatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  ConsumerState<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends ConsumerState<ProfitLossScreen> {
  String _filterType = 'This Month'; // 'Today', 'Yesterday', 'Last 7 Days', 'This Month', 'Custom'
  DateTimeRange? _customRange;

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_filterType == 'Today') {
      return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: endOfToday);
    } else if (_filterType == 'Yesterday') {
      final yStart = DateTime(now.year, now.month, now.day - 1);
      final yEnd = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
      return DateTimeRange(start: yStart, end: yEnd);
    } else if (_filterType == 'Last 7 Days') {
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      return DateTimeRange(start: start, end: endOfToday);
    } else if (_filterType == 'This Month') {
      final start = DateTime(now.year, now.month, 1);
      return DateTimeRange(start: start, end: endOfToday);
    } else if (_filterType == 'Custom' && _customRange != null) {
      return DateTimeRange(
        start: _customRange!.start,
        end: DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59),
      );
    }

    return DateTimeRange(start: DateTime(now.year, now.month, 1), end: endOfToday);
  }

  @override
  Widget build(BuildContext context) {
    final range = _getDateRange();
    final profitAsync = ref.watch(profitSummaryProvider(range));
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return GlassScaffold(
      appBar: AppBar(
        title: const Text("P&L & Net Profit", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...['Today', 'Yesterday', 'Last 7 Days', 'This Month'].map((filter) {
                    final isSelected = _filterType == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        selectedColor: const Color(0xFF6366F1),
                        backgroundColor: const Color(0xFF1E293B),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _filterType = filter);
                        },
                      ),
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.date_range, size: 16, color: Colors.cyanAccent),
                    label: Text(
                      _filterType == 'Custom' && _customRange != null
                          ? "${DateFormat('MMM d').format(_customRange!.start)} - ${DateFormat('MMM d').format(_customRange!.end)}"
                          : "Custom",
                      style: TextStyle(
                        color: _filterType == 'Custom' ? Colors.cyanAccent : Colors.white70,
                        fontWeight: _filterType == 'Custom' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    backgroundColor: const Color(0xFF1E293B),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _customRange ?? range,
                      );
                      if (picked != null) {
                        setState(() {
                          _customRange = picked;
                          _filterType = 'Custom';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // P&L Content
          Expanded(
            child: profitAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
              error: (err, _) => Center(
                child: Text("Error: $err", style: const TextStyle(color: Colors.redAccent)),
              ),
              data: (summary) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date range display
                      Text(
                        "${DateFormat('MMMM dd, yyyy').format(range.start)}  →  ${DateFormat('MMMM dd, yyyy').format(range.end)}",
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                      ),
                      const SizedBox(height: 12),

                      // KPI Cards Grid
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(child: _buildKpiCard("Gross Revenue", summary.totalRevenue, Colors.blueAccent, Icons.trending_up)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildKpiCard("Cost of Goods (COGS)", summary.totalCOGS, Colors.amberAccent, Icons.shopping_bag_outlined)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildKpiCard("Gross Profit", summary.grossProfit, Colors.tealAccent, Icons.account_balance_wallet_outlined, subtitle: "Margin: ${summary.grossMarginPercent.toStringAsFixed(1)}%")),
                            const SizedBox(width: 12),
                            Expanded(child: _buildKpiCard("Operating Expenses", summary.operatingExpenses, Colors.orangeAccent, Icons.money_off)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildKpiCard("Net Profit", summary.netProfit, summary.netProfit >= 0 ? Colors.greenAccent : Colors.redAccent, Icons.stars, subtitle: "Margin: ${summary.netMarginPercent.toStringAsFixed(1)}%")),
                          ],
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(child: _buildKpiCard("Gross Revenue", summary.totalRevenue, Colors.blueAccent, Icons.trending_up)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildKpiCard("COGS (Cost)", summary.totalCOGS, Colors.amberAccent, Icons.shopping_bag_outlined)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildKpiCard("Gross Profit", summary.grossProfit, Colors.tealAccent, Icons.account_balance_wallet_outlined, subtitle: "${summary.grossMarginPercent.toStringAsFixed(1)}% Margin")),
                            const SizedBox(width: 12),
                            Expanded(child: _buildKpiCard("Expenses", summary.operatingExpenses, Colors.orangeAccent, Icons.money_off)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildNetProfitBanner(summary),
                      ],

                      const SizedBox(height: 24),

                      // Financial Breakdown Statement
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Income Statement Breakdown",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 16),
                            _buildStatementRow("Gross Sales / Revenue (${summary.transactionCount} orders)", summary.totalRevenue, isPositive: true),
                            _buildStatementRow("Less: Cost of Goods Sold (COGS)", -summary.totalCOGS, isPositive: false),
                            const Divider(color: Colors.white24, height: 24),
                            _buildStatementRow("Gross Profit", summary.grossProfit, isBold: true, highlightColor: Colors.tealAccent),
                            const SizedBox(height: 8),
                            _buildStatementRow("Less: Shift Payouts & Expenses", -summary.operatingExpenses, isPositive: false),
                            const Divider(color: Colors.white38, height: 24),
                            _buildStatementRow(
                              "NET PROFIT (BOTTOM LINE)",
                              summary.netProfit,
                              isBold: true,
                              highlightColor: summary.netProfit >= 0 ? Colors.greenAccent : Colors.redAccent,
                              largeFont: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Product Profitability Leaderboard
                      const Text(
                        "Product Profitability Breakdown",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      if (summary.topProducts.isEmpty)
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              "No product sales recorded in this period.",
                              style: TextStyle(color: Colors.white.withOpacity(0.5)),
                            ),
                          ),
                        )
                      else
                        GlassCard(
                          padding: const EdgeInsets.all(8),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: summary.topProducts.length,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                            itemBuilder: (ctx, idx) {
                              final p = summary.topProducts[idx];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                                  child: Text(
                                    "${idx + 1}",
                                    style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(p.productName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(
                                  "Sold: ${p.quantitySold}  •  Rev: Rs. ${p.revenue.toStringAsFixed(0)}  •  Cost: Rs. ${p.cost.toStringAsFixed(0)}",
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "Rs. ${p.profit.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        color: p.profit >= 0 ? Colors.greenAccent : Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      "${p.marginPercent.toStringAsFixed(1)}% margin",
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, double amount, Color color, IconData icon, {String? subtitle}) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Rs. ${amount.toStringAsFixed(2)}",
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildNetProfitBanner(ProfitSummary summary) {
    final isProfitable = summary.netProfit >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isProfitable ? Colors.green.shade900.withOpacity(0.3) : Colors.red.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isProfitable ? Colors.greenAccent.withOpacity(0.4) : Colors.redAccent.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("NET PROFIT (BOTTOM LINE)",
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                "Rs. ${summary.netProfit.toStringAsFixed(2)}",
                style: TextStyle(
                  color: isProfitable ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isProfitable ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${summary.netMarginPercent.toStringAsFixed(1)}% NET MARGIN",
              style: TextStyle(
                color: isProfitable ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementRow(String label, double amount,
      {bool isPositive = true, bool isBold = false, Color? highlightColor, bool largeFont = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(isBold ? 0.9 : 0.7),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: largeFont ? 15 : 13,
            ),
          ),
          Text(
            amount < 0
                ? "- Rs. ${amount.abs().toStringAsFixed(2)}"
                : "Rs. ${amount.toStringAsFixed(2)}",
            style: TextStyle(
              color: highlightColor ?? (amount >= 0 ? Colors.white : Colors.redAccent),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: largeFont ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

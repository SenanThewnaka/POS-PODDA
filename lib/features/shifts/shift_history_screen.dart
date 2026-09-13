import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/shifts/shift_model.dart';
import 'package:sme_buddy/features/shifts/shift_repository.dart';
import 'package:sme_buddy/features/shifts/z_report_screen.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';

class ShiftHistoryScreen extends ConsumerWidget {
  const ShiftHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(shiftHistoryProvider);
    final activeShiftAsync = ref.watch(currentShiftProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      appBar: AppBar(
        title: const Text("Shifts & Z-Reports", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Active Shift Card (if any)
              activeShiftAsync.when(
                data: (activeShift) {
                  if (activeShift == null) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: GlassCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(16),
                      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5), width: 1.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "CURRENT ACTIVE SHIFT",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.greenAccent,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "Opened ${DateFormat('hh:mm a').format(activeShift.openedAt)}",
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeShift.cashierName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    "${activeShift.transactionCount} transactions",
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    "Drawer Balance",
                                    style: TextStyle(fontSize: 11, color: Colors.greenAccent),
                                  ),
                                  Text(
                                    "Rs. ${activeShift.expectedCash.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              Text(
                "Closed Shifts History",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 10),

              historyAsync.when(
                data: (shifts) {
                  if (shifts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.history_toggle_off, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(height: 12),
                            Text(
                              "No closed shifts found",
                              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: shifts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final shift = shifts[index];
                      final diff = shift.difference ?? 0.0;
                      Color diffColor = Colors.greenAccent;
                      String diffLabel = "Balanced";
                      if (shift.isOver) {
                        diffColor = Colors.blueAccent;
                        diffLabel = "+Rs. ${diff.toStringAsFixed(2)}";
                      } else if (shift.isShort) {
                        diffColor = Colors.redAccent;
                        diffLabel = "-Rs. ${diff.abs().toStringAsFixed(2)}";
                      }

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ZReportScreen(shift: shift)),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: GlassCard(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.receipt_long, color: Colors.cyanAccent, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          shift.cashierName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: diffColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            diffLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: diffColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "${DateFormat('dd MMM yyyy, hh:mm a').format(shift.openedAt)}  •  ${shift.transactionCount} bills",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white54 : Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "Rs. ${shift.totalSales.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Z-Report >",
                                    style: TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text("Error loading shifts: $e")),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

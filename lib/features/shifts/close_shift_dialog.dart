import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/shifts/shift_model.dart';
import 'package:sme_buddy/features/shifts/shift_repository.dart';
import 'package:sme_buddy/features/shifts/z_report_screen.dart';
import 'package:sme_buddy/utils/glass_card.dart';

class CloseShiftDialog extends ConsumerStatefulWidget {
  final ShiftModel shift;

  const CloseShiftDialog({super.key, required this.shift});

  static Future<void> show(BuildContext context, ShiftModel shift) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CloseShiftDialog(shift: shift),
    );
  }

  @override
  ConsumerState<CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends ConsumerState<CloseShiftDialog> {
  final TextEditingController _countedCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  double _countedCash = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default counted to expected cash so cashier can just adjust or confirm
    _countedCash = widget.shift.expectedCash;
    _countedCtrl.text = _countedCash.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _countedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      final closed = await ref.read(shiftRepositoryProvider).closeShift(
            shiftId: widget.shift.id,
            actualCash: _countedCash,
            notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          );
      HapticFeedback.heavyImpact();

      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ZReportScreen(shift: closed)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error closing shift: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final expected = shift.expectedCash;
    final diff = _countedCash - expected;
    final isBalanced = diff.abs() < 0.01;
    final isOver = diff > 0.01;
    final isShort = diff < -0.01;

    Color diffColor = Colors.greenAccent;
    String diffStatus = "Exact Match (Rs. 0.00)";
    if (isOver) {
      diffColor = Colors.blueAccent;
      diffStatus = "Over by +Rs. ${diff.toStringAsFixed(2)}";
    } else if (isShort) {
      diffColor = Colors.redAccent;
      diffStatus = "Short by -Rs. ${diff.abs().toStringAsFixed(2)}";
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4), width: 1.5),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lock_clock, color: Colors.redAccent, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Close Shift & Balance Drawer",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            "Reconcile expected cash with physical drawer count",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Shift Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Column(
                    children: [
                      _summaryRow("Cashier:", shift.cashierName, isDark),
                      const SizedBox(height: 6),
                      _summaryRow("Opening Float:", "Rs. ${shift.openingFloat.toStringAsFixed(2)}", isDark),
                      const SizedBox(height: 6),
                      _summaryRow("Cash Sales:", "Rs. ${shift.cashSales.toStringAsFixed(2)}", isDark),
                      const SizedBox(height: 6),
                      _summaryRow("Cash In (+):", "Rs. ${shift.cashInTotal.toStringAsFixed(2)}", isDark),
                      const SizedBox(height: 6),
                      _summaryRow("Cash Out (-):", "Rs. ${shift.cashOutTotal.toStringAsFixed(2)}", isDark, color: Colors.orangeAccent),
                      const Divider(height: 16),
                      _summaryRow(
                        "EXPECTED DRAWER CASH:",
                        "Rs. ${expected.toStringAsFixed(2)}",
                        isDark,
                        isBold: true,
                        color: Colors.cyanAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Actual Cash Counted Field
                Text(
                  "Actual Counted Cash (Rs.)",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                GlassCard(
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _countedCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      prefixText: "Rs. ",
                      prefixStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _countedCash = double.tryParse(val) ?? 0.0;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Discrepancy Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: diffColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isBalanced
                            ? Icons.check_circle
                            : (isOver ? Icons.arrow_upward : Icons.warning_amber),
                        color: diffColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "VARIANCE STATUS",
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: diffColor),
                            ),
                            Text(
                              diffStatus,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: diffColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Closing Notes
                Text(
                  "Closing Remarks / Audit Notes (Optional)",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                GlassCard(
                  borderRadius: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _notesCtrl,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: const InputDecoration(
                      hintText: "e.g. Discrepancy explanation, petty cash voucher IDs...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Text(
                          "CLOSE SHIFT & GENERATE Z-REPORT",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool isDark, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

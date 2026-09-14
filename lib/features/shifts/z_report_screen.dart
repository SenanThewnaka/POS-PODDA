import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sme_buddy/features/settings/printer_settings_service.dart';
import 'package:sme_buddy/features/shifts/shift_model.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/responsive_layout.dart';

class ZReportScreen extends ConsumerStatefulWidget {
  final ShiftModel shift;

  const ZReportScreen({super.key, required this.shift});

  @override
  ConsumerState<ZReportScreen> createState() => _ZReportScreenState();
}

class _ZReportScreenState extends ConsumerState<ZReportScreen> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.keyP) {
      final user = ref.read(userProfileProvider).value;
      _printReport(context, user);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
  }

  Future<void> _printReport(BuildContext context, UserModel? user) async {
    final settings = ref.read(printerSettingsProvider);
    final pdf = await _generatePdf(user, paperSize: settings.paperSize);
    await ref.read(printerSettingsProvider.notifier).printDocument(
          doc: pdf,
          name: 'Z_Report_${widget.shift.id.substring(0, 8)}',
        );
  }

  Future<void> _sharePdf(BuildContext context, UserModel? user) async {
    final settings = ref.read(printerSettingsProvider);
    final pdf = await _generatePdf(user, paperSize: settings.paperSize);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Z_Report_${DateFormat('yyyyMMdd_HHmm').format(widget.shift.openedAt)}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;
    final user = ref.watch(userProfileProvider).value;
    final printerSettings = ref.watch(printerSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktopOrTablet = context.isTabletOrDesktop;

    final diff = shift.difference ?? 0.0;
    Color diffColor = Colors.greenAccent;
    String diffText = "BALANCED (Rs. 0.00)";
    if (shift.isOver) {
      diffColor = Colors.blueAccent;
      diffText = "OVER (+Rs. ${diff.toStringAsFixed(2)})";
    } else if (shift.isShort) {
      diffColor = Colors.redAccent;
      diffText = "SHORT (-Rs. ${diff.abs().toStringAsFixed(2)})";
    }

    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        _handleKey(event);
        return KeyEventResult.handled;
      },
      child: GlassScaffold(
        appBar: AppBar(
          title: const Text("Day-End Z-Report", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: "Share PDF",
              onPressed: () => _sharePdf(context, user),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Header Card
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 20,
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                  child: Column(
                    children: [
                      const Icon(Icons.assessment_outlined, color: Colors.cyanAccent, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        user?.shopName ?? "POS PODDA",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "OFFICIAL DAY-END Z-REPORT",
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Shift #${shift.id.substring(0, 8).toUpperCase()}",
                        style: const TextStyle(fontSize: 12, color: Colors.cyanAccent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Shift Metadata
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Column(
                    children: [
                      _row("Cashier:", shift.cashierName, isDark),
                      const SizedBox(height: 8),
                      _row(
                        "Opened At:",
                        DateFormat('dd MMM yyyy, hh:mm a').format(shift.openedAt),
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      _row(
                        "Closed At:",
                        shift.closedAt != null
                            ? DateFormat('dd MMM yyyy, hh:mm a').format(shift.closedAt!)
                            : "Still Open",
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      _row("Total Transactions:", "${shift.transactionCount} bills", isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sales Breakdown Card
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Sales by Payment Tender",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                      ),
                      const Divider(height: 20),
                      _row("Cash Sales:", "Rs. ${shift.cashSales.toStringAsFixed(2)}", isDark),
                      const SizedBox(height: 8),
                      _row("Card Sales:", "Rs. ${shift.cardSales.toStringAsFixed(2)}", isDark),
                      const SizedBox(height: 8),
                      _row("Credit Sales (Potha):", "Rs. ${shift.creditSales.toStringAsFixed(2)}", isDark),
                      const Divider(height: 20),
                      _row(
                        "TOTAL SALES REVENUE:",
                        "Rs. ${shift.totalSales.toStringAsFixed(2)}",
                        isDark,
                        isBold: true,
                        color: Colors.greenAccent,
                        fontSize: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Cash Drawer Balancing Card
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  border: Border.all(color: diffColor.withValues(alpha: 0.5)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Cash Drawer Reconciliation",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                      ),
                      const Divider(height: 20),
                      _row("(+) Opening Cash Float:", "Rs. ${shift.openingFloat.toStringAsFixed(2)}", isDark),
                      const SizedBox(height: 8),
                      _row("(+) Cash Sales:", "Rs. ${shift.cashSales.toStringAsFixed(2)}", isDark),
                      const SizedBox(height: 8),
                      _row("(+) Cash In (Added):", "Rs. ${shift.cashInTotal.toStringAsFixed(2)}", isDark),
                      const SizedBox(height: 8),
                      _row("(-) Cash Out (Payouts):", "Rs. ${shift.cashOutTotal.toStringAsFixed(2)}", isDark, color: Colors.orangeAccent),
                      const Divider(height: 20),
                      _row(
                        "EXPECTED CASH IN DRAWER:",
                        "Rs. ${shift.expectedCash.toStringAsFixed(2)}",
                        isDark,
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      _row(
                        "ACTUAL COUNTED CASH:",
                        shift.actualCash != null
                            ? "Rs. ${shift.actualCash!.toStringAsFixed(2)}"
                            : "Not Counted",
                        isDark,
                        isBold: true,
                      ),
                      const Divider(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: diffColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: diffColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                "CASH DISCREPANCY:",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  diffText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: diffColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Drawer Transactions List
                if (shift.cashTransactions.isNotEmpty) ...[
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Cash Movement Audit Log",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                        ),
                        const Divider(height: 20),
                        ...shift.cashTransactions.map((tx) {
                          final isTxIn = tx.type == 'IN';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isTxIn ? Colors.green : Colors.orange).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isTxIn ? "+ IN" : "- OUT",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isTxIn ? Colors.greenAccent : Colors.orangeAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.reason,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('hh:mm a').format(tx.timestamp),
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "Rs. ${tx.amount.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isTxIn ? Colors.greenAccent : Colors.orangeAccent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (shift.notes != null && shift.notes!.isNotEmpty) ...[
                  GlassCard(
                    padding: const EdgeInsets.all(14),
                    borderRadius: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Shift Notes:", style: TextStyle(fontSize: 12, color: Colors.cyanAccent)),
                        const SizedBox(height: 4),
                        Text(shift.notes!, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                ElevatedButton.icon(
                  onPressed: () => _printReport(context, user),
                  icon: const Icon(Icons.print),
                  label: Text(
                    isDesktopOrTablet ? "PRINT Z-REPORT [Enter]" : "PRINT Z-REPORT",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                    foregroundColor: isDark ? Colors.white70 : Colors.black54,
                  ),
                  child: Text(isDesktopOrTablet ? "CLOSE [Esc]" : "CLOSE"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value,
    bool isDark, {
    bool isBold = false,
    Color? color,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
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
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<pw.Document> _generatePdf(UserModel? user, {String paperSize = '80mm'}) async {
    final pdf = pw.Document();
    final is58 = paperSize == '58mm';
    final pageFormat = is58 ? PdfPageFormat.roll57 : PdfPageFormat.roll80;
    final margin = is58 ? 4.0 : 8.0;
    final titleSize = is58 ? 13.0 : 16.0;
    final bodySize = is58 ? 8.0 : 9.5;
    final shift = widget.shift;

    final diff = shift.difference ?? 0.0;
    String diffText = "BALANCED (0.00)";
    if (shift.isOver) diffText = "OVER (+${diff.toStringAsFixed(2)})";
    if (shift.isShort) diffText = "SHORT (-${diff.abs().toStringAsFixed(2)})";

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(margin),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                user?.shopName ?? "POS PODDA",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: titleSize),
                textAlign: pw.TextAlign.center,
              ),
              if (user?.shopAddress != null)
                pw.Text(user!.shopAddress!, style: pw.TextStyle(fontSize: bodySize - 1.5), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 2),
              pw.Text("*** DAY-END Z-REPORT ***", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: bodySize)),
              pw.Text("Shift: #${shift.id.substring(0, 8).toUpperCase()}", style: pw.TextStyle(fontSize: bodySize - 1.5)),
              pw.Divider(thickness: 0.5),

              _pdfRow("Cashier:", shift.cashierName, bodySize),
              _pdfRow("Opened:", DateFormat('yyyy-MM-dd HH:mm').format(shift.openedAt), bodySize),
              if (shift.closedAt != null)
                _pdfRow("Closed:", DateFormat('yyyy-MM-dd HH:mm').format(shift.closedAt!), bodySize),
              _pdfRow("Bills Count:", "${shift.transactionCount}", bodySize),
              pw.Divider(thickness: 0.5),

              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text("SALES BY TENDER", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: bodySize - 0.5)),
              ),
              pw.SizedBox(height: 2),
              _pdfRow("Cash Sales:", "Rs. ${shift.cashSales.toStringAsFixed(2)}", bodySize),
              _pdfRow("Card Sales:", "Rs. ${shift.cardSales.toStringAsFixed(2)}", bodySize),
              _pdfRow("Credit Sales:", "Rs. ${shift.creditSales.toStringAsFixed(2)}", bodySize),
              pw.SizedBox(height: 2),
              _pdfRow("TOTAL SALES:", "Rs. ${shift.totalSales.toStringAsFixed(2)}", bodySize + 1, isBold: true),
              pw.Divider(thickness: 0.5),

              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text("DRAWER BALANCING", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: bodySize - 0.5)),
              ),
              pw.SizedBox(height: 2),
              _pdfRow("(+) Opening Float:", "Rs. ${shift.openingFloat.toStringAsFixed(2)}", bodySize),
              _pdfRow("(+) Cash Sales:", "Rs. ${shift.cashSales.toStringAsFixed(2)}", bodySize),
              _pdfRow("(+) Cash In:", "Rs. ${shift.cashInTotal.toStringAsFixed(2)}", bodySize),
              _pdfRow("(-) Cash Out:", "Rs. ${shift.cashOutTotal.toStringAsFixed(2)}", bodySize),
              pw.SizedBox(height: 2),
              _pdfRow("EXPECTED CASH:", "Rs. ${shift.expectedCash.toStringAsFixed(2)}", bodySize, isBold: true),
              _pdfRow(
                "ACTUAL COUNTED:",
                shift.actualCash != null ? "Rs. ${shift.actualCash!.toStringAsFixed(2)}" : "N/A",
                bodySize,
                isBold: true,
              ),
              _pdfRow("DISCREPANCY:", diffText, bodySize + 0.5, isBold: true),
              pw.Divider(thickness: 0.5),

              if (shift.cashTransactions.isNotEmpty) ...[
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text("DRAWER TRANSACTIONS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: bodySize - 1)),
                ),
                ...shift.cashTransactions.map(
                  (tx) => _pdfRow(
                    "${tx.type == 'IN' ? '+' : '-'} ${tx.reason}:",
                    "Rs. ${tx.amount.toStringAsFixed(2)}",
                    bodySize - 1,
                  ),
                ),
                pw.Divider(thickness: 0.5),
              ],

              if (shift.notes != null && shift.notes!.isNotEmpty) ...[
                pw.Text("Note: ${shift.notes!}", style: pw.TextStyle(fontSize: bodySize - 1.5, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 4),
              ],

              pw.SizedBox(height: 6),
              pw.Text("Powered by POS Podda", style: pw.TextStyle(fontSize: bodySize - 3, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  pw.Widget _pdfRow(String label, String value, double fontSize, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}

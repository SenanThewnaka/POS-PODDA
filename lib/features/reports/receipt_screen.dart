import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/reports/sale_model.dart';
import 'package:sme_buddy/features/settings/printer_settings_service.dart';
import 'package:sme_buddy/features/settings/printer_settings_screen.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/utils/responsive_layout.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptScreen extends ConsumerStatefulWidget {
  final Sale sale;

  const ReceiptScreen({super.key, required this.sale});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _hasAutoPrinted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasAutoPrinted) {
        final settings = ref.read(printerSettingsProvider);
        if (settings.autoPrint) {
          _hasAutoPrinted = true;
          final user = ref.read(userProfileProvider).value;
          _printReceipt(context, user);
        }
      }
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        final user = ref.read(userProfileProvider).value;
        _printReceipt(context, user);
      } else if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyN) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final user = ref.watch(userProfileProvider).value;
    final printerSettings = ref.watch(printerSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktopOrTablet = context.isTabletOrDesktop;

    return Focus(
      autofocus: true,
      focusNode: _keyboardFocusNode,
      onKeyEvent: (node, event) {
        _handleKey(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            "Transaction Complete",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black12,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Theme.of(context).primaryColorDark.withValues(alpha: 0.8),
                      Colors.black87,
                    ]
                  : [
                      Colors.white,
                      Colors.blue.shade50,
                    ],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                children: [
                  SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top + 8),

                  // Quick printer status badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.print, size: 14, color: Colors.cyanAccent),
                            const SizedBox(width: 6),
                            Text(
                              "Paper: ${printerSettings.paperSize} • ${printerSettings.autoPrint ? 'Auto-Print ON' : 'Manual Print'}${printerSettings.directPrint ? ' • Direct' : ''}",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.settings, size: 12, color: Colors.cyanAccent),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: GlassCard(
                        borderRadius: 24,
                        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // SUCCESS ICON
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 46),
                              ),
                              const SizedBox(height: 16),
                              const Center(
                                child: Text(
                                  "PAYMENT SUCCESSFUL",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              Text(
                                "Total Paid",
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                "Rs. ${sale.totalAmount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(sale.timestamp),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                              ),
                              if (sale.paymentMethod == 'CREDIT' && sale.customerId != null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    "Added to Credit (Potha)",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 24),
                              Divider(color: isDark ? Colors.white12 : Colors.black12),

                              // Shop Info Preview
                              if (user != null) ...[
                                Text(
                                  user.shopName ?? "POS Podda",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                if (user.shopAddress != null)
                                  Text(
                                    user.shopAddress!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                const SizedBox(height: 16),
                              ],

                              Text(
                                "Items Purchased",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Items List UI
                              ...sale.items.map((item) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "${item.quantity} x ${item.productName}",
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              item.subTotal.toStringAsFixed(2),
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (item.description != null && item.description!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 16),
                                            child: Text(
                                              item.description!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontStyle: FontStyle.italic,
                                                color: isDark ? Colors.white54 : Colors.black45,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  )),

                              const SizedBox(height: 16),
                              Divider(color: isDark ? Colors.white12 : Colors.black12),
                              if (user?.invoiceFooterMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(
                                    user!.invoiceFooterMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? Colors.white38 : Colors.black45,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _printReceipt(context, user),
                            icon: const Icon(Icons.print),
                            label: Text(
                              isDesktopOrTablet ? "PRINT [Enter]" : "PRINT",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _sharePdf(context, user),
                            icon: const Icon(Icons.share),
                            label: const Text("PDF", style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () => _shareSms(context, user),
                          icon: const Icon(Icons.message),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          tooltip: "SMS",
                        ),
                      ],
                    ),
                  ),

                  // Close Big Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: isDark
                                ? Colors.cyanAccent.withValues(alpha: 0.5)
                                : Colors.blue.withValues(alpha: 0.5),
                          ),
                          foregroundColor: isDark ? Colors.cyanAccent : Colors.blue,
                        ),
                        child: Text(
                          isDesktopOrTablet ? "START NEW SALE [Esc]" : "START NEW SALE",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context, UserModel? user) async {
    final settings = ref.read(printerSettingsProvider);
    final pdf = await _generatePdf(user, paperSize: settings.paperSize);
    await ref.read(printerSettingsProvider.notifier).printDocument(
          doc: pdf,
          name: 'receipt_${widget.sale.id}',
        );
  }

  String _generateReceiptText(UserModel? user) {
    final sb = StringBuffer();
    sb.writeln("*${user?.shopName ?? "POS Podda Receipt"}*");
    if (user?.shopAddress != null) sb.writeln(user!.shopAddress!);
    sb.writeln("Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(widget.sale.timestamp)}");
    sb.writeln("----------------");
    for (var item in widget.sale.items) {
      sb.writeln("${item.productName} x ${item.quantity} = ${item.subTotal}");
      if (item.description != null && item.description!.isNotEmpty) {
        sb.writeln("  (${item.description})");
      }
    }
    sb.writeln("----------------");
    sb.writeln("*TOTAL: Rs. ${widget.sale.totalAmount}*");
    if (user?.invoiceFooterMessage != null) sb.writeln("\n${user!.invoiceFooterMessage}");
    return sb.toString();
  }

  Future<void> _sharePdf(BuildContext context, UserModel? user) async {
    final settings = ref.read(printerSettingsProvider);
    final pdf = await _generatePdf(user, paperSize: settings.paperSize);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'receipt_${widget.sale.timestamp.millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _shareSms(BuildContext context, UserModel? user) async {
    final text = Uri.encodeComponent(_generateReceiptText(user));
    final url = "sms:?body=$text";

    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cannot launch SMS"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<pw.Document> _generatePdf(UserModel? user, {String paperSize = '80mm'}) async {
    final pdf = pw.Document();
    final is58 = paperSize == '58mm';
    final pageFormat = is58 ? PdfPageFormat.roll57 : PdfPageFormat.roll80;
    final margin = is58 ? 4.0 : 8.0;
    final titleSize = is58 ? 13.0 : 16.0;
    final bodySize = is58 ? 8.0 : 9.5;
    final totalSize = is58 ? 11.5 : 14.0;

    pw.ImageProvider? logoImage;
    if (user?.shopLogo != null && user!.shopLogo!.isNotEmpty) {
      try {
        logoImage = await networkImage(user.shopLogo!);
      } catch (e) {
        debugPrint("Logo Error: $e");
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(margin),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              if (logoImage != null)
                pw.Center(
                  child: pw.Image(logoImage, width: is58 ? 35 : 45, height: is58 ? 35 : 45),
                ),

              pw.Center(
                child: pw.Text(
                  user?.shopName ?? "POS Podda Store",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: titleSize),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              if (user?.shopAddress != null)
                pw.Center(
                  child: pw.Text(
                    user!.shopAddress!,
                    style: pw.TextStyle(fontSize: bodySize - 1),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

              if (user?.shopMobile != null)
                pw.Center(
                  child: pw.Text(
                    "Tel: ${user!.shopMobile}",
                    style: pw.TextStyle(fontSize: bodySize - 1),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(widget.sale.timestamp),
                  style: pw.TextStyle(fontSize: bodySize - 1),
                ),
              ),
              pw.Divider(thickness: 0.5),

              // --- ITEMS ---
              ...widget.sale.items.map((item) => pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                "${item.quantity} x ${item.productName}",
                                style: pw.TextStyle(fontSize: bodySize),
                              ),
                            ),
                            pw.Text(
                              item.subTotal.toStringAsFixed(2),
                              style: pw.TextStyle(fontSize: bodySize),
                            ),
                          ],
                        ),
                        if (item.description != null && item.description!.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text(
                              item.description!,
                              style: pw.TextStyle(
                                fontSize: bodySize - 1.5,
                                fontStyle: pw.FontStyle.italic,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )),

              pw.Divider(thickness: 0.5),

              // --- TOTALS ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "TOTAL",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: totalSize - 2),
                  ),
                  pw.Text(
                    "Rs. ${widget.sale.totalAmount.toStringAsFixed(2)}",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: totalSize),
                  ),
                ],
              ),

              // Payment Method Info
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Payment Method:", style: pw.TextStyle(fontSize: bodySize - 1.5)),
                  pw.Text(widget.sale.paymentMethod, style: pw.TextStyle(fontSize: bodySize - 1.5)),
                ],
              ),

              if (widget.sale.paymentMethod == 'CREDIT')
                pw.Center(
                  child: pw.Text(
                    "(CREDIT SALE - UNPAID)",
                    style: pw.TextStyle(fontSize: bodySize - 1.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),

              pw.SizedBox(height: 6),

              // --- FOOTER ---
              if (user?.invoiceFooterMessage != null)
                pw.Center(
                  child: pw.Text(
                    user!.invoiceFooterMessage!,
                    style: pw.TextStyle(fontSize: bodySize - 1, fontStyle: pw.FontStyle.italic),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

              if (user?.invoiceContactInfo != null) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    user!.invoiceContactInfo!,
                    style: pw.TextStyle(fontSize: bodySize - 1.5),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],

              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  "Powered by POS Podda",
                  style: pw.TextStyle(fontSize: bodySize - 3, color: PdfColors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:sme_buddy/utils/glass_card.dart';

class SettlementReceiptScreen extends ConsumerWidget {
  final String customerName;
  final double amountPaid;
  final double previousDue; 
  final double remainingDue;
  final String billId;
  final DateTime timestamp;
  final bool isHistoryView; 

  const SettlementReceiptScreen({
    super.key,
    required this.customerName,
    required this.amountPaid,
    required this.previousDue,
    required this.remainingDue,
    required this.billId,
    required this.timestamp,
    this.isHistoryView = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isHistoryView ? "Bill Status" : "Payment Receipt", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, shape: BoxShape.circle),
             child: Icon(Icons.close, color: isDark ? Colors.white : Colors.black)
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: isDark ? Colors.white : Colors.black),
            onPressed: () => _sharePdf(context, user),
          )
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
                    Colors.black87
                  ]
                : [
                    Colors.white,
                    Colors.blue.shade50
                  ]
          )
        ),
        child: Column(
          children: [
           SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top + 16),
           Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    borderRadius: 24,
                    border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (isHistoryView ? Colors.blue : Colors.green).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: (isHistoryView ? Colors.blue : Colors.green).withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)]
                          ),
                          child: Icon(
                            isHistoryView ? Icons.info_outline : Icons.check_circle, 
                            color: isHistoryView ? Colors.blueAccent : Colors.greenAccent, 
                            size: 50
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user?.shopName ?? "POS Podda",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                          textAlign: TextAlign.center,
                        ),
                        if (user?.shopAddress != null)
                          Text(user!.shopAddress!, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                        const SizedBox(height: 16),
                        Text(
                          isHistoryView ? "Bill Statement" : "Payment Successful", 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)
                        ),
                        const SizedBox(height: 8),
                        Text(DateFormat("dd MMM yyyy - hh:mm a").format(timestamp), style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                        Divider(height: 48, color: isDark ? Colors.white12 : Colors.black12),
                        
                        _row(context, "Customer", customerName, color: isDark ? Colors.white70 : Colors.black54),
                        const SizedBox(height: 12),
                        _row(context, "Bill Ref", billId.substring(0, 8).toUpperCase(), color: isDark ? Colors.white70 : Colors.black54),
                        const SizedBox(height: 12),
                        _row(
                          context,
                          isHistoryView ? "Total Paid" : "Amount Paid", 
                          "Rs. ${amountPaid.toStringAsFixed(2)}", 
                          isBold: true, 
                          color: Colors.green
                        ),
                        
                        Divider(height: 32, color: isDark ? Colors.white12 : Colors.black12),
                        
                        _row(context, "Remaining Due", "Rs. ${remainingDue.toStringAsFixed(2)}", color: Colors.redAccent),
                        
                        if (user?.invoiceFooterMessage != null) ...[
                          const SizedBox(height: 32),
                          Text(user!.invoiceFooterMessage!, textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, color: isDark ? Colors.white38 : Colors.grey)),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _printPdf(context, user),
                    icon: const Icon(Icons.print),
                    label: const Text("PRINT RECEIPT"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                      foregroundColor: isDark ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _sharePdf(context, user),
                          icon: const Icon(Icons.share),
                          label: const Text("PDF"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                            foregroundColor: Colors.blueAccent
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareSms(context, user),
                          icon: const Icon(Icons.message),
                          label: const Text("SMS"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                            foregroundColor: Colors.orange
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
           ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool isBold = false, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.black54)),
        Text(value, style: TextStyle(
          fontSize: 16, 
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? (isDark ? Colors.white : Colors.black)
        )),
      ],
    );
  }

  Future<void> _printPdf(BuildContext context, UserModel? user) async {
    final pdf = await _generatePdf(user);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _sharePdf(BuildContext context, UserModel? user) async {
    final pdf = await _generatePdf(user);
    await Printing.sharePdf(
      bytes: await pdf.save(), 
      filename: 'receipt_${billId.substring(0,6)}.pdf'
    );
  }

  Future<void> _shareSms(BuildContext context, UserModel? user) async {
     final sb = StringBuffer();
     sb.writeln("*${user?.shopName ?? "POS Podda"}*");
     if (user?.shopAddress != null) sb.writeln(user!.shopAddress!);
     sb.writeln("----------------");
     sb.writeln(isHistoryView ? "BILL STATEMENT" : "PAYMENT RECEIPT");
     sb.writeln("Date: ${DateFormat("yyyy-MM-dd HH:mm").format(timestamp)}");
     sb.writeln("----------------");
     sb.writeln("Customer: $customerName");
     sb.writeln("Bill Ref: ${billId.substring(0, 8).toUpperCase()}");
     sb.writeln("Paid: Rs. ${amountPaid.toStringAsFixed(2)}");
     sb.writeln("Remaining: Rs. ${remainingDue.toStringAsFixed(2)}");
     sb.writeln("----------------");
     if (user?.invoiceFooterMessage != null) sb.writeln(user!.invoiceFooterMessage!);
     
     final text = Uri.encodeComponent(sb.toString());
     final url = "sms:?body=$text";
     
     try {
       if (await canLaunchUrlString(url)) {
         await launchUrlString(url);
       } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot launch SMS"), backgroundColor: Colors.red));
       }
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
     }
  }

  Future<pw.Document> _generatePdf(UserModel? user) async {
    final pdf = pw.Document();
    
    // Attempt to load logo if available
    pw.ImageProvider? logoImage;
    if (user?.shopLogo != null && user!.shopLogo!.isNotEmpty) {
      try {
        logoImage = await networkImage(user.shopLogo!);
      } catch (e) {
        debugPrint("Failed to load logo: $e");
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, 
        // roll80 is standard 80mm thermal paper
        // Margin adjusted for thermal printer
        margin: const pw.EdgeInsets.all(10), 
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // --- HEADER ---
              if (logoImage != null)
                 pw.Container(height: 50, child: pw.Image(logoImage)),
              
              pw.SizedBox(height: 10),
              pw.Text(user?.shopName ?? "POS Podda", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
              if (user?.shopAddress != null)
                 pw.Text(user!.shopAddress!, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
              if (user?.shopMobile != null)
                 pw.Text("Tel: ${user!.shopMobile}", style: const pw.TextStyle(fontSize: 10)),
              
              pw.Divider(), 

              // --- SUB HEADER ---
              pw.Text(isHistoryView ? "BILL STATEMENT" : "PAYMENT RECEIPT", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text("Date: ${DateFormat("yyyy-MM-dd HH:mm").format(timestamp)}", style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 10),
              
              // --- BODY ---
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("Customer:", style: const pw.TextStyle(fontSize: 10)),
                pw.Text(customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ]),
              pw.SizedBox(height: 5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("Bill Ref:", style: const pw.TextStyle(fontSize: 10)),
                pw.Text(billId.substring(0, 6), style: const pw.TextStyle(fontSize: 10)),
              ]),
              pw.Divider(thickness: 0.5),

              pw.SizedBox(height: 10),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("Total Due Before:", style: const pw.TextStyle(fontSize: 10)),
                pw.Text("${previousDue.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10)),
              ]),
              pw.SizedBox(height: 5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("PAID AMOUNT:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.Text("Rs. ${amountPaid.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              ]),
              pw.SizedBox(height: 5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("Remaining Balance:", style: const pw.TextStyle(fontSize: 10)),
                pw.Text("${remainingDue.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10)),
              ]),
              
              pw.Divider(),

              // --- FOOTER ---
              pw.SizedBox(height: 10),
              pw.Text(user?.invoiceFooterMessage ?? "Thank You!", textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
              if (user?.invoiceContactInfo != null)
                 pw.Text(user!.invoiceContactInfo!, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
                 
              pw.SizedBox(height: 20),
              pw.Text("Powered by POS Podda", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          );
        },
      ),
    );
    return pdf;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/reports/sale_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';



class ReceiptScreen extends ConsumerWidget {
  final Sale sale;

  const ReceiptScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch user profile for Shop Details
    final user = ref.watch(userProfileProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: Text("Transaction Complete", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, shape: BoxShape.circle),
              child: Icon(Icons.close, color: isDark ? Colors.white : Colors.black)
            ),
            onPressed: () => Navigator.pop(context)
          ),
          const SizedBox(width: 8)
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2), 
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 5)]
                        ),
                        child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 50),
                      ),
                      const SizedBox(height: 16),
                      const Center(child: Text("PAYMENT SUCCESSFUL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green))),
                      const SizedBox(height: 32),
                      
                      Text("Total Paid", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54), textAlign: TextAlign.center),
                      Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(DateFormat('dd MMM yyyy, hh:mm a').format(sale.timestamp), textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                      if (sale.paymentMethod == 'CREDIT' && sale.customerId != null)
                         Padding(
                           padding: const EdgeInsets.only(top: 8),
                           child: const Text("Added to Credit (Potha)", textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                         ),
                      
                      const SizedBox(height: 32),
                      Divider(color: isDark ? Colors.white12 : Colors.black12),
                      
                      // Shop Info Preview
                       if (user != null) ...[
                         Text(user.shopName ?? "POS Podda", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                         if (user.shopAddress != null) Text(user.shopAddress!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                         const SizedBox(height: 16),
                       ],

                      Text("Items Purchased", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                      const SizedBox(height: 16),
                      
                      // Items List UI
                      ...sale.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text("${item.quantity} x ${item.productName}", style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87))),
                                Text(item.subTotal.toStringAsFixed(2), style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                              ],
                            ),
                            if (item.description != null && item.description!.isNotEmpty)
                               Padding(
                                 padding: const EdgeInsets.only(left: 16),
                                 child: Text(item.description!, style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: isDark ? Colors.white54 : Colors.black45)),
                               )
                          ],
                        ),
                      )),
                      
                      const SizedBox(height: 16),
                      Divider(color: isDark ? Colors.white12 : Colors.black12),
                      if (user?.invoiceFooterMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(user!.invoiceFooterMessage!, textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, color: isDark ? Colors.white38 : Colors.black45)),
                        )
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
                    label: const Text("PRINT", style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200, 
                      foregroundColor: isDark ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                      shadowColor: Colors.blueAccent.withValues(alpha: 0.5)
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _shareSms(context, user),
                  icon: const Icon(Icons.message), 
                  style: IconButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  tooltip: "SMS",
                ),
              ],
            ),
          ),
          // Close Big Button
           Padding(
             padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
             child: SizedBox(
               width: double.infinity,
               child: OutlinedButton(
                 onPressed: () => Navigator.pop(context),
                 style: OutlinedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   side: BorderSide(color: isDark ? Colors.cyanAccent.withValues(alpha: 0.5) : Colors.blue.withValues(alpha: 0.5)),
                   foregroundColor: isDark ? Colors.cyanAccent : Colors.blue
                 ),
                 child: const Text("START NEW SALE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
               ),
             ),
           )
        ],
      ),
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context, UserModel? user) async {
    final pdf = await _generatePdf(user);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  String _generateReceiptText(UserModel? user) {
    final sb = StringBuffer();
    sb.writeln("*${user?.shopName ?? "POS Podda Receipt"}*");
    if (user?.shopAddress != null) sb.writeln(user!.shopAddress!);
    sb.writeln("Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(sale.timestamp)}");
    sb.writeln("----------------");
    for (var item in sale.items) {
      sb.writeln("${item.productName} x ${item.quantity} = ${item.subTotal}");
      if (item.description != null && item.description!.isNotEmpty) {
        sb.writeln("  (${item.description})");
      }
    }
    sb.writeln("----------------");
    sb.writeln("*TOTAL: Rs. ${sale.totalAmount}*");
    if (user?.invoiceFooterMessage != null) sb.writeln("\n${user!.invoiceFooterMessage}");
    return sb.toString();
  }

  Future<void> _sharePdf(BuildContext context, UserModel? user) async {
    final pdf = await _generatePdf(user);
    await Printing.sharePdf(
      bytes: await pdf.save(), 
      filename: 'receipt_${sale.timestamp.millisecondsSinceEpoch}.pdf'
    );
  }

  Future<void> _shareSms(BuildContext context, UserModel? user) async {
    final text = Uri.encodeComponent(_generateReceiptText(user));
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
    
    pw.ImageProvider? logoImage;
    if (user?.shopLogo != null && user!.shopLogo!.isNotEmpty) {
      try {
        logoImage = await networkImage(user.shopLogo!);
      } catch (e) { print("Logo Error: $e"); }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10), // Small margins for roll
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
               // --- HEADER ---
               if (logoImage != null)
                 pw.Center(child: pw.Image(logoImage, width: 50, height: 50)),
                 
               pw.Center(child: pw.Text(user?.shopName ?? "POS Podda Store", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18), textAlign: pw.TextAlign.center)),
               
               if (user?.shopAddress != null)
                 pw.Center(child: pw.Text(user!.shopAddress!, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),
                 
               if (user?.shopMobile != null)
                 pw.Center(child: pw.Text("Tel: ${user!.shopMobile}", style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),

               pw.SizedBox(height: 5),
               pw.Center(child: pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(sale.timestamp), style: const pw.TextStyle(fontSize: 10))),
               pw.Divider(thickness: 0.5),
               
               // --- ITEMS ---
               ...sale.items.map((item) => pw.Container(
                 margin: const pw.EdgeInsets.symmetric(vertical: 2),
                 child: pw.Column(
                   crossAxisAlignment: pw.CrossAxisAlignment.start,
                   children: [
                     pw.Row(
                       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                       crossAxisAlignment: pw.CrossAxisAlignment.start,
                       children: [
                         pw.Expanded(child: pw.Text("${item.quantity} x ${item.productName}", style: const pw.TextStyle(fontSize: 10))),
                         pw.Text(item.subTotal.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                       ]
                     ),
                     if (item.description != null && item.description!.isNotEmpty)
                       pw.Padding(
                         padding: const pw.EdgeInsets.only(left: 10),
                         child: pw.Text(item.description!, style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                       )
                   ]
                 )
               )),
               
               pw.Divider(thickness: 0.5),
               
               // --- TOTALS ---
               pw.Row(
                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                 children: [
                   pw.Text("TOTAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                   pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                 ]
               ),
               
               // Payment Method Info
               pw.SizedBox(height: 4),
               pw.Row(
                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                 children: [
                   pw.Text("Payment Method:", style: const pw.TextStyle(fontSize: 8)),
                   pw.Text(sale.paymentMethod, style: const pw.TextStyle(fontSize: 8)),
                 ]
               ),
               
               if (sale.paymentMethod == 'CREDIT')
                 pw.Center(child: pw.Text("(CREDIT SALE - UNPAID)", style: const pw.TextStyle(fontSize: 8))),
                 
               pw.SizedBox(height: 10),
               
               // --- FOOTER ---
               if (user?.invoiceFooterMessage != null)
                 pw.Center(child: pw.Text(user!.invoiceFooterMessage!, style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic), textAlign: pw.TextAlign.center)),
                 
               if (user?.invoiceContactInfo != null) ...[
                 pw.SizedBox(height: 4),
                 pw.Center(child: pw.Text(user!.invoiceContactInfo!, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
               ],
               
               pw.SizedBox(height: 10),
               pw.Center(child: pw.Text("Powered strictly by POS Podda", style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey))),
            ],
          );
        },
      ),
    );
    return pdf;
  }
}

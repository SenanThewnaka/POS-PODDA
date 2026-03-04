import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sme_buddy/features/reports/sale_model.dart';
import 'package:cross_file/cross_file.dart';

class CsvExporter {
  static Future<void> exportSales(List<Sale> sales) async {
    final List<List<dynamic>> rows = [];
    
    // Headers
    rows.add([
      "Date",
      "Time",
      "Total Amount",
      "Payment Method",
      "Customer ID",
      "Status",
      "Items Purchased"
    ]);

    for (var sale in sales) {
      final dateStr = DateFormat('yyyy-MM-dd').format(sale.timestamp);
      final timeStr = DateFormat('HH:mm').format(sale.timestamp);
      final statusStr = sale.isFullyPaid ? "Paid" : "Unpaid (${sale.amountPaid} Paid)";
      final itemsStr = sale.items.map((i) => "${i.quantity}x ${i.productName}").join(", ");

      rows.add([
        dateStr,
        timeStr,
        sale.totalAmount,
        sale.paymentMethod,
        sale.customerId ?? "Walk-in",
        statusStr,
        itemsStr
      ]);
    }

    final csvData = rows.map((row) => row.map((item) {
      final str = item.toString().replaceAll('"', '""');
      return '"$str"';
    }).join(",")).join("\n");
    final bytes = utf8.encode(csvData);

    // XFile handles Web downloads automatically in share_plus!
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes), 
      mimeType: 'text/csv', 
      name: 'sales_report_${DateTime.now().millisecondsSinceEpoch}.csv'
    );

    // Provide bounds for iPad share sheet
    await Share.shareXFiles([xFile], text: 'Sales Report CSV');
  }
}

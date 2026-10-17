import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';

/// Supported physical sticker label layouts and roll dimensions
enum BarcodeLabelFormat {
  thermal50x30, // 50mm x 30mm standard retail sticker roll (Xprinter, Zebra, TSC)
  thermal40x30, // 40mm x 30mm compact retail sticker
  roll58,       // 58mm continuous thermal receipt paper / label roll
  roll80,       // 80mm continuous thermal receipt paper / label roll
  a4Grid30,     // A4 Sheet: 3 columns x 10 rows (30 stickers per sheet)
  a4Grid24,     // A4 Sheet: 3 columns x 8 rows (24 stickers per sheet)
}

extension BarcodeLabelFormatExtension on BarcodeLabelFormat {
  String get displayName {
    switch (this) {
      case BarcodeLabelFormat.thermal50x30:
        return '50 × 30 mm Thermal Sticker';
      case BarcodeLabelFormat.thermal40x30:
        return '40 × 30 mm Mini Sticker';
      case BarcodeLabelFormat.roll58:
        return '58 mm Thermal Roll';
      case BarcodeLabelFormat.roll80:
        return '80 mm Thermal Roll';
      case BarcodeLabelFormat.a4Grid30:
        return 'A4 Sheet (30 Labels - 3×10)';
      case BarcodeLabelFormat.a4Grid24:
        return 'A4 Sheet (24 Labels - 3×8)';
    }
  }

  String get description {
    switch (this) {
      case BarcodeLabelFormat.thermal50x30:
        return 'Standard desktop barcode printer (Xprinter, Rongta, Zebra)';
      case BarcodeLabelFormat.thermal40x30:
        return 'Small items (stationery, hardware screws, cosmetics)';
      case BarcodeLabelFormat.roll58:
        return 'Continuous 58mm thermal receipt roll with cut lines';
      case BarcodeLabelFormat.roll80:
        return 'Continuous 80mm thermal receipt roll with cut lines';
      case BarcodeLabelFormat.a4Grid30:
        return 'Regular office laser/inkjet printer on A4 sticker sheets';
      case BarcodeLabelFormat.a4Grid24:
        return 'Regular office laser/inkjet printer on A4 sticker sheets';
    }
  }

  bool get isSheet =>
      this == BarcodeLabelFormat.a4Grid30 || this == BarcodeLabelFormat.a4Grid24;

  bool get isContinuousRoll =>
      this == BarcodeLabelFormat.roll58 || this == BarcodeLabelFormat.roll80;
}

/// Customization options for sticker label design
class BarcodeLabelConfig {
  final BarcodeLabelFormat format;
  final bool showStoreName;
  final String? storeName;
  final bool showProductName;
  final bool showPrice;
  final bool showBarcodeText;
  final bool showDate;
  final String? customDate;
  final String currencySymbol;
  final String? customSubtitle;

  const BarcodeLabelConfig({
    this.format = BarcodeLabelFormat.thermal50x30,
    this.showStoreName = true,
    this.storeName,
    this.showProductName = true,
    this.showPrice = true,
    this.showBarcodeText = true,
    this.showDate = false,
    this.customDate,
    this.currencySymbol = 'Rs. ',
    this.customSubtitle,
  });

  BarcodeLabelConfig copyWith({
    BarcodeLabelFormat? format,
    bool? showStoreName,
    String? storeName,
    bool? showProductName,
    bool? showPrice,
    bool? showBarcodeText,
    bool? showDate,
    String? customDate,
    String? currencySymbol,
    String? customSubtitle,
  }) {
    return BarcodeLabelConfig(
      format: format ?? this.format,
      showStoreName: showStoreName ?? this.showStoreName,
      storeName: storeName ?? this.storeName,
      showProductName: showProductName ?? this.showProductName,
      showPrice: showPrice ?? this.showPrice,
      showBarcodeText: showBarcodeText ?? this.showBarcodeText,
      showDate: showDate ?? this.showDate,
      customDate: customDate ?? this.customDate,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      customSubtitle: customSubtitle ?? this.customSubtitle,
    );
  }
}

/// An item queued to have barcode stickers printed
class BarcodeLabelItem {
  final String productId;
  final String productName;
  final String barcode;
  final double price;
  final String? unitText;
  final int quantity;
  final Product? product;

  const BarcodeLabelItem({
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.price,
    this.unitText,
    this.quantity = 1,
    this.product,
  });

  factory BarcodeLabelItem.fromProduct(Product product, {int quantity = 1}) {
    String? unit;
    double displayPrice = product.sellingPrice;
    if (product.stockType == 'weight' && product.baseUnit == 'g') {
      displayPrice = product.sellingPrice * 1000;
      unit = '/kg';
    } else if (product.stockType == 'weight' && product.baseUnit == 'ml') {
      displayPrice = product.sellingPrice * 1000;
      unit = '/L';
    } else if (product.baseUnit != null && product.baseUnit != 'unit') {
      unit = '/${product.baseUnit}';
    }

    return BarcodeLabelItem(
      productId: product.id,
      productName: product.name,
      barcode: product.barcode ?? '',
      price: displayPrice,
      unitText: unit,
      quantity: quantity,
      product: product,
    );
  }

  BarcodeLabelItem copyWith({
    String? productId,
    String? productName,
    String? barcode,
    double? price,
    String? unitText,
    int? quantity,
    Product? product,
  }) {
    return BarcodeLabelItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      unitText: unitText ?? this.unitText,
      quantity: quantity ?? this.quantity,
      product: product ?? this.product,
    );
  }
}

class BarcodeStickerService {
  /// Generates a PDF Document containing the barcode stickers according to the config.
  static Future<pw.Document> generatePdf({
    required List<BarcodeLabelItem> items,
    required BarcodeLabelConfig config,
  }) async {
    final pdf = pw.Document();

    // Prepare font theme with Sinhala fallback
    pw.ThemeData? theme;
    try {
      final baseFont = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      final sinhalaFont = await PdfGoogleFonts.notoSansSinhalaRegular();
      final sinhalaBold = await PdfGoogleFonts.notoSansSinhalaBold();
      theme = pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        fontFallback: [sinhalaFont, sinhalaBold],
      );
    } catch (e) {
      debugPrint("Barcode font fallback note: $e");
    }

    // Flatten items according to quantity
    final flattenedLabels = <BarcodeLabelItem>[];
    for (final item in items) {
      if (item.barcode.isEmpty) continue;
      for (int i = 0; i < item.quantity; i++) {
        flattenedLabels.add(item);
      }
    }

    if (flattenedLabels.isEmpty) {
      // Empty document fallback
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          theme: theme,
          build: (ctx) => pw.Center(child: pw.Text("No labels to print")),
        ),
      );
      return pdf;
    }

    switch (config.format) {
      case BarcodeLabelFormat.thermal50x30:
        _buildThermalSinglePages(
          pdf: pdf,
          labels: flattenedLabels,
          config: config,
          theme: theme,
          widthMm: 50,
          heightMm: 30,
        );
        break;

      case BarcodeLabelFormat.thermal40x30:
        _buildThermalSinglePages(
          pdf: pdf,
          labels: flattenedLabels,
          config: config,
          theme: theme,
          widthMm: 40,
          heightMm: 30,
        );
        break;

      case BarcodeLabelFormat.roll58:
        _buildContinuousRollPages(
          pdf: pdf,
          labels: flattenedLabels,
          config: config,
          theme: theme,
          pageFormat: PdfPageFormat.roll57,
          itemHeightMm: 36,
        );
        break;

      case BarcodeLabelFormat.roll80:
        _buildContinuousRollPages(
          pdf: pdf,
          labels: flattenedLabels,
          config: config,
          theme: theme,
          pageFormat: PdfPageFormat.roll80,
          itemHeightMm: 40,
        );
        break;

      case BarcodeLabelFormat.a4Grid30:
        _buildA4GridPages(
          pdf: pdf,
          labels: flattenedLabels,
          config: config,
          theme: theme,
          columns: 3,
          rows: 10,
        );
        break;

      case BarcodeLabelFormat.a4Grid24:
        _buildA4GridPages(
          pdf: pdf,
          labels: flattenedLabels,
          config: config,
          theme: theme,
          columns: 3,
          rows: 8,
        );
        break;
    }

    return pdf;
  }

  /// Builds individual pages for dedicated thermal label printers (e.g. 50x30mm)
  static void _buildThermalSinglePages({
    required pw.Document pdf,
    required List<BarcodeLabelItem> labels,
    required BarcodeLabelConfig config,
    required pw.ThemeData? theme,
    required double widthMm,
    required double heightMm,
  }) {
    final pageFormat = PdfPageFormat(
      widthMm * PdfPageFormat.mm,
      heightMm * PdfPageFormat.mm,
      marginAll: 1.5 * PdfPageFormat.mm,
    );

    for (final label in labels) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          theme: theme,
          build: (context) {
            return _buildSingleLabelWidget(
              label: label,
              config: config,
              maxWidth: (widthMm - 3) * PdfPageFormat.mm,
              maxHeight: (heightMm - 3) * PdfPageFormat.mm,
              compact: widthMm <= 40,
            );
          },
        ),
      );
    }
  }

  /// Builds continuous thermal receipt paper roll pages with tear lines
  static void _buildContinuousRollPages({
    required pw.Document pdf,
    required List<BarcodeLabelItem> labels,
    required BarcodeLabelConfig config,
    required pw.ThemeData? theme,
    required PdfPageFormat pageFormat,
    required double itemHeightMm,
  }) {
    // 10 labels per page chunk to avoid unmanageably long single rolls in viewer
    const int labelsPerPage = 8;
    for (int i = 0; i < labels.length; i += labelsPerPage) {
      final chunk = labels.sublist(
        i,
        (i + labelsPerPage < labels.length) ? i + labelsPerPage : labels.length,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          theme: theme,
          margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          build: (context) {
            return pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: chunk.map((label) {
                return pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 4),
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.grey400,
                      width: 0.5,
                      style: pw.BorderStyle.dashed,
                    ),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: _buildSingleLabelWidget(
                    label: label,
                    config: config,
                    maxWidth: pageFormat.availableWidth,
                    maxHeight: itemHeightMm * PdfPageFormat.mm,
                    compact: pageFormat.width < 60 * PdfPageFormat.mm,
                  ),
                );
              }).toList(),
            );
          },
        ),
      );
    }
  }

  /// Builds A4 Sheet Grid pages (e.g. 3x10 or 3x8 sticky label sheets)
  static void _buildA4GridPages({
    required pw.Document pdf,
    required List<BarcodeLabelItem> labels,
    required BarcodeLabelConfig config,
    required pw.ThemeData? theme,
    required int columns,
    required int rows,
  }) {
    final itemsPerPage = columns * rows;
    final totalPages = (labels.length / itemsPerPage).ceil();

    final a4Format = PdfPageFormat.a4;
    final double marginHorizontal = 6 * PdfPageFormat.mm;
    final double marginVertical = 8 * PdfPageFormat.mm;
    final double availableWidth = a4Format.width - (marginHorizontal * 2);
    final double availableHeight = a4Format.height - (marginVertical * 2);
    final double cellWidth = availableWidth / columns;
    final double cellHeight = availableHeight / rows;

    for (int pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final startIdx = pageIdx * itemsPerPage;
      final endIdx = (startIdx + itemsPerPage < labels.length)
          ? startIdx + itemsPerPage
          : labels.length;
      final pageLabels = labels.sublist(startIdx, endIdx);

      pdf.addPage(
        pw.Page(
          pageFormat: a4Format,
          theme: theme,
          margin: pw.EdgeInsets.symmetric(
            horizontal: marginHorizontal,
            vertical: marginVertical,
          ),
          build: (context) {
            return pw.GridView(
              crossAxisCount: columns,
              childAspectRatio: cellWidth / cellHeight,
              children: List.generate(itemsPerPage, (index) {
                if (index < pageLabels.length) {
                  final label = pageLabels[index];
                  return pw.Container(
                    margin: const pw.EdgeInsets.all(1.5),
                    padding: const pw.EdgeInsets.all(3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: _buildSingleLabelWidget(
                      label: label,
                      config: config,
                      maxWidth: cellWidth - 5,
                      maxHeight: cellHeight - 5,
                      compact: false,
                    ),
                  );
                } else {
                  // Empty placeholder cell with faint outline
                  return pw.Container(
                    margin: const pw.EdgeInsets.all(1.5),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey200,
                        width: 0.25,
                      ),
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                  );
                }
              }),
            );
          },
        ),
      );
    }
  }

  /// Internal widget representing a single formatted sticker
  static pw.Widget _buildSingleLabelWidget({
    required BarcodeLabelItem label,
    required BarcodeLabelConfig config,
    required double maxWidth,
    required double maxHeight,
    required bool compact,
  }) {
    final titleFontSize = compact ? 7.5 : 8.5;
    final storeFontSize = compact ? 5.5 : 6.5;
    final priceFontSize = compact ? 8.5 : 10.0;
    final barcodeHeight = compact ? 18.0 : 24.0;
    final dateFontSize = compact ? 5.0 : 6.0;

    String dateStr = config.customDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Store Name Header (optional)
        if (config.showStoreName && config.storeName != null && config.storeName!.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 1),
            child: pw.Text(
              config.storeName!.toUpperCase(),
              style: pw.TextStyle(
                fontSize: storeFontSize,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
              maxLines: 1,
              textAlign: pw.TextAlign.center,
            ),
          ),

        // Product Name
        if (config.showProductName)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2),
            child: pw.Text(
              label.productName,
              style: pw.TextStyle(
                fontSize: titleFontSize,
                fontWeight: pw.FontWeight.bold,
              ),
              maxLines: 2,
              textAlign: pw.TextAlign.center,
              overflow: pw.TextOverflow.clip,
            ),
          ),

        pw.SizedBox(height: 1.5),

        // Barcode Graphic
        pw.Expanded(
          child: pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: label.barcode,
              drawText: config.showBarcodeText,
              textStyle: pw.TextStyle(fontSize: compact ? 6.0 : 7.0),
              height: barcodeHeight,
              width: maxWidth * 0.9,
            ),
          ),
        ),

        pw.SizedBox(height: 1.5),

        // Bottom Bar: Price & optional packed date
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (config.showPrice) ...[
              pw.Text(
                "${config.currencySymbol}${label.price.toStringAsFixed(2)}${label.unitText != null ? ' ${label.unitText}' : ''}",
                style: pw.TextStyle(
                  fontSize: priceFontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
            if (config.showDate) ...[
              if (config.showPrice) pw.SizedBox(width: 4),
              pw.Text(
                "• Pkd: $dateStr",
                style: pw.TextStyle(
                  fontSize: dateFontSize,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterSettings {
  final String paperSize; // '80mm' or '58mm'
  final bool autoPrint;
  final bool directPrint;
  final String? selectedPrinterUrl;
  final String? selectedPrinterName;

  const PrinterSettings({
    this.paperSize = '80mm',
    this.autoPrint = false,
    this.directPrint = false,
    this.selectedPrinterUrl,
    this.selectedPrinterName,
  });

  PdfPageFormat get pageFormat =>
      paperSize == '58mm' ? PdfPageFormat.roll57 : PdfPageFormat.roll80;

  PrinterSettings copyWith({
    String? paperSize,
    bool? autoPrint,
    bool? directPrint,
    String? selectedPrinterUrl,
    String? selectedPrinterName,
  }) {
    return PrinterSettings(
      paperSize: paperSize ?? this.paperSize,
      autoPrint: autoPrint ?? this.autoPrint,
      directPrint: directPrint ?? this.directPrint,
      selectedPrinterUrl: selectedPrinterUrl ?? this.selectedPrinterUrl,
      selectedPrinterName: selectedPrinterName ?? this.selectedPrinterName,
    );
  }
}

class PrinterSettingsNotifier extends StateNotifier<PrinterSettings> {
  static const _keyPaperSize = 'pos_printer_paper_size';
  static const _keyAutoPrint = 'pos_printer_auto_print';
  static const _keyDirectPrint = 'pos_printer_direct_print';
  static const _keyPrinterUrl = 'pos_printer_url';
  static const _keyPrinterName = 'pos_printer_name';

  PrinterSettingsNotifier() : super(const PrinterSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = PrinterSettings(
        paperSize: prefs.getString(_keyPaperSize) ?? '80mm',
        autoPrint: prefs.getBool(_keyAutoPrint) ?? false,
        directPrint: prefs.getBool(_keyDirectPrint) ?? false,
        selectedPrinterUrl: prefs.getString(_keyPrinterUrl),
        selectedPrinterName: prefs.getString(_keyPrinterName),
      );
    } catch (e) {
      debugPrint('Error loading printer settings: $e');
    }
  }

  Future<void> setPaperSize(String size) async {
    state = state.copyWith(paperSize: size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaperSize, size);
  }

  Future<void> setAutoPrint(bool autoPrint) async {
    state = state.copyWith(autoPrint: autoPrint);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPrint, autoPrint);
  }

  Future<void> setDirectPrint(bool directPrint) async {
    state = state.copyWith(directPrint: directPrint);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDirectPrint, directPrint);
  }

  Future<void> setSelectedPrinter(Printer? printer) async {
    state = state.copyWith(
      selectedPrinterUrl: printer?.url,
      selectedPrinterName: printer?.name,
    );
    final prefs = await SharedPreferences.getInstance();
    if (printer != null) {
      await prefs.setString(_keyPrinterUrl, printer.url);
      await prefs.setString(_keyPrinterName, printer.name);
    } else {
      await prefs.remove(_keyPrinterUrl);
      await prefs.remove(_keyPrinterName);
    }
  }

  /// Prints a given PDF document according to the active settings.
  /// Uses directPrint to the selected printer if configured, otherwise falls back to layoutPdf dialog.
  Future<bool> printDocument({
    required pw.Document doc,
    String name = 'Receipt',
  }) async {
    final bytes = await doc.save();

    if (state.directPrint && state.selectedPrinterUrl != null) {
      try {
        final printers = await Printing.listPrinters();
        final matched = printers.firstWhere(
          (p) => p.url == state.selectedPrinterUrl,
          orElse: () => printers.firstWhere(
            (p) => p.name == state.selectedPrinterName,
            orElse: () => printers.first,
          ),
        );

        return await Printing.directPrintPdf(
          printer: matched,
          onLayout: (format) async => bytes,
          name: name,
        );
      } catch (e) {
        debugPrint('Direct printing failed, falling back to layoutPdf: $e');
      }
    }

    // Fallback or default: OS print dialog / preview
    return await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: name,
      format: state.pageFormat,
    );
  }
}

final printerSettingsProvider =
    StateNotifierProvider<PrinterSettingsNotifier, PrinterSettings>((ref) {
  return PrinterSettingsNotifier();
});

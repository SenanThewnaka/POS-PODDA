import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sme_buddy/features/settings/printer_settings_service.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  List<Printer> _printers = [];
  bool _isLoadingPrinters = false;

  @override
  void initState() {
    super.initState();
    _refreshPrinters();
  }

  Future<void> _refreshPrinters() async {
    setState(() => _isLoadingPrinters = true);
    try {
      final list = await Printing.listPrinters();
      if (mounted) {
        setState(() {
          _printers = list;
          _isLoadingPrinters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPrinters = false);
      }
    }
  }

  Future<void> _printTestReceipt() async {
    final settings = ref.read(printerSettingsProvider);
    final user = ref.read(userProfileProvider).value;

    final doc = pw.Document();
    final is58 = settings.paperSize == '58mm';
    final fontSizeTitle = is58 ? 13.0 : 16.0;
    final fontSizeBody = is58 ? 8.5 : 10.0;

    doc.addPage(
      pw.Page(
        pageFormat: settings.pageFormat,
        margin: pw.EdgeInsets.all(is58 ? 4 : 8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                user?.shopName ?? "POS PODDA TEST",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: fontSizeTitle,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                "*** HARDWARE TEST RECEIPT ***",
                style: pw.TextStyle(
                  fontSize: fontSizeBody,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                style: pw.TextStyle(fontSize: fontSizeBody - 1),
              ),
              pw.Text(
                "Paper Width: ${settings.paperSize}",
                style: pw.TextStyle(fontSize: fontSizeBody - 1),
              ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("ITEM", style: pw.TextStyle(fontSize: fontSizeBody, fontWeight: pw.FontWeight.bold)),
                  pw.Text("PRICE", style: pw.TextStyle(fontSize: fontSizeBody, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("1 x Demo Hardware Test", style: pw.TextStyle(fontSize: fontSizeBody)),
                  pw.Text("Rs. 100.00", style: pw.TextStyle(fontSize: fontSizeBody)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL", style: pw.TextStyle(fontSize: fontSizeBody + 1, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Rs. 100.00", style: pw.TextStyle(fontSize: fontSizeBody + 1, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.BarcodeWidget(
                  data: 'POS-PODDA-TEST',
                  barcode: pw.Barcode.code128(),
                  width: is58 ? 120 : 150,
                  height: 30,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                "Thermal Printer Configured Successfully!",
                style: pw.TextStyle(fontSize: fontSizeBody - 1, fontStyle: pw.FontStyle.italic),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    final success = await ref
        .read(printerSettingsProvider.notifier)
        .printDocument(doc: doc, name: 'Test_Receipt');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Test print sent!" : "Print cancelled or unavailable"),
          backgroundColor: success ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(printerSettingsProvider);
    final notifier = ref.read(printerSettingsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      appBar: AppBar(
        title: const Text("Printer & Hardware", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Scan for Printers",
            onPressed: _refreshPrinters,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // SECTION 1: Paper Roll Format
              _buildSectionHeader("Thermal Paper Roll Width"),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPaperOption(
                      title: "80mm Roll",
                      subtitle: "Standard Retail / Restaurant (3-inch)",
                      isSelected: settings.paperSize == '80mm',
                      onTap: () => notifier.setPaperSize('80mm'),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPaperOption(
                      title: "58mm Roll",
                      subtitle: "Compact Desktop / Bluetooth (2-inch)",
                      isSelected: settings.paperSize == '58mm',
                      onTap: () => notifier.setPaperSize('58mm'),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // SECTION 2: Automation & Direct Printing
              _buildSectionHeader("Printing Automation"),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SwitchListTile(
                  title: Text(
                    "Auto-Print on Checkout",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    "Immediately print receipt as soon as a sale is completed",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  secondary: const Icon(Icons.flash_on, color: Colors.amberAccent),
                  value: settings.autoPrint,
                  activeColor: Colors.cyanAccent,
                  onChanged: (val) => notifier.setAutoPrint(val),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SwitchListTile(
                  title: Text(
                    "Direct Printing (Bypass OS Dialog)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    "Send directly to the selected printer without opening system preview",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  secondary: const Icon(Icons.print_outlined, color: Colors.cyanAccent),
                  value: settings.directPrint,
                  activeColor: Colors.cyanAccent,
                  onChanged: (val) => notifier.setDirectPrint(val),
                ),
              ),
              const SizedBox(height: 24),

              // SECTION 3: Device Selection
              _buildSectionHeader("Connected Printers"),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Select Default Printer",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        if (_isLoadingPrinters)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Text(
                            "${_printers.length} found",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.cyanAccent : Colors.blueAccent,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_printers.isEmpty && !_isLoadingPrinters)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          "No printers found. Ensure your USB/Bluetooth/Network printer is powered on and connected to this device.",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      )
                    else
                      ..._printers.map((printer) {
                        final isSelected = settings.selectedPrinterUrl == printer.url ||
                            (settings.selectedPrinterUrl == null &&
                                settings.selectedPrinterName == printer.name);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.cyanAccent
                                  : (isDark ? Colors.white12 : Colors.black12),
                              width: isSelected ? 1.5 : 1,
                            ),
                            color: isSelected
                                ? Colors.cyanAccent.withValues(alpha: 0.1)
                                : Colors.transparent,
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.print,
                              color: isSelected ? Colors.cyanAccent : Colors.grey,
                            ),
                            title: Text(
                              printer.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              printer.url,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Colors.cyanAccent)
                                : null,
                            onTap: () => notifier.setSelectedPrinter(printer),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // TEST PRINT BUTTON
              ElevatedButton.icon(
                onPressed: _printTestReceipt,
                icon: const Icon(Icons.receipt_long),
                label: const Text(
                  "PRINT TEST RECEIPT",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.cyanAccent,
      ),
    );
  }

  Widget _buildPaperOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
        border: Border.all(
          color: isSelected ? Colors.cyanAccent : (isDark ? Colors.white12 : Colors.black12),
          width: isSelected ? 2 : 1,
        ),
        color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.12) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? Colors.cyanAccent : Colors.grey,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

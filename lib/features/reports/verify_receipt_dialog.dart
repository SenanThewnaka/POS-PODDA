import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/reports/receipt_screen.dart';
import 'package:sme_buddy/features/reports/sale_model.dart';
import 'package:sme_buddy/features/reports/sales_repository.dart';

class VerifyReceiptDialog extends ConsumerStatefulWidget {
  final String? initialBillId;

  const VerifyReceiptDialog({super.key, this.initialBillId});

  static Future<void> show(BuildContext context, {String? initialBillId}) {
    return showDialog(
      context: context,
      builder: (_) => VerifyReceiptDialog(initialBillId: initialBillId),
    );
  }

  @override
  ConsumerState<VerifyReceiptDialog> createState() => _VerifyReceiptDialogState();
}

class _VerifyReceiptDialogState extends ConsumerState<VerifyReceiptDialog> {
  late final TextEditingController _idController;
  bool _isLoading = false;
  Sale? _verifiedSale;
  bool _hasSearched = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.initialBillId ?? '');
    if (widget.initialBillId != null && widget.initialBillId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyBill(widget.initialBillId!);
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _verifyBill(String rawId) async {
    final cleanId = rawId.trim();
    if (cleanId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _verifiedSale = null;
      _hasSearched = true;
    });

    try {
      final sale = await ref.read(salesRepositoryProvider).getSaleById(cleanId);
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (sale != null) {
            _verifiedSale = sale;
            _errorMessage = null;
          } else {
            _errorMessage = "Receipt ID '$cleanId' not found. It may be invalid or from another store.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error verifying receipt: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = screenSize.width > 650 ? 600.0 : screenSize.width * 0.92;
    final dialogHeight = (screenSize.height * 0.82).clamp(420.0, 720.0);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_outlined, color: Colors.cyanAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Verify Bill / Receipt",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Scan receipt barcode or enter Bill ID to verify legitimacy",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search / Scan Input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _idController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Scan barcode or enter Bill ID...",
                        prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.cyanAccent),
                        suffixIcon: _idController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _idController.clear();
                                  setState(() {
                                    _hasSearched = false;
                                    _verifiedSale = null;
                                    _errorMessage = null;
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: _verifyBill,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(80, 48),
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : () => _verifyBill(_idController.text),
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text("Verify", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Results Area
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _verifiedSale != null
                        ? _buildVerifiedResult(context, _verifiedSale!, isDark)
                        : _hasSearched && _errorMessage != null
                            ? _buildErrorResult(_errorMessage!, isDark)
                            : _buildEmptyPrompt(isDark),
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPrompt(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.document_scanner_outlined, size: 56, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            "Scan Receipt Barcode",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Use any USB or Bluetooth barcode scanner to scan the printed barcode at the bottom of the customer's receipt, or type the Bill ID above.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorResult(String error, bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            const Text(
              "VERIFICATION FAILED",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedResult(BuildContext context, Sale sale, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          // Authenticated Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "LEGITIMATE RECEIPT VERIFIED",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(sale.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Body (Bill Summary + Items)
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bill Summary
                  Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Bill #: ${sale.id}",
                                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              if (sale.userName != null)
                                Text(
                                  "Cashier: ${sale.userName}",
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                                ),
                              Text(
                                "Payment: ${sale.paymentMethod}${sale.paymentMethod == 'CASH' ? ' (Tender: Rs. ${sale.cashTendered.toStringAsFixed(0)} | Change: Rs. ${sale.changeDue.toStringAsFixed(0)})' : ''}",
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Rs. ${sale.totalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.greenAccent),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Items title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Purchased Items (${sale.items.length})",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const Text(
                          "Check for Returns",
                          style: TextStyle(fontSize: 11, color: Colors.cyanAccent),
                        ),
                      ],
                    ),
                  ),

                  // Items list
                  ...sale.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${item.quantity.toInt()}x",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                Text(
                                  "Unit Price: Rs. ${item.unitPrice.toStringAsFixed(2)}",
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "Rs. ${item.subTotal.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Action Buttons: View Receipt / Open
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text("Open Receipt & Reprint"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ReceiptScreen(sale: sale)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

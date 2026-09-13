import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/shifts/shift_repository.dart';
import 'package:sme_buddy/utils/glass_card.dart';

class CashDrawerActionDialog extends ConsumerStatefulWidget {
  final String initialType; // 'IN' or 'OUT'

  const CashDrawerActionDialog({super.key, this.initialType = 'OUT'});

  static Future<bool?> show(BuildContext context, {String initialType = 'OUT'}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => CashDrawerActionDialog(initialType: initialType),
    );
  }

  @override
  ConsumerState<CashDrawerActionDialog> createState() =>
      _CashDrawerActionDialogState();
}

class _CashDrawerActionDialogState
    extends ConsumerState<CashDrawerActionDialog> {
  late String _type;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _isLoading = false;

  final List<String> _cashOutReasons = [
    "Supplier Payout",
    "Petty Cash Expense",
    "Staff Tea / Lunch",
    "Mid-day Bank Drop",
    "Owner Cash Draw",
  ];

  final List<String> _cashInReasons = [
    "Change Top-up",
    "Owner Deposit",
    "Cash Float Addition",
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (_type == 'OUT') {
      _reasonCtrl.text = _cashOutReasons.first;
    } else {
      _reasonCtrl.text = _cashInReasons.first;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid amount"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a reason"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(shiftRepositoryProvider).addCashTransaction(
            type: _type,
            amount: amount,
            reason: reason,
          );
      HapticFeedback.mediumImpact();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${_type == 'IN' ? 'Cash In (+)' : 'Cash Payout (-)'}: Rs. ${amount.toStringAsFixed(2)} logged",
            ),
            backgroundColor: _type == 'IN' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCashIn = _type == 'IN';
    final activeColor = isCashIn ? Colors.greenAccent : Colors.orangeAccent;
    final currentReasons = isCashIn ? _cashInReasons : _cashOutReasons;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          border: Border.all(color: activeColor.withValues(alpha: 0.4), width: 1.5),
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
                      color: activeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCashIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      color: activeColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cash Drawer Payout / Inflow",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          "Record money entering or leaving the register",
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
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // IN / OUT Toggle
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _type = 'OUT';
                          _reasonCtrl.text = _cashOutReasons.first;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _type == 'OUT'
                              ? Colors.orangeAccent.withValues(alpha: 0.2)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _type == 'OUT' ? Colors.orangeAccent : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            "CASH OUT (PAYOUT)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _type = 'IN';
                          _reasonCtrl.text = _cashInReasons.first;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _type == 'IN'
                              ? Colors.greenAccent.withValues(alpha: 0.2)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _type == 'IN' ? Colors.greenAccent : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            "CASH IN (ADD)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Amount Field
              Text(
                "Amount (Rs.)",
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
                  controller: _amountCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    prefixText: "Rs. ",
                    prefixStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    border: InputBorder.none,
                    hintText: "0.00",
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Reason Chips
              Text(
                "Reason Category",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: currentReasons.map((reason) {
                  final isSelected = _reasonCtrl.text == reason;
                  return InkWell(
                    onTap: () => setState(() => _reasonCtrl.text = reason),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withValues(alpha: 0.2)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? activeColor : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        reason,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Custom Reason Input
              GlassCard(
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _reasonCtrl,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: const InputDecoration(
                    hintText: "Enter custom reason or memo...",
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
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
                    : Text(
                        "CONFIRM ${_type == 'IN' ? 'CASH IN' : 'CASH OUT'}",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

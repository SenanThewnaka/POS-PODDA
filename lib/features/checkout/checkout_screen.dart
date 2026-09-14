import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/home/cart_provider.dart';
import 'package:sme_buddy/features/credit/customer_model.dart';
import 'package:sme_buddy/features/credit/customer_repository.dart';
import 'package:sme_buddy/features/credit/customer_list_screen.dart';
import 'package:sme_buddy/features/reports/sales_repository.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/reports/receipt_screen.dart';
import 'package:sme_buddy/utils/analytics_service.dart';
import 'package:sme_buddy/utils/rating_service.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/responsive_layout.dart';
import 'package:sme_buddy/features/shifts/shift_repository.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _paymentMethod = 'CASH'; // CASH, CARD, CREDIT
  double _cashGiven = 0;
  Customer? _selectedCustomer;
  bool _isLoading = false;
  bool _hasInitializedCash = false;
  bool _hasCustomCashInput = false;

  final FocusNode _keyboardFocusNode = FocusNode();
  final FocusNode _customAmountFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _keyboardFocusNode.dispose();
    _customAmountFocusNode.dispose();
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (!mounted) return false;
    final total = ref.read(cartTotalProvider);
    return _handleKey(event, total);
  }

  bool _handleKey(KeyEvent event, double total) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    final isCustomAmountFocused = _customAmountFocusNode.hasFocus;

    if (key == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return true;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.f12) {
      _onCompletePressed(total);
      return true;
    }

    if (!isCustomAmountFocused) {
      // Payment method hotkeys: strictly F1, F2, F3
      if (key == LogicalKeyboardKey.f1) {
        _selectPaymentMethod('CASH', total);
        return true;
      } else if (key == LogicalKeyboardKey.f2) {
        _selectPaymentMethod('CARD', total);
        return true;
      } else if (key == LogicalKeyboardKey.f3) {
        _selectPaymentMethod('CREDIT', total);
        return true;
      }

      // Cash tender keyboard / numpad typing - numbers 0-9 and numpad 0-9
      final isDigitKey = key == LogicalKeyboardKey.digit0 ||
          key == LogicalKeyboardKey.numpad0 ||
          key == LogicalKeyboardKey.digit1 ||
          key == LogicalKeyboardKey.numpad1 ||
          key == LogicalKeyboardKey.digit2 ||
          key == LogicalKeyboardKey.numpad2 ||
          key == LogicalKeyboardKey.digit3 ||
          key == LogicalKeyboardKey.numpad3 ||
          key == LogicalKeyboardKey.digit4 ||
          key == LogicalKeyboardKey.numpad4 ||
          key == LogicalKeyboardKey.digit5 ||
          key == LogicalKeyboardKey.numpad5 ||
          key == LogicalKeyboardKey.digit6 ||
          key == LogicalKeyboardKey.numpad6 ||
          key == LogicalKeyboardKey.digit7 ||
          key == LogicalKeyboardKey.numpad7 ||
          key == LogicalKeyboardKey.digit8 ||
          key == LogicalKeyboardKey.numpad8 ||
          key == LogicalKeyboardKey.digit9 ||
          key == LogicalKeyboardKey.numpad9 ||
          key == LogicalKeyboardKey.period ||
          key == LogicalKeyboardKey.numpadDecimal ||
          key == LogicalKeyboardKey.comma ||
          key == LogicalKeyboardKey.backspace ||
          key == LogicalKeyboardKey.delete;

      if (isDigitKey) {
        if (_paymentMethod != 'CASH') {
          setState(() {
            _paymentMethod = 'CASH';
            _cashGiven = 0;
            _hasCustomCashInput = true;
          });
        }

        if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
          _onNumpadDigit('0', total);
        } else if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
          _onNumpadDigit('1', total);
        } else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
          _onNumpadDigit('2', total);
        } else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
          _onNumpadDigit('3', total);
        } else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
          _onNumpadDigit('4', total);
        } else if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
          _onNumpadDigit('5', total);
        } else if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
          _onNumpadDigit('6', total);
        } else if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
          _onNumpadDigit('7', total);
        } else if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
          _onNumpadDigit('8', total);
        } else if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
          _onNumpadDigit('9', total);
        } else if (key == LogicalKeyboardKey.period || key == LogicalKeyboardKey.numpadDecimal || key == LogicalKeyboardKey.comma) {
          _onNumpadDigit('.', total);
        } else if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
          _onNumpadDigit('BACK', total);
        }
        return true;
      } else if (key == LogicalKeyboardKey.keyC) {
        if (_paymentMethod == 'CASH') {
          _onNumpadDigit('CLEAR', total);
          return true;
        }
      }
    }
    return false;
  }

  void _selectPaymentMethod(String label, double total) {
    setState(() {
      _paymentMethod = label;
      _cashGiven = label == 'CASH' ? total : 0;
      _selectedCustomer = null;
      _hasCustomCashInput = false;
    });
    HapticFeedback.mediumImpact();
  }

  void _onCompletePressed(double total) {
    if (_isLoading) return;

    if (_paymentMethod == 'CREDIT' && _selectedCustomer == null) {
      _selectCustomer();
    } else if (_paymentMethod == 'CASH' && _cashGiven < total) {
      if (_cashGiven == 0) {
        // Cashier didn't input cash given; assume exact cash
        setState(() => _cashGiven = total);
        _processSale(total);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Insufficient Cash! Short by Rs. ${(total - _cashGiven).toStringAsFixed(2)}",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      _processSale(total);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = ref.watch(cartTotalProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktopOrTablet = context.isTabletOrDesktop;

    // Initialize cash given to total once when screen loads
    if (!_hasInitializedCash && total > 0) {
      _hasInitializedCash = true;
      if (_paymentMethod == 'CASH') {
        _cashGiven = total;
      }
    }

    return GlassScaffold(
        appBar: AppBar(
          title: const Text("Checkout", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          centerTitle: true,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Column(
              children: [
                // 1. Total Amount
                GlassCard(
                  margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  borderRadius: 24,
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5), width: 1.5),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        const Text(
                          "TOTAL TO PAY",
                          style: TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Rs. ${total.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 2. Payment Toggles
                        Row(
                          children: [
                            Expanded(
                              child: _buildPaymentToggle(
                                "CASH",
                                Icons.money,
                                Colors.greenAccent,
                                total,
                                hotkeyHint: "F1",
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildPaymentToggle(
                                "CARD",
                                Icons.credit_card,
                                Colors.blueAccent,
                                total,
                                hotkeyHint: "F2",
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildPaymentToggle(
                                "CREDIT",
                                Icons.person,
                                Colors.redAccent,
                                total,
                                hotkeyHint: "F3",
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // 3. Method Specific UI
                        if (_paymentMethod == 'CASH') ...[
                          // Quick Tender Chips (Exact & Common Notes)
                          Text(
                            "Quick Tender Notes:",
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                                label: Text(
                                  "Exact (Rs. ${total.toStringAsFixed(0)})",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                ),
                                backgroundColor: _cashGiven == total
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF1E293B),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _cashGiven = total;
                                    _hasCustomCashInput = true;
                                  });
                                },
                              ),
                              ...[500.0, 1000.0, 2000.0, 5000.0]
                                  .where((denom) => denom >= total || denom == 500.0)
                                  .map((denom) {
                                final isSelected = _cashGiven == denom;
                                return ActionChip(
                                  label: Text(
                                    "Rs. ${denom.toInt()}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  backgroundColor: isSelected
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF1E293B),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _cashGiven = denom;
                                      _hasCustomCashInput = true;
                                    });
                                  },
                                );
                              }),
                              ..._getQuickCashOptions(total).where((opt) => opt != total && opt != 500 && opt != 1000 && opt != 2000 && opt != 5000).map((opt) {
                                final isSelected = _cashGiven == opt;
                                return ActionChip(
                                  label: Text(
                                    "Rs. ${opt.toInt()}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  backgroundColor: isSelected
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF1E293B),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _cashGiven = opt;
                                      _hasCustomCashInput = true;
                                    });
                                  },
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Cash Received Display with Clear Button (Interactive Neumorphic Input)
                          MouseRegion(
                            cursor: SystemMouseCursors.text,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                _keyboardFocusNode.requestFocus();
                                setState(() {
                                  _hasCustomCashInput = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _keyboardFocusNode.hasFocus
                                        ? const Color(0xFF6366F1)
                                        : const Color(0xFF1E293B),
                                    width: _keyboardFocusNode.hasFocus ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _keyboardFocusNode.hasFocus
                                          ? const Color(0xFF6366F1).withOpacity(0.25)
                                          : Colors.black.withOpacity(0.5),
                                      offset: const Offset(1.5, 1.5),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Row(
                                              children: [
                                                Text(
                                                  "CASH TENDERED",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white.withOpacity(0.5),
                                                    letterSpacing: 1.1,
                                                  ),
                                                ),
                                                if (!_hasCustomCashInput) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF6366F1).withOpacity(0.25),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      "SELECTED",
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF818CF8),
                                                        letterSpacing: 0.8,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: !_hasCustomCashInput
                                                    ? const Color(0xFF6366F1).withOpacity(0.25)
                                                    : Colors.transparent,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: !_hasCustomCashInput ? 6 : 0,
                                              vertical: 1,
                                            ),
                                            child: Text(
                                              "Rs. ${_cashGiven.toStringAsFixed(2)}",
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_cashGiven > 0) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.backspace_outlined, color: Colors.white70),
                                      tooltip: "Clear / Backspace",
                                      onPressed: () => _onNumpadDigit('BACK', total),
                                    ),
                                  ],
                                ],
                              ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Touch NumPad Grid
                          _buildTouchNumpad(total),
                          const SizedBox(height: 16),

                          // Giant Change Due / Still Due Banner
                          if (_cashGiven >= total)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF064E3B).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "CHANGE DUE",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF6EE7B7),
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            "Rs. ${(_cashGiven - total).toStringAsFixed(2)}",
                                            style: const TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 36),
                                ],
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF78350F).withOpacity(0.35),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Amount Remaining:",
                                    style: TextStyle(color: Color(0xFFFCD34D), fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "Rs. ${(total - _cashGiven).toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ] else if (_paymentMethod == 'CREDIT') ...[
                          InkWell(
                            onTap: _selectCustomer,
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                              child: Row(
                                children: [
                                  const Icon(Icons.person, color: Colors.redAccent, size: 40),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _selectedCustomer == null
                                        ? Text(
                                            "Tap to Select Customer",
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                          )
                                        : Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _selectedCustomer!.name,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : Colors.black,
                                                ),
                                              ),
                                              Text(
                                                "Current Due: Rs. ${_selectedCustomer!.currentBalance}",
                                                style: const TextStyle(color: Colors.redAccent),
                                              ),
                                            ],
                                          ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, color: Colors.white54),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // 4. Complete Action Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _onCompletePressed(total),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _paymentMethod == 'CREDIT' ? Colors.redAccent : Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                            )
                          : Text(
                              _paymentMethod == 'CREDIT'
                                  ? (_selectedCustomer == null
                                      ? "SELECT CUSTOMER"
                                      : "ADD TO POTHA (CREDIT)${isDesktopOrTablet ? ' [Enter]' : ''}")
                                  : "COMPLETE SALE${isDesktopOrTablet ? ' [Enter]' : ''}",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),

                // Hotkey helper row on Desktop / Tablet
                if (isDesktopOrTablet)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildHotkeyTag("[F1] Cash"),
                          const SizedBox(width: 8),
                          _buildHotkeyTag("[F2] Card"),
                          const SizedBox(width: 8),
                          _buildHotkeyTag("[F3] Credit"),
                          const SizedBox(width: 8),
                          _buildHotkeyTag("[Enter] Pay"),
                          const SizedBox(width: 8),
                          _buildHotkeyTag("[Esc] Back"),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildHotkeyTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _onNumpadDigit(String digit, double total) {
    HapticFeedback.lightImpact();
    setState(() {
      if (!_hasCustomCashInput && digit != 'BACK' && digit != 'CLEAR') {
        _hasCustomCashInput = true;
        if (digit == '.') {
          _cashGiven = 0;
        } else if (digit == '00') {
          _cashGiven = 0;
          return;
        } else {
          _cashGiven = double.tryParse(digit) ?? 0;
          return;
        }
      }
      _hasCustomCashInput = true;

      String current = _cashGiven == 0
          ? ''
          : (_cashGiven % 1 == 0 ? _cashGiven.toInt().toString() : _cashGiven.toString());

      if (digit == 'CLEAR') {
        _cashGiven = 0;
      } else if (digit == 'BACK') {
        if (current.isNotEmpty) {
          current = current.substring(0, current.length - 1);
          _cashGiven = double.tryParse(current) ?? 0;
        } else {
          _cashGiven = 0;
        }
      } else if (digit == '.') {
        if (!current.contains('.')) {
          current = current.isEmpty ? '0.' : '$current.';
          _cashGiven = double.tryParse(current) ?? 0;
        }
      } else if (digit == '00') {
        if (current.isNotEmpty && current != '0') {
          current = '${current}00';
          _cashGiven = double.tryParse(current) ?? 0;
        }
      } else {
        current = '$current$digit';
        _cashGiven = double.tryParse(current) ?? 0;
      }
    });
  }

  Widget _buildTouchNumpad(double total) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            offset: const Offset(2, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildNumpadKey('1', () => _onNumpadDigit('1', total)),
              const SizedBox(width: 8),
              _buildNumpadKey('2', () => _onNumpadDigit('2', total)),
              const SizedBox(width: 8),
              _buildNumpadKey('3', () => _onNumpadDigit('3', total)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildNumpadKey('4', () => _onNumpadDigit('4', total)),
              const SizedBox(width: 8),
              _buildNumpadKey('5', () => _onNumpadDigit('5', total)),
              const SizedBox(width: 8),
              _buildNumpadKey('6', () => _onNumpadDigit('6', total)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildNumpadKey('7', () => _onNumpadDigit('7', total)),
              const SizedBox(width: 8),
              _buildNumpadKey('8', () => _onNumpadDigit('8', total)),
              const SizedBox(width: 8),
              _buildNumpadKey('9', () => _onNumpadDigit('9', total)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildNumpadKey('C', () => _onNumpadDigit('CLEAR', total), color: Colors.redAccent.withValues(alpha: 0.18), textColor: Colors.redAccent),
              const SizedBox(width: 8),
              _buildNumpadKey('0', () => _onNumpadDigit('0', total)),
              const SizedBox(width: 8),
              _buildNumpadKey('00', () => _onNumpadDigit('00', total)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadKey(String label, VoidCallback onTap, {Color? color, Color? textColor}) {
    return Expanded(
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color ?? const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF334155).withValues(alpha: 0.4),
              offset: const Offset(-2, -2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              offset: const Offset(2.5, 2.5),
              blurRadius: 5,
            ),
          ],
        ),
        child: Material(
          key: Key('numpad_$label'),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectCustomer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerListScreen(
          isSelectionMode: true,
          onSelect: (customer) {
            setState(() => _selectedCustomer = customer);
          },
        ),
      ),
    );
  }

  Widget _buildPaymentToggle(
    String label,
    IconData icon,
    Color color,
    double total, {
    String? hotkeyHint,
  }) {
    final isSelected = _paymentMethod == label;

    return GlassCard(
      onTap: () => _selectPaymentMethod(label, total),
      padding: const EdgeInsets.symmetric(vertical: 14),
      borderRadius: 12,
      color: isSelected ? color.withValues(alpha: 0.2) : null,
      border: Border.all(
        color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
        width: isSelected ? 2 : 1,
      ),
      child: Column(
        children: [
          Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? color : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (hotkeyHint != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hotkeyHint,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? color : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<double> _getQuickCashOptions(double total) {
    if (total <= 0) return [];
    List<double> options = [];
    if (total < 500) options.add(500);
    if (total < 1000) options.add(1000);
    if (total < 2000) options.add(2000);
    if (total < 5000) options.add(5000);

    double next500 = ((total / 500).ceil() * 500).toDouble();
    if (!options.contains(next500) && next500 > total) options.add(next500);

    double next1000 = ((total / 1000).ceil() * 1000).toDouble();
    if (!options.contains(next1000) && next1000 > total) options.add(next1000);

    return options..sort();
  }

  void _processSale(double total) async {
    setState(() => _isLoading = true);

    try {
      if (_paymentMethod == 'CREDIT' && _selectedCustomer != null) {
        await ref.read(customerRepositoryProvider).updateBalance(_selectedCustomer!.id, total);
      }

      final cart = ref.read(cartProvider);

      final sale = await ref.read(salesRepositoryProvider).recordSale(
            total,
            _paymentMethod,
            _paymentMethod == 'CREDIT' ? _selectedCustomer?.id : null,
            cart,
          );

      // Record in active shift if one is open
      ref.read(shiftRepositoryProvider).recordSaleInActiveShift(
            amount: total,
            paymentMethod: _paymentMethod,
          );

      final stockUpdates = cart.values
          .map((item) => BatchSaleItem(
                productId: item.product.id,
                quantity: item.quantity,
                soldPrice: item.effectivePrice,
              ))
          .toList();
      await ref.read(productRepositoryProvider).processSale(stockUpdates);

      // Clear Cart
      ref.read(cartProvider.notifier).clearCart();

      HapticFeedback.heavyImpact();

      // Analytics
      AnalyticsService.logSaleCompleted(
        totalAmount: total,
        paymentMethod: _paymentMethod,
        itemCount: cart.length,
      );
      if (_paymentMethod == 'CREDIT') {
        AnalyticsService.logCreditSale(amount: total);
      }

      // Rating
      RatingService.onSaleCompleted();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ReceiptScreen(sale: sale)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}

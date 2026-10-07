import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sme_buddy/features/subscription/subscription_guard.dart';

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
import 'package:sme_buddy/features/home/held_bills_provider.dart';
import 'package:sme_buddy/utils/sound_service.dart';

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
    final cart = ref.watch(cartProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktopOrTablet = context.isTabletOrDesktop;
    final size = MediaQuery.of(context).size;
    final isWideDesktop = isDesktopOrTablet && size.width >= 900;

    // Initialize cash given to total once when screen loads
    if (!_hasInitializedCash && total > 0) {
      _hasInitializedCash = true;
      if (_paymentMethod == 'CASH') {
        _cashGiven = total;
      }
    }

    if (isWideDesktop) {
      return GlassScaffold(
        appBar: AppBar(
          title: const Text("Checkout", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          centerTitle: true,
          actions: [
            TextButton.icon(
              onPressed: () => _holdOrder(context, total),
              icon: const Icon(Icons.pause_circle_outline, color: Colors.amber, size: 20),
              label: const Text(
                "Hold",
                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Panel: Total Card + Order Items Details (flex: 5)
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildTotalCard(total, isDark),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _buildOrderSummaryList(cart, total, isDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right Panel: Payment Modes, Numpad & Action (flex: 7)
                  Expanded(
                    flex: 7,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPaymentMethodsRow(total),
                          const SizedBox(height: 16),
                          _buildMethodSpecificUI(total, isDark),
                          const SizedBox(height: 16),
                          _buildCompleteButton(total, isDesktopOrTablet),
                          const SizedBox(height: 12),
                          _buildHotkeysRow(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Single centered column layout (Mobile and Tablet Portrait)
    return GlassScaffold(
      appBar: AppBar(
        title: const Text("Checkout", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () => _holdOrder(context, total),
            icon: const Icon(Icons.pause_circle_outline, color: Colors.amber, size: 20),
            label: const Text(
              "Hold",
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            children: [
              _buildTotalCard(total, isDark),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPaymentMethodsRow(total),
                      const SizedBox(height: 20),
                      _buildMethodSpecificUI(total, isDark),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _buildCompleteButton(total, isDesktopOrTablet),
              ),
              if (isDesktopOrTablet)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _buildHotkeysRow(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard(double total, bool isDark) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      borderRadius: 20,
      border: Border.all(
        color: (isDark ? Colors.cyanAccent : const Color(0xFF0284C7)).withValues(alpha: 0.5),
        width: 1.5,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Text(
              "TOTAL TO PAY",
              style: TextStyle(
                color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Rs. ${total.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryList(Map<String, CartItem> cart, double total, bool isDark) {
    final totalUnits = cart.values.fold<double>(0, (sum, i) => sum + i.quantity);
    final hasDecimalUnits = cart.values.any((i) => i.quantity % 1 != 0);

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      border: Border.all(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "ORDER ITEMS (${cart.length})",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${totalUnits.toStringAsFixed(hasDecimalUnits ? 2 : 0)} Units",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              itemCount: cart.length,
              separatorBuilder: (_, __) => Divider(
                height: 10,
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
              ),
              itemBuilder: (context, index) {
                final item = cart.values.elementAt(index);
                final product = item.product;
                final isDiscounted = item.effectivePrice < product.sellingPrice;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                "${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} × Rs. ${item.effectivePrice.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                ),
                              ),
                              if (isDiscounted) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "Save Rs. ${(product.sellingPrice - item.effectivePrice).toStringAsFixed(0)}",
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Rs. ${item.subTotal.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Subtotal",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              Text(
                "Rs. ${total.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsRow(double total) {
    return Row(
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
    );
  }

  Widget _buildMethodSpecificUI(double total, bool isDark) {
    if (_paymentMethod == 'CASH') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick Tender 1-Tap Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Quick Tender (1-Tap):",
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_cashGiven != total && _cashGiven > 0)
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _cashGiven = total;
                      _hasCustomCashInput = true;
                    });
                  },
                  icon: Icon(Icons.refresh, size: 14, color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7)),
                  label: Text("Reset to Exact", style: TextStyle(fontSize: 12, color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7))),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 1. Exact Total Button (prominent emerald)
              ActionChip(
                avatar: Icon(
                  _cashGiven == total ? Icons.check_circle : Icons.flash_on,
                  size: 16,
                  color: _cashGiven == total ? Colors.black : const Color(0xFF10B981),
                ),
                label: Text(
                  "Exact (Rs. ${total.toStringAsFixed(total % 1 == 0 ? 0 : 2)})",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _cashGiven == total
                        ? Colors.black
                        : (isDark ? Colors.white : const Color(0xFF065F46)),
                    fontSize: 13,
                  ),
                ),
                backgroundColor: _cashGiven == total
                    ? const Color(0xFF10B981)
                    : (isDark
                        ? const Color(0xFF10B981).withValues(alpha: 0.18)
                        : const Color(0xFFD1FAE5)),
                side: BorderSide(
                  color: _cashGiven == total
                      ? const Color(0xFF10B981)
                      : (isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.5)
                          : const Color(0xFF34D399)),
                  width: 1.2,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _cashGiven = total;
                    _hasCustomCashInput = true;
                  });
                },
              ),

              // 2. Quick Note Options (>= total)
              ..._getQuickCashOptions(total).map((denom) {
                final isSelected = (_cashGiven == denom);
                return ActionChip(
                  avatar: Icon(
                    Icons.payments_outlined,
                    size: 15,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.indigoAccent : const Color(0xFF4F46E5)),
                  ),
                  label: Text(
                    "Rs. ${denom.toInt()}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: isSelected
                      ? const Color(0xFF6366F1)
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFDFE4EA)),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF818CF8)
                        : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _cashGiven = denom;
                      _hasCustomCashInput = true;
                    });
                  },
                );
              }),

              // 3. Quick Note Additions (+Rs. 100, +Rs. 500, +Rs. 1,000)
              ...[100.0, 500.0, 1000.0].map((increment) {
                return ActionChip(
                  avatar: Icon(
                    Icons.add,
                    size: 14,
                    color: isDark ? Colors.cyanAccent : const Color(0xFF4F46E5),
                  ),
                  label: Text(
                    "${increment.toInt()}",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.cyanAccent : const Color(0xFF4F46E5),
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: isDark
                      ? Colors.cyanAccent.withValues(alpha: 0.1)
                      : const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  side: BorderSide(
                    color: isDark
                        ? Colors.cyanAccent.withValues(alpha: 0.3)
                        : const Color(0xFF4F46E5).withValues(alpha: 0.3),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _cashGiven = (_cashGiven > 0 ? _cashGiven : total) + increment;
                      _hasCustomCashInput = true;
                    });
                  },
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // Cash Received Display with Clear Button (Interactive Input)
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
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _keyboardFocusNode.hasFocus
                        ? const Color(0xFF6366F1)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                    width: _keyboardFocusNode.hasFocus ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _keyboardFocusNode.hasFocus
                          ? const Color(0xFF6366F1).withOpacity(0.25)
                          : (isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.08)),
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
                                    color: isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B),
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
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                        icon: Icon(Icons.backspace_outlined, color: isDark ? Colors.white70 : const Color(0xFF475569)),
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

          // Change Due / Still Due Banner
          if (_cashGiven >= total)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B).withOpacity(0.5) : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "CHANGE DUE",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Rs. ${(_cashGiven - total).toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF10B981) : const Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.check_circle,
                    color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                    size: 36,
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF78350F).withOpacity(0.35) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFFF59E0B).withOpacity(0.5) : const Color(0xFFD97706),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Amount Remaining:",
                    style: TextStyle(
                      color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Rs. ${(total - _cashGiven).toStringAsFixed(2)}",
                    style: TextStyle(
                      color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    } else if (_paymentMethod == 'CARD') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.blueAccent.withValues(alpha: 0.3) : const Color(0xFF3B82F6).withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.blueAccent.withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.credit_card_rounded,
                size: 40,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "Card / POS Terminal Tender",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Charge Rs. ${total.toStringAsFixed(2)} on POS terminal or EDC machine, then tap Complete Sale.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    } else if (_paymentMethod == 'CREDIT') {
      return InkWell(
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
              Icon(
                Icons.arrow_forward_ios,
                color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                size: 16,
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCompleteButton(double total, bool isDesktopOrTablet) {
    return SizedBox(
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
    );
  }

  Widget _buildHotkeysRow() {
    return SingleChildScrollView(
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
    );
  }

  Widget _buildHotkeyTag(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white60 : const Color(0xFF475569),
          fontWeight: FontWeight.w600,
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.06),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFDFE4EA);
    final defaultTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final defaultBorder = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1);

    return Expanded(
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color ?? defaultBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: defaultBorder,
            width: 1,
          ),
          boxShadow: isDark
              ? [
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
                ]
              : [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.9),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: const Color(0xFFA3B1C2).withValues(alpha: 0.5),
                    offset: const Offset(2.5, 2.5),
                    blurRadius: 4,
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
                  color: textColor ?? defaultTextColor,
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

  void _selectCustomer() async {
    if (!await SubscriptionGuard.check(context, ref, SubscriptionAction.accessCreditBook)) {
      return;
    }

    if (!mounted) return;

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

  void _holdOrder(BuildContext context, double total) async {
    final noteController = TextEditingController();
    final nameController = TextEditingController(text: _selectedCustomer?.name ?? '');

    final shouldHold = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
        final subtextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
        final hintColor = isDark ? Colors.white60 : const Color(0xFF94A3B8);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.pause_circle_filled, color: Colors.amber),
              const SizedBox(width: 8),
              Text("Hold Current Order", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Park this order so you can serve other customers. You can resume it anytime from the register.",
                style: TextStyle(color: subtextColor, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Customer Name (optional)",
                  labelStyle: TextStyle(color: hintColor),
                  prefixIcon: Icon(Icons.person_outline, color: hintColor),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Note (e.g. Counter 2, customer went to car)",
                  labelStyle: TextStyle(color: hintColor),
                  prefixIcon: Icon(Icons.notes, color: hintColor),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Hold Order", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (shouldHold == true && mounted) {
      final cart = ref.read(cartProvider);
      final heldBill = await ref.read(heldBillsProvider.notifier).holdCurrentCart(
        items: cart,
        totalAmount: total,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        customerName: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
      );
      ref.read(cartProvider.notifier).clearCart();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order held as ${heldBill.id}. You can resume it anytime."),
            backgroundColor: Colors.amber.shade800,
          ),
        );
      }
    }
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
    if (total <= 0) return [500, 1000, 2000, 5000];
    final Set<double> options = {};

    // 1. Next round-up steps if not an exact round number
    if (total < 500) {
      final next50 = (total / 50).ceil() * 50.0;
      if (next50 > total) options.add(next50);
      final next100 = (total / 100).ceil() * 100.0;
      if (next100 > total) options.add(next100);
    } else if (total < 2000) {
      final next100 = (total / 100).ceil() * 100.0;
      if (next100 > total) options.add(next100);
      final next500 = (total / 500).ceil() * 500.0;
      if (next500 > total) options.add(next500);
    } else {
      final next500 = (total / 500).ceil() * 500.0;
      if (next500 > total) options.add(next500);
      final next1000 = (total / 1000).ceil() * 1000.0;
      if (next1000 > total) options.add(next1000);
    }

    // 2. Standard circulating banknotes covering the bill
    for (final note in [500.0, 1000.0, 2000.0, 5000.0]) {
      if (note >= total) {
        options.add(note);
      }
    }

    // 3. For very large bills (> 5000)
    if (total > 5000) {
      final next5k = (total / 5000).ceil() * 5000.0;
      if (next5k > total) options.add(next5k);
      final next10k = (total / 10000).ceil() * 10000.0;
      if (next10k >= total) options.add(next10k);
    }

    // Exact total has its own dedicated button
    options.remove(total);

    final list = options.toList()..sort();
    return list;
  }

  void _processSale(double total) async {
    setState(() => _isLoading = true);

    try {
      // NOTE: Customer balance is updated atomically inside recordSale's transaction.
      // Do NOT call updateBalance separately — it caused a desync (overdue shows but no record).
      final cart = ref.read(cartProvider);

      final sale = await ref.read(salesRepositoryProvider).recordSale(
            total,
            _paymentMethod,
            _paymentMethod == 'CREDIT' ? _selectedCustomer?.id : null,
            cart,
            amountTendered: _paymentMethod == 'CASH' ? _cashGiven : null,
          );

      // Record in active shift if one is open
      try {
        await ref.read(shiftRepositoryProvider).recordSaleInActiveShift(
              amount: total,
              paymentMethod: _paymentMethod,
            );
      } catch (e) {
        if (kDebugMode) print('Shift recording note: $e');
      }

      try {
        final stockUpdates = cart.values
            .map((item) => BatchSaleItem(
                  productId: item.product.id,
                  quantity: item.quantity,
                  soldPrice: item.effectivePrice,
                ))
            .toList();
        await ref.read(productRepositoryProvider).processSale(stockUpdates);
      } catch (e) {
        if (kDebugMode) print('Stock update note: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sale recorded, but inventory sync failed. Please check stock."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Clear Cart
      ref.read(cartProvider.notifier).clearCart();

      HapticFeedback.heavyImpact();
      SoundService.playScanSuccess();

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

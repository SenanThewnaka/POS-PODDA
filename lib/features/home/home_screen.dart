import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/home/cart_provider.dart'; // import cart provider
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/checkout/checkout_screen.dart';
import 'package:sme_buddy/features/inventory/inventory_screen.dart';
import 'package:sme_buddy/features/credit/customer_list_screen.dart';
import 'package:sme_buddy/features/reports/reports_screen.dart';
import 'package:sme_buddy/features/inventory/simple_scanner_screen.dart'; // Keep for Add Product
import 'package:sme_buddy/features/inventory/pos_scanner_screen.dart'; // New POS Scanner
import 'package:sme_buddy/features/home/product_search_delegate.dart';
import 'package:sme_buddy/features/inventory/product_details_sheet.dart';
import 'package:sme_buddy/features/home/add_to_cart_sheet.dart';
import 'package:sme_buddy/features/inventory/product_dashboard_screen.dart';
import 'package:sme_buddy/features/home/edit_cart_item_sheet.dart';
import 'package:sme_buddy/utils/unit_formatter.dart';
import 'dart:async'; // For Timer hiding
import 'package:flutter/services.dart'; // For KeyboardListener
import 'package:sme_buddy/features/settings/settings_screen.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/features/inventory/batch_price_selection_dialog.dart';
import 'dart:ui';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/text_controller_extensions.dart';
import 'package:sme_buddy/utils/responsive_layout.dart';
import 'package:sme_buddy/utils/shimmer_skeletons.dart';
import 'package:sme_buddy/features/shifts/shift_model.dart';
import 'package:sme_buddy/features/shifts/shift_repository.dart';
import 'package:sme_buddy/features/shifts/open_shift_dialog.dart';
import 'package:sme_buddy/features/shifts/cash_drawer_action_dialog.dart';
import 'package:sme_buddy/features/shifts/close_shift_dialog.dart';
import 'package:sme_buddy/features/shifts/shift_history_screen.dart';
import 'package:sme_buddy/features/procurement/grn_history_screen.dart';
import 'package:sme_buddy/features/procurement/suppliers_screen.dart';
import 'package:sme_buddy/features/home/held_bills_provider.dart';
import 'package:sme_buddy/features/home/held_bills_dialog.dart';
import 'package:sme_buddy/features/reports/verify_receipt_dialog.dart';
import 'package:sme_buddy/features/reports/sales_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedFilter = 'All'; // 'All', 'Unit', 'Measurable', 'Service'
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  
  // Barcode Scanner Logic
  final StringBuffer _barcodeBuffer = StringBuffer();
  Timer? _barcodeBufferTimer;
  final FocusNode _keyboardFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (!mounted) return false;
    if (_searchFocusNode.hasFocus) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;

    _handleKey(event);
    return false;
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;
    final char = event.character;

    // 1. Function Key: F1 -> Focus search bar and select all
    if (key == LogicalKeyboardKey.f1) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return;
    }

    // 2. Escape -> Clear search and return focus to register
    if (key == LogicalKeyboardKey.escape) {
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        setState(() => _searchQuery = '');
      }
      _searchFocusNode.unfocus();
      _keyboardFocusNode.requestFocus();
      return;
    }

    // 3. Function Key: F2 -> Prompt Clear Cart
    if (key == LogicalKeyboardKey.f2) {
      _promptClearCart();
      return;
    }

    // 4. Function Key: F12 or Ctrl+Enter / Cmd+Enter -> Proceed to Checkout
    if (key == LogicalKeyboardKey.f12 ||
        ((HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed) &&
            key == LogicalKeyboardKey.enter)) {
      final cart = ref.read(cartProvider);
      if (cart.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CheckoutScreen()),
        );
      }
      return;
    }

    // 5. If search textfield does not have focus, handle scanner buffer
    if (!_searchFocusNode.hasFocus) {
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        if (_barcodeBuffer.isNotEmpty) {
          final barcode = _barcodeBuffer.toString();
          _barcodeBuffer.clear();
          _processBarcode(barcode);
        } else {
          // If buffer is empty and cart has items, Enter opens Checkout
          final cart = ref.read(cartProvider);
          if (cart.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutScreen()),
            );
          }
        }
      } else if (char != null && char.isNotEmpty && !HardwareKeyboard.instance.isControlPressed) {
        _barcodeBuffer.write(char);
        _barcodeBufferTimer?.cancel();
        _barcodeBufferTimer = Timer(const Duration(milliseconds: 500), () {
          _barcodeBuffer.clear();
        });
      }
    }
  }

  void _promptClearCart() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Clear Current Order?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to remove all items from the current cart?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel [Esc]", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("Clear Cart [Enter]"),
          ),
        ],
      ),
    );
  }

  Future<void> _processBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    final product = await ref.read(productRepositoryProvider).getProductByBarcode(cleanBarcode);

    if (!mounted) return;

    if (product != null) {
      if (product.isActive) {
        final bool needsCustomInput = product.stockType != 'unit' || product.isVariablePrice;

        bool hasMultiplePrices = false;
        try {
          final batches = await ref.read(productRepositoryProvider).getPosBatches(product.id);
          final uniquePrices = batches.map((b) => b.sellingPrice).toSet();
          if (uniquePrices.length > 1) {
            hasMultiplePrices = true;
          }
        } catch (_) {}

        if (needsCustomInput || hasMultiplePrices) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddToCartSheet(product: product),
          );
        } else {
          // Fast counter scanning: directly add or increment in cart
          ref.read(cartProvider.notifier).addToCart(product, quantity: 1);
          HapticFeedback.mediumImpact();

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Added: ${product.name} (Rs. ${product.sellingPrice.toStringAsFixed(2)})",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              duration: const Duration(milliseconds: 900),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        _showError("Product is inactive");
      }
    } else {
      // Check if this barcode is a Receipt / Sale ID
      try {
        final sale = await ref.read(salesRepositoryProvider).getSaleById(cleanBarcode);
        if (sale != null && mounted) {
          VerifyReceiptDialog.show(context, initialBillId: cleanBarcode);
          return;
        }
      } catch (_) {}
      _showError("Product not found: $cleanBarcode");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _promptHoldCart(double total) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final noteController = TextEditingController();
    final nameController = TextEditingController();

    final shouldHold = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.pause_circle_filled, color: Colors.amber),
            SizedBox(width: 8),
            Text("Hold Current Order", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Park this order so you can serve other customers. You can resume it anytime.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Customer Name (optional)",
                labelStyle: TextStyle(color: Colors.white60),
                prefixIcon: Icon(Icons.person_outline, color: Colors.white60),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Note (e.g. Counter 2, customer went to car)",
                labelStyle: TextStyle(color: Colors.white60),
                prefixIcon: Icon(Icons.notes, color: Colors.white60),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
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
      ),
    );

    if (shouldHold == true && mounted) {
      final heldBill = await ref.read(heldBillsProvider.notifier).holdCurrentCart(
        items: cart,
        totalAmount: total,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        customerName: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
      );
      ref.read(cartProvider.notifier).clearCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order held as ${heldBill.id}. You can resume it anytime."),
            backgroundColor: Colors.amber.shade800,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _barcodeBufferTimer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch cart
    final cartTotal = ref.watch(cartTotalProvider);
    final cart = ref.watch(cartProvider);

    final userProfile = ref.watch(userProfileProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isDesktopOrTablet = context.isTabletOrDesktop;

    final catalogContent = Column(
      children: [
        _buildTopBar(isDark, isDesktopOrTablet),
        _buildFilterBar(),
        Expanded(child: _buildProductGrid(ref)),
      ],
    );

    return Focus(
      autofocus: true,
      focusNode: _keyboardFocusNode,
      child: GlassScaffold(
        drawer: _buildDrawer(context, userProfile),
        body: isDesktopOrTablet
            ? Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: catalogContent),
                        _buildDesktopCartPane(context, ref, cartTotal, cart, isDark),
                      ],
                    ),
                  ),
                  _buildDesktopHotkeyStrip(isDark),
                ],
              )
            : Column(
                children: [
                  Expanded(child: catalogContent),
                  if (cart.isNotEmpty)
                    _buildCartBar(context, cartTotal, cart.length),
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark, bool isDesktopOrTablet) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Builder(
            builder: (scaffoldContext) => GlassCard(
              borderRadius: 16,
              width: 52,
              height: 52,
              padding: EdgeInsets.zero,
              onTap: () => Scaffold.of(scaffoldContext).openDrawer(),
              child: const Center(
                child: Tooltip(
                  message: "Navigation Menu (ERP, Inventory, Reports)",
                  child: Icon(Icons.menu_rounded, size: 24, color: Colors.cyanAccent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GlassCard(
              borderRadius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 52,
              child: Center(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocusNode,
                  textAlignVertical: TextAlignVertical.center,
                  onTap: () => _searchCtrl.selectAll(),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      _processBarcode(val.trim());
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    }
                  },
                  decoration: InputDecoration(
                    hintText: isDesktopOrTablet
                        ? "Search items by name or scan barcode... [F1]"
                        : "Search items by name or barcode...",
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent, size: 22),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            color: isDark ? Colors.white60 : Colors.black54,
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GlassCard(
            borderRadius: 16,
            width: 52,
            height: 52,
            padding: EdgeInsets.zero,
            onTap: () async {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const POSScannerScreen()));
            },
            child: const Center(
              child: Icon(Icons.qr_code_scanner, size: 26, color: Colors.cyanAccent),
            ),
          ),
          // Verify Bill Button
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: GlassCard(
              borderRadius: 16,
              width: 52,
              height: 52,
              padding: EdgeInsets.zero,
              onTap: () => VerifyReceiptDialog.show(context),
              child: const Center(
                child: Tooltip(
                  message: "Verify Bill / Returns",
                  child: Icon(Icons.verified_outlined, size: 24, color: Colors.cyanAccent),
                ),
              ),
            ),
          ),
          // Held Orders Pill Button
          Consumer(
            builder: (context, ref, child) {
              final heldBills = ref.watch(heldBillsProvider);
              if (heldBills.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 10),
                child: GlassCard(
                  borderRadius: 16,
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.7), width: 1.5),
                  onTap: () => HeldBillsDialog.show(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pause_circle_filled, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${heldBills.length}",
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (isDesktopOrTablet) ...[
                        const SizedBox(width: 6),
                        const Text(
                          "HELD",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              final shiftAsync = ref.watch(currentShiftProvider);
              final shift = shiftAsync.valueOrNull;

              if (shift == null) {
                return Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: GlassCard(
                    borderRadius: 16,
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                    onTap: () => OpenShiftDialog.show(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_open_rounded, color: Colors.amberAccent, size: 20),
                        if (isDesktopOrTablet) ...[
                          const SizedBox(width: 8),
                          const Text(
                            "OPEN SHIFT",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(left: 10),
                child: PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'cash_action') {
                      CashDrawerActionDialog.show(context);
                    } else if (val == 'close_shift') {
                      CloseShiftDialog.show(context, shift);
                    } else if (val == 'history') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ShiftHistoryScreen()),
                      );
                    }
                  },
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'cash_action',
                      child: Row(
                        children: const [
                          Icon(Icons.swap_vert, color: Colors.cyanAccent, size: 20),
                          SizedBox(width: 10),
                          Text("Cash In / Payout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'close_shift',
                      child: Row(
                        children: const [
                          Icon(Icons.lock_clock, color: Colors.redAccent, size: 20),
                          SizedBox(width: 10),
                          Text("Close Shift & Z-Report", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'history',
                      child: Row(
                        children: const [
                          Icon(Icons.history, color: Colors.amberAccent, size: 20),
                          SizedBox(width: 10),
                          Text("Shift History & Z-Reports", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                  child: GlassCard(
                    borderRadius: 16,
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "DRAWER CASH",
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                            ),
                            Text(
                              "Rs. ${shift.expectedCash.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 18, color: isDark ? Colors.white54 : Colors.black54),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHotkeyStrip(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHotkeyBadge("[F1] Search"),
                const SizedBox(width: 8),
                _buildHotkeyBadge("[F2] Clear Cart"),
                const SizedBox(width: 8),
                _buildHotkeyBadge("[F12] Checkout"),
                const SizedBox(width: 8),
                _buildHotkeyBadge("[Esc] Clear / Unfocus"),
              ],
            ),
            const SizedBox(width: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "Hardware Scanner: Active",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotkeyBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
      ),
    );
  }

  Widget _buildDesktopCartPane(BuildContext context, WidgetRef ref, double cartTotal, Map<String, CartItem> cart, bool isDark) {
    final activeColor = isDark ? Colors.cyanAccent : Colors.blueAccent;
    final totalUnits = cart.values.fold<double>(0, (sum, item) => sum + item.quantity);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cartWidth = screenWidth < 900 ? 300.0 : (screenWidth < 1200 ? 340.0 : 370.0);

    return Container(
      width: cartWidth,
      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Column(
            children: [
              // 1. Cart Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart_checkout_rounded, color: activeColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Current Order",
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    if (cart.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${totalUnits.toStringAsFixed(totalUnits % 1 == 0 ? 0 : 2)} items",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: activeColor),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.pause_circle_outline, color: Colors.amber, size: 20),
                        tooltip: "Hold Order",
                        onPressed: () => _promptHoldCart(cartTotal),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20),
                        tooltip: "Clear Order [F2]",
                        onPressed: _promptClearCart,
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),

              // 2. Line Items List
              Expanded(
                child: cart.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.remove_shopping_cart_outlined,
                                size: 48,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Order is empty",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Select items from catalog or scan barcode to add",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: cart.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final cartItemId = cart.keys.elementAt(index);
                          final item = cart.values.elementAt(index);
                          final product = item.product;

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      "Rs. ${item.subTotal.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: activeColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.description != null && item.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      item.description!,
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Rs. ${item.effectivePrice.toStringAsFixed(2)}${product.baseUnit != null && product.baseUnit!.isNotEmpty ? ' / ${product.baseUnit}' : ''}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            if (item.quantity > 1) {
                                              ref.read(cartProvider.notifier).updateQuantity(cartItemId, item.quantity - 1);
                                            } else {
                                              ref.read(cartProvider.notifier).removeFromCart(cartItemId);
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(Icons.remove, size: 14, color: isDark ? Colors.white : Colors.black87),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            UnitFormatter.format(item.quantity, product.baseUnit),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            ref.read(cartProvider.notifier).updateQuantity(cartItemId, item.quantity + 1);
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(Icons.add, size: 14, color: isDark ? Colors.white : Colors.black87),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.edit_note, size: 17),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          color: isDark ? Colors.white60 : Colors.black54,
                                          tooltip: "Edit Item",
                                          onPressed: () {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor: Colors.transparent,
                                              builder: (_) => EditCartItemSheet(cartItem: item, cartItemId: cartItemId),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // 3. Checkout Action
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.shade50,
                  border: Border(
                    top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "Total Amount",
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                          ),
                        ),
                        Text(
                          "Rs. ${cartTotal.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: activeColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: cart.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                              );
                            },
                      icon: const Icon(Icons.payment_rounded, size: 18),
                      label: Text(
                        cart.isEmpty ? "CART IS EMPTY" : "CHECKOUT [F12]  (Rs. ${cartTotal.toStringAsFixed(2)})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeColor,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, UserModel? user) {
    if (user == null) return const SizedBox(); 
    
    // Sub Logic
    final expiry = user.expiryDate;
    final daysLeft = expiry != null ? expiry.difference(DateTime.now()).inDays : 0;
    final isExpired = daysLeft < 0;
    
    return Drawer(
      child: ListView(
        children: [
           UserAccountsDrawerHeader(
            accountName: Text(user.shopName ?? "POS Podda"),
            accountEmail: Text(user.name),
            currentAccountPicture: const CircleAvatar(child: Icon(Icons.store)),
          ),
          
          // SUBSCRIPTION SUMMARY
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isExpired ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isExpired ? Colors.redAccent.withValues(alpha: 0.5) : Colors.cyanAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(user.plan.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: isExpired ? Colors.redAccent : Colors.cyanAccent)),
                 Text(
                   isExpired ? "EXPIRED" : "$daysLeft Days Left",
                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isExpired ? Colors.red : Colors.cyan),
                 )
               ],
            ),
          ),
          
          if (user.hasPermission(AppPermissions.canManageInventory))
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text("Inventory & Stock"),
            onTap: () {
               Navigator.pop(context); 
               Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
            },
          ),

          if (user.hasPermission(AppPermissions.canManageInventory))
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined, color: Colors.cyanAccent),
            title: const Text("Procurement & ERP (GRN)"),
            onTap: () {
               Navigator.pop(context); 
               Navigator.push(context, MaterialPageRoute(builder: (_) => const GRNHistoryScreen()));
            },
          ),
          
          if (user.hasPermission(AppPermissions.canViewCredit))
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text("Credit Book (Potha)"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
            },
          ),

          ListTile(
            leading: const Icon(Icons.point_of_sale_rounded, color: Colors.greenAccent),
            title: const Text("Shifts & Cash Balancing"),
            onTap: () {
               Navigator.pop(context); 
               Navigator.push(context, MaterialPageRoute(builder: (_) => const ShiftHistoryScreen()));
            },
          ),
          
          if (user.isAdmin) 
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text("Daily Reports"),
            onTap: () {
               Navigator.pop(context); 
               Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
            },
          ),
          
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () {
               Navigator.pop(context);
               Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ["All", "Unit", "Measurable", "Service"];
    return SizedBox(
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_,__) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
           final filter = filters[index];
           final isSelected = _selectedFilter == filter;
           final isDark = Theme.of(context).brightness == Brightness.dark;
           return ChoiceChip(
             label: Text(filter),
             selected: isSelected,
             onSelected: (val) => setState(() => _selectedFilter = filter),
             selectedColor: Colors.cyanAccent,
             labelStyle: TextStyle(
               fontWeight: FontWeight.bold,
               color: isSelected 
                   ? Colors.black // Cyan is bright, so Black text is visible
                   : (isDark ? Colors.white : Colors.black) // Unselected: White in Dark, Black in Light
             ),
             backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(20), 
               side: BorderSide(color: isDark ? Colors.white12 : Colors.transparent)
             ),
           );
        },
      ),
    );
  }

  Widget _buildProductGrid(WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);

    return productsAsync.when(
      loading: () => const ShimmerProductGrid(),
      error: (err, st) => const Center(child: Text("Error loading items")),
      data: (products) {
        // Filter Logic
        final filtered = products.where((p) {
           // GLOBAL LOCK: Only show Active items in POS 
           if (!p.isActive) return false;

           if (_searchQuery.isNotEmpty) {
             final q = _searchQuery.toLowerCase();
             final nameMatch = p.name.toLowerCase().contains(q);
             final barcodeMatch = p.barcode != null && p.barcode!.toLowerCase().contains(q);
             if (!nameMatch && !barcodeMatch) return false;
           }

           if (_selectedFilter == 'All') return true;
           if (_selectedFilter == 'Unit') return p.stockType == 'unit' && p.productType != 'SERVICE';
           if (_selectedFilter == 'Measurable') return p.stockType == 'weight' && p.productType != 'SERVICE'; 
           if (_selectedFilter == 'Service') return p.productType == 'SERVICE';
           return true;
        }).toList();

        if (filtered.isEmpty) {
          return Center(child: Text("No items found for $_selectedFilter"));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160, 
            childAspectRatio: 0.67, 
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final product = filtered[index];
            // Dynamic color based on type or just nice pastels (with opacity for dark mode)
            // Determine Border Color based on Type
            Color borderColor = Colors.white.withValues(alpha: 0.3); // Default
            if (product.productType == 'SERVICE') borderColor = Colors.purpleAccent.withValues(alpha: 0.5);
            else if (product.stockType == 'weight') borderColor = Colors.orangeAccent.withValues(alpha: 0.5);
            else borderColor = Colors.cyanAccent.withValues(alpha: 0.5); // Default for Unit items

            return GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.all(8),
              border: Border.all(color: borderColor, width: 1.5),
              onTap: () async {
                 // 1. Check for Multi-Batch Prices
                 final batches = await ref.read(productRepositoryProvider).getPosBatches(product.id);
                 double? selectedBatchPrice;
                 
                 if (batches.isNotEmpty) {
                    final uniquePrices = batches.map((b) => b.sellingPrice).toSet().toList();
                    if (uniquePrices.length > 1) {
                       selectedBatchPrice = await BatchPriceSelectionDialog.show(context, product, batches);
                       if (selectedBatchPrice == null) return; 
                    } else {
                       selectedBatchPrice = uniquePrices.first;
                    }
                 }

                 if (context.mounted) {
                   showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => AddToCartSheet(product: product, overridePrice: selectedBatchPrice),
                   );
                 }
              },
              onLongPress: () {
                 if (product.productType == 'SERVICE') {
                    showModalBottomSheet(
                       context: context,
                       isScrollControlled: true,
                       backgroundColor: Colors.transparent,
                       builder: (_) => ProductDetailsSheet(product: product), // Usually logic for service
                    );
                 } else {
                    Navigator.push(
                       context,
                       MaterialPageRoute(builder: (_) => ProductDashboardScreen(product: product)),
                    );
                 }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black12,
                    radius: 18,
                    child: Icon(
                      product.productType == 'SERVICE' ? Icons.cleaning_services 
                      : (product.stockType == 'weight' ? Icons.scale : Icons.shopping_bag),
                      size: 18, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black54
                    ),
                  ),
                  const SizedBox(height: 5),
                  Flexible(
                    child: Text(
                      product.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 3),
                  product.isVariablePrice 
                  ? const Text("Variable", style: TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold))
                  : Builder(builder: (_) {
                       // Unit Scaling Logic for Display
                       double price = product.sellingPrice;
                       String unitSuffix = "";
                       
                       if (product.stockType != 'unit' && product.stockType != 'service') {
                          if (product.baseUnit == 'g') {
                             price *= 1000;
                             unitSuffix = "/kg";
                          } else if (product.baseUnit == 'ml') {
                             price *= 1000;
                             unitSuffix = "/L";
                          } else if (product.baseUnit == 'cm') {
                             price *= 100;
                             unitSuffix = "/m";
                          } else if (product.baseUnit != null) {
                             unitSuffix = "/${product.baseUnit}";
                          }
                       }
                      
                       return Text("Rs. ${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}$unitSuffix", 
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                       );
                  }),
                  if (product.productType != 'SERVICE') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: product.currentStock <= 0
                            ? Colors.red.withOpacity(0.2)
                            : (product.currentStock <= (product.lowStockThreshold ?? 5)
                                ? Colors.amber.withOpacity(0.2)
                                : Colors.green.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.currentStock <= 0
                            ? "Out of Stock"
                            : (product.currentStock <= (product.lowStockThreshold ?? 5)
                                ? "Low: ${UnitFormatter.format(product.currentStock, product.baseUnit)}"
                                : "Stock: ${UnitFormatter.format(product.currentStock, product.baseUnit)}"),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: product.currentStock <= 0
                              ? Colors.redAccent
                              : (product.currentStock <= (product.lowStockThreshold ?? 5)
                                  ? Colors.amberAccent
                                  : Colors.greenAccent),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartBar(BuildContext context, double total, int itemsCount) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Floating Margin
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 24,
      onTap: () {
        showModalBottomSheet(
          context: context, 
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _buildFullCartSheet(context),
        );
      },
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Text("$itemsCount", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Total", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54, fontSize: 11)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text("Rs. ${total.toStringAsFixed(2)}", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("View Cart", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_up, color: Colors.cyanAccent, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullCartSheet(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.black.withValues(alpha: 0.85) 
                  : Colors.white.withValues(alpha: 0.85),
              child: Column(
                children: [
                   const SizedBox(height: 12),
                   // Handle
                   Center(
                      child: Container(
                        width: 50, height: 5,
                        decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(10)),
                      ),
                   ),
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 20),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(
                           "Current Cart", 
                           style: TextStyle(
                             fontSize: 20, 
                             fontWeight: FontWeight.bold, 
                             color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black
                           )
                         ),
                         Consumer(builder: (ctx, ref, _) {
                           final cart = ref.watch(cartProvider);
                           if (cart.isEmpty) return const SizedBox.shrink();
                           return Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               TextButton.icon(
                                 onPressed: () {
                                   Navigator.pop(context);
                                   _promptHoldCart(ref.read(cartTotalProvider));
                                 },
                                 icon: const Icon(Icons.pause_circle_outline, color: Colors.amber, size: 16),
                                 label: const Text("Hold", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                               ),
                               TextButton.icon(
                                 onPressed: () {
                                   Navigator.pop(context);
                                   _promptClearCart();
                                 },
                                 icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 16),
                                 label: const Text("Clear", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                               ),
                             ],
                           );
                         }),
                       ],
                     ),
                   ),
                   const SizedBox(height: 12),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final cart = ref.watch(cartProvider); 
                    return ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: cart.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final String cartItemId = cart.keys.elementAt(index);
                        final CartItem item = cart[cartItemId]!;
                        final product = item.product;
                        
                        // Price Display Logic
                        String priceDisplay = "Rs. ${item.effectivePrice.toStringAsFixed(2)}";
                        String unitLabel = ""; 
                        
                        if (product.baseUnit == 'g') {
                          priceDisplay = "Rs. ${(item.effectivePrice * 1000).toStringAsFixed(2)}";
                          unitLabel = " / kg";
                        } else if (product.baseUnit == 'ml') {
                           priceDisplay = "Rs. ${(item.effectivePrice * 1000).toStringAsFixed(2)}";
                           unitLabel = " / L";
                        } else if (product.baseUnit == 'cm') {
                           priceDisplay = "Rs. ${(item.effectivePrice * 100).toStringAsFixed(2)}";
                           unitLabel = " / m";
                        } else {
                           unitLabel = " / unit";
                        }

                        bool isDiscounted = item.effectivePrice < product.sellingPrice;
                        
                        return GlassCard(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(0), // Inner padding handled by padding widget
                          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12),
                          onTap: () {
                             showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => EditCartItemSheet(cartItem: item, cartItemId: cartItemId),
                             );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Icon/Image Placeholder
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.blueGrey : Colors.blue.shade100).withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12)
                                  ),
                                  child: Icon(
                                    product.productType == 'SERVICE' ? Icons.cleaning_services : Icons.shopping_bag_outlined,
                                    color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(product.name, style: TextStyle(
                                        fontSize: 16, 
                                        fontWeight: FontWeight.bold, 
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87
                                      )),
                                      const SizedBox(height: 4),
                                      Text(
                                        "$priceDisplay$unitLabel",
                                        style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey, fontSize: 13),
                                      ),
                                      if (item.description != null && item.description!.isNotEmpty)
                                        Text(
                                          item.description!, 
                                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic, fontSize: 12),
                                          maxLines: 1, overflow: TextOverflow.ellipsis
                                        ),
                                      if (isDiscounted)
                                        const Text("(Discounted)", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontStyle: FontStyle.italic)),
                                      
                                      const SizedBox(height: 8),
                                      // Explicit Actions
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor: Colors.transparent,
                                                  builder: (_) => EditCartItemSheet(cartItem: item, cartItemId: cartItemId),
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.edit, size: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blue),
                                                  const SizedBox(width: 4),
                                                  Text("Edit", style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blue, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Container(height: 12, width: 1, color: Colors.grey.withValues(alpha: 0.5)),
                                          InkWell(
                                            onTap: () {
                                               ref.read(cartProvider.notifier).removeFromCart(cartItemId);
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.delete, size: 14, color: Colors.redAccent),
                                                  const SizedBox(width: 4),
                                                  const Text("Remove", style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                
                                // Qty & Total
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                     Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         InkWell(
                                           onTap: () {
                                             if (item.quantity > 1) {
                                               ref.read(cartProvider.notifier).updateQuantity(cartItemId, item.quantity - 1);
                                             } else {
                                               ref.read(cartProvider.notifier).removeFromCart(cartItemId);
                                             }
                                           },
                                           borderRadius: BorderRadius.circular(6),
                                           child: Container(
                                             padding: const EdgeInsets.all(4),
                                             decoration: BoxDecoration(
                                               color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade200,
                                               borderRadius: BorderRadius.circular(6),
                                             ),
                                             child: Icon(Icons.remove, size: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                           ),
                                         ),
                                         Padding(
                                           padding: const EdgeInsets.symmetric(horizontal: 8),
                                           child: Text(
                                             UnitFormatter.format(item.quantity, product.baseUnit),
                                             style: TextStyle(
                                               fontWeight: FontWeight.bold,
                                               fontSize: 13,
                                               color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                             ),
                                           ),
                                         ),
                                         InkWell(
                                           onTap: () {
                                             ref.read(cartProvider.notifier).updateQuantity(cartItemId, item.quantity + 1);
                                           },
                                           borderRadius: BorderRadius.circular(6),
                                           child: Container(
                                             padding: const EdgeInsets.all(4),
                                             decoration: BoxDecoration(
                                               color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade200,
                                               borderRadius: BorderRadius.circular(6),
                                             ),
                                             child: Icon(Icons.add, size: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                           ),
                                         ),
                                       ],
                                     ),
                                     const SizedBox(height: 8),
                                    Text(
                                      "Rs. ${item.subTotal.toStringAsFixed(2)}",
                                      style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // CHECKOUT BUTTON
              Consumer(builder: (context, ref, child) {
                 final user = ref.watch(userProfileProvider).value;
                 if (user != null && user.hasPermission(AppPermissions.canCheckout)) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: Colors.green.withValues(alpha: 0.4)
                        ),
                        child: const Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Icon(Icons.payment),
                             SizedBox(width: 8),
                             Text("CHARGE (CHECKOUT)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                           ],
                        ),
                      ),
                    );
                 } else {
                   return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text("Checkout Disabled (Ask Owner)", style: TextStyle(color: Colors.grey)),
                   );
                 }
              }),
            ],
          ),
        ),
      ),
    );
  },
 );
}
}

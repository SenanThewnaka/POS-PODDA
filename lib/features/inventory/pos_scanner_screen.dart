import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sme_buddy/features/checkout/checkout_screen.dart';
import 'package:sme_buddy/features/home/add_to_cart_sheet.dart';
import 'package:sme_buddy/features/home/cart_provider.dart';
import 'package:sme_buddy/features/inventory/batch_price_selection_dialog.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/inventory/stock_batch_model.dart';
import 'package:sme_buddy/utils/sound_service.dart';

class POSScannerScreen extends ConsumerStatefulWidget {
  const POSScannerScreen({super.key});

  @override
  ConsumerState<POSScannerScreen> createState() => _POSScannerScreenState();
}

class _POSScannerScreenState extends ConsumerState<POSScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  late final AnimationController _laserAnim;
  bool _isProcessing = false;
  bool _isTorchOn = false;
  String? _lastScannedBanner;
  String? _lastScannedCode;
  DateTime? _lastScannedTimestamp;

  @override
  void initState() {
    super.initState();
    _laserAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        final cleanCode = code.trim();
        // Prevent rapid repeated triggers for the exact same barcode within 1.5 seconds
        if (_lastScannedCode == cleanCode && _lastScannedTimestamp != null) {
          if (DateTime.now().difference(_lastScannedTimestamp!).inMilliseconds < 1500) {
            return;
          }
        }
        _handleBarcode(cleanCode);
        break;
      }
    }
  }

  void _handleBarcode(String code) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
      _lastScannedTimestamp = DateTime.now();
    });

    try {
      final product = await ref.read(productRepositoryProvider).getProductByBarcode(code);

      if (!mounted) return;

      if (product != null) {
        if (!product.isActive) {
          SoundService.playScanError();
          await HapticFeedback.heavyImpact();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("This product is marked inactive"),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        SoundService.playScanSuccess();
        await HapticFeedback.lightImpact();

        final bool needsCustomInput = product.stockType != 'unit' || product.isVariablePrice;

        List<StockBatch> batches = [];
        try {
          batches = await ref.read(productRepositoryProvider).getActiveBatches(product.id);
        } catch (_) {}

        final uniquePrices = batches.map((b) => b.sellingPrice).toSet().toList();
        final bool hasMultiplePrices = uniquePrices.length > 1;

        if (needsCustomInput) {
          if (!mounted) return;
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: AddToCartSheet(product: product),
            ),
          );
        } else if (hasMultiplePrices) {
          if (!mounted) return;
          final selectedPrice = await BatchPriceSelectionDialog.show(context, product, batches);
          if (selectedPrice != null) {
            ref.read(cartProvider.notifier).addToCart(product, quantity: 1, overridePrice: selectedPrice);
            _setScannedBanner(product.name, selectedPrice);
          }
        } else {
          final double price = uniquePrices.length == 1 ? uniquePrices.first : product.sellingPrice;
          ref.read(cartProvider.notifier).addToCart(product, quantity: 1, overridePrice: price);
          _setScannedBanner(product.name, price);
        }
      } else {
        SoundService.playScanError();
        await HapticFeedback.mediumImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No product found for code: $code"),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Scan error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _setScannedBanner(String productName, double price) {
    if (!mounted) return;
    setState(() {
      _lastScannedBanner = "$productName • Rs. ${price.toStringAsFixed(0)}";
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _lastScannedBanner != null) {
        setState(() => _lastScannedBanner = null);
      }
    });
  }

  void _promptClearCart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "Clear Current Cart?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        content: Text(
          "Remove all scanned items from the cart?",
          style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
            },
            child: const Text("Clear Cart"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isLandscapeTablet = size.width >= 750;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE8ECEF),
      appBar: AppBar(
        title: const Text("POS Barcode Scanner", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _isTorchOn ? "Turn Torch Off" : "Turn Torch On",
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.amber : (isDark ? Colors.white70 : Colors.black54),
            ),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            tooltip: "Switch Camera",
            icon: Icon(
              Icons.cameraswitch,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () => _controller.switchCamera(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: isLandscapeTablet
          ? Row(
              children: [
                // Left: Camera Viewfinder (Landscape)
                Expanded(
                  flex: 5,
                  child: _buildCameraViewport(isDark, size),
                ),
                // Right: Scanned Items Cart Panel
                Expanded(
                  flex: 6,
                  child: _buildCartPanel(cart, total, isDark),
                ),
              ],
            )
          : Column(
              children: [
                // Top: Focused Camera Viewfinder (Portrait)
                SizedBox(
                  height: (size.height * 0.36).clamp(220.0, 290.0),
                  child: _buildCameraViewport(isDark, size),
                ),
                // Bottom: Live Scanned Cart & Ring-up Station
                Expanded(
                  child: _buildCartPanel(cart, total, isDark),
                ),
              ],
            ),
    );
  }

  Widget _buildCameraViewport(bool isDark, Size size) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Dark vignette overlays outside reticle
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Central Scanner Reticle
          Center(
            child: Container(
              width: 260,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isProcessing
                      ? const Color(0xFF10B981)
                      : Colors.cyanAccent.withValues(alpha: 0.85),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isProcessing ? const Color(0xFF10B981) : Colors.cyanAccent)
                        .withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    // Animated moving laser line
                    AnimatedBuilder(
                      animation: _laserAnim,
                      builder: (context, child) {
                        return Positioned(
                          top: 8 + (_laserAnim.value * 90),
                          left: 10,
                          right: 10,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: _isProcessing ? const Color(0xFF10B981) : Colors.redAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isProcessing ? const Color(0xFF10B981) : Colors.redAccent)
                                      .withValues(alpha: 0.9),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Live feedback status chip floating at bottom of viewfinder
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _lastScannedBanner != null
                    ? Container(
                        key: ValueKey(_lastScannedBanner),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF065F46),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF6EE7B7), size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _lastScannedBanner!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        key: const ValueKey('idle_prompt'),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isProcessing ? Icons.hourglass_top : Icons.filter_center_focus,
                              size: 13,
                              color: _isProcessing ? Colors.amber : Colors.cyanAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isProcessing ? "Reading barcode..." : "Align barcode in frame",
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPanel(Map<String, CartItem> cart, double total, bool isDark) {
    final totalUnits = cart.values.fold<double>(0, (sum, i) => sum + i.quantity);
    final hasDecimalUnits = cart.values.any((i) => i.quantity % 1 != 0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Cart Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_outlined, size: 20, color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Text(
                  "Scanned Cart",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${cart.length} items (${totalUnits.toStringAsFixed(hasDecimalUnits ? 2 : 0)} pcs)",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                    ),
                  ),
                ),
                const Spacer(),
                if (cart.isNotEmpty)
                  TextButton.icon(
                    onPressed: _promptClearCart,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.redAccent),
                    label: const Text(
                      "Clear",
                      style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),

          // 2. Cart Items List
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Ready to Ring Up Items",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Aim the camera at product barcodes above.\nScanned items will appear here automatically.",
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
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = cart.entries.elementAt(index);
                      final cartItemId = entry.key;
                      final item = entry.value;
                      final product = item.product;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Product Icon / Avatar
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                product.productType == 'SERVICE'
                                    ? Icons.cleaning_services
                                    : (product.stockType == 'weight' ? Icons.scale : Icons.inventory_2_outlined),
                                size: 18,
                                color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Product Name & Price
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Rs. ${item.effectivePrice.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Inline Stepper (- / +)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    if (item.quantity <= 1) {
                                      ref.read(cartProvider.notifier).removeFromCart(cartItemId);
                                    } else {
                                      ref.read(cartProvider.notifier).updateQuantity(cartItemId, item.quantity - 1);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      item.quantity <= 1 ? Icons.delete_outline : Icons.remove,
                                      size: 16,
                                      color: item.quantity <= 1
                                          ? Colors.redAccent
                                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                    ),
                                  ),
                                ),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 28),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    "${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    ref.read(cartProvider.notifier).updateQuantity(cartItemId, item.quantity + 1);
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.add,
                                      size: 16,
                                      color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),

                            // Line Item Subtotal
                            SizedBox(
                              width: 68,
                              child: Text(
                                "Rs. ${item.subTotal.toStringAsFixed(0)}",
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // 3. Bottom Sticky Checkout Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "TOTAL",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        "Rs. ${total.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: cart.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                            );
                          },
                    icon: const Icon(Icons.payment, size: 18),
                    label: Text(
                      cart.isEmpty ? "CART EMPTY" : "CHECKOUT (${cart.length})",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: isDark ? Colors.white10 : Colors.black12,
                      disabledForegroundColor: isDark ? Colors.white30 : Colors.black26,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: cart.isEmpty ? 0 : 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

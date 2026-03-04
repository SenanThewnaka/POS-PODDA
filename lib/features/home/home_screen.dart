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
import 'dart:ui'; // Req for ImageFilter
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/features/subscription/subscription_guard.dart';
import 'package:sme_buddy/utils/shimmer_skeletons.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedFilter = 'All'; // 'All', 'Unit', 'Measurable', 'Service'
  
  // Barcode Scanner Logic
  final StringBuffer _barcodeBuffer = StringBuffer();
  Timer? _barcodeBufferTimer;
  final FocusNode _keyboardFocusNode = FocusNode();

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
       final String? char = event.character;
       
       if (event.logicalKey == LogicalKeyboardKey.enter) {
          // Commit
          if (_barcodeBuffer.isNotEmpty) {
             _processBarcode(_barcodeBuffer.toString());
             _barcodeBuffer.clear();
          }
       } else if (char != null) {
          // Accumulate
          _barcodeBuffer.write(char);
          
          // Debounce Reset (e.g., if user typing manually too slow vs scanner)
          // Scanners are fast (< 50ms per key typically). 
          _barcodeBufferTimer?.cancel();
          _barcodeBufferTimer = Timer(const Duration(milliseconds: 500), () {
             _barcodeBuffer.clear();
          });
       }
    }
  }

  Future<void> _processBarcode(String barcode) async {
      // Logic to find product and add to cart
      final product = await ref.read(productRepositoryProvider).getProductByBarcode(barcode);
      
      if (!mounted) return;

      if (product != null) {
          if (product.isActive) {
             // OLD: Direct Add
             // ref.read(cartProvider.notifier).addToCart(product);
             
             // NEW: Open Modal for Quantity/Price/Cost Confirmation
             // We need to check for batches if we want to be consistent, but for rapid scan, 
             // we usually pick the default (active) batch or base price.
             // If the product has multiple batches, we might default to the first ACTIVE one 
             // or the one with the highest stock. 
             // ProductRepository.getPosBatches logic already does some of this filtering.
             
             // For now, let's open the sheet with base product data.
             
             showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AddToCartSheet(product: product),
             );

             /*
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text("Scanned: ${product.name}"), 
                 backgroundColor: Colors.green,
                 duration: const Duration(milliseconds: 800),
               )
             );
             */
          } else {
             _showError("Product is inactive");
          }
      } else {
          _showError("Product not found: $barcode");
      }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text(message), backgroundColor: Colors.redAccent)
    );
  }

  @override
  void dispose() {
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


    final isDesktop = MediaQuery.of(context).size.width >= 900;
    
    final mainContent = Column(
        children: [
            // 1. Top Bar: Search | Scan
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: GlassCard(
                      borderRadius: 30, // Pill shape
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 56, // Fixed height for alignment
                      child: Center(
                        child: TextField(
                          readOnly: true,
                          textAlignVertical: TextAlignVertical.center,
                          onTap: () async {
                             final productsAsync = ref.read(productsStreamProvider);
                             productsAsync.whenData((products) async {
                               final activeProducts = products.where((p) => p.isActive).toList();
                               final selected = await showSearch(
                                 context: context, 
                                 delegate: ProductSearchDelegate(activeProducts),
                               );
                               
                               if (selected != null) {
                                  ref.read(cartProvider.notifier).addToCart(selected);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Added ${selected.name} to cart!"), duration: const Duration(milliseconds: 800))
                                  );
                               }
                             });
                          },
                          decoration: InputDecoration(
                            hintText: "Search Item...",
                            hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54), // Adaptive Hint
                            prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            filled: false, // Turn off default fill since GlassCard handles it
                          ),
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GlassCard(
                    borderRadius: 16,
                    width: 56, height: 56,
                    padding: EdgeInsets.zero,
                    onTap: () async {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => const POSScannerScreen()));
                    },
                    child: const Center(
                      child: Icon(Icons.qr_code_scanner, size: 28, color: Colors.cyanAccent),
                    ),
                  ),

                ],
              ),
            ),

            // 2. Filter Chips
            _buildFilterBar(),

            // 3. Filtered Product Grid
            Expanded(
              child: _buildProductGrid(ref),
            ),

            // 4. Cart Bottom Sheet Slice
            if (cart.isNotEmpty)
              _buildCartBar(context, cartTotal, cart.length),
          ],
        );

    return Focus( // Keyboard Trap
       autofocus: true,
       focusNode: _keyboardFocusNode,
       onKeyEvent: (node, event) {
          _handleKey(event);
          return KeyEventResult.ignored; // Let others handle if needed, or handled if exclusive
       },
       child: GlassScaffold(
      drawer: isDesktop ? null : _buildDrawer(context, userProfile),
      body: isDesktop 
         ? Row(
             children: [
               SizedBox(
                 width: 300,
                 child: ClipRRect(
                   borderRadius: const BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24)),
                   child: _buildDrawer(context, userProfile),
                 )
               ),
               Expanded(child: mainContent),
             ],
           )
         : mainContent,
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
          
          if (user.hasPermission(AppPermissions.canViewCredit))
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text("Credit Book (Potha)"),
            onTap: () async {
               if (await SubscriptionGuard.check(context, ref, SubscriptionAction.accessCreditBook)) {
                  if (context.mounted) {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
                  }
               }
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
            childAspectRatio: 0.85, 
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
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
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black12,
                    radius: 20,
                    child: Icon(
                      product.productType == 'SERVICE' ? Icons.cleaning_services 
                      : (product.stockType == 'weight' ? Icons.scale : Icons.shopping_bag),
                      size: 20, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black54
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    product.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
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
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent)
                       );
                  }),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Text("$itemsCount", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(width: 16),
               Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text("Total", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54, fontSize: 12)),
                   Text("Rs. ${total.toStringAsFixed(2)}", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Text("View Cart", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_up, color: Colors.cyanAccent),
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
                   const SizedBox(height: 16),
                   Text(
                     "Current Cart", 
                     style: TextStyle(
                       fontSize: 22, 
                       fontWeight: FontWeight.bold, 
                       color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black
                     )
                   ),
                   const SizedBox(height: 16),
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
                                    Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                       decoration: BoxDecoration(
                                         color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade200,
                                         borderRadius: BorderRadius.circular(8)
                                       ),
                                       child: Text(
                                         UnitFormatter.format(item.quantity, product.baseUnit),
                                         style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                                       ),
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
                        onPressed: () async {
                          if (await SubscriptionGuard.check(context, ref, SubscriptionAction.write)) {
                              Navigator.pop(context); // Close sheet
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                              );
                          }
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

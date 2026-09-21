import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/home/cart_provider.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/utils/quantity_parser.dart';
import 'package:sme_buddy/utils/unit_formatter.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/text_controller_extensions.dart';

class AddToCartSheet extends ConsumerStatefulWidget {
  final Product product;
  final double? overridePrice; // New: For selected batch price

  const AddToCartSheet({super.key, required this.product, this.overridePrice});

  @override
  ConsumerState<AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends ConsumerState<AddToCartSheet> {
  // Logic
  double _quantity = 1.0; 
  final _smartInputController = TextEditingController();
  final _overridePriceController = TextEditingController(); // For Manual Selling Price / Discount
  final _manualCostController = TextEditingController(); // New: For Manual Cost Price (Variable Services)
  final _descriptionController = TextEditingController(); // New: Service Description
  String _parsedFeedback = ""; 
  String? _errorMessage; // New: Inline Error State 
  
  // State for Rate (Unit Price)
  late double _effectiveUnitPrice;
  
  // Discount Type State
  bool _isFixedDiscount = false; // false = Percentage, true = Fixed Amount

  // Focus Nodes for Keyboard Navigation
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _costFocusNode = FocusNode();
  final FocusNode _discountFocusNode = FocusNode(); // Also used for Price Override
  final FocusNode _descFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Initialize Rate: Use override/batch price if available, else standard selling price
    _effectiveUnitPrice = widget.overridePrice ?? widget.product.sellingPrice;

    // Default quantity
    if (widget.product.stockType == 'unit' || widget.product.stockType == 'service') {
      _quantity = 1.0;
      _smartInputController.text = "1"; // Init text for Unit Counter
      _smartInputController.selectAll();
    } else {
       _quantity = 0.0;
    }
    
    // Pre-fill Cost if available (e.g. from Product)
    if (widget.product.costPrice > 0) {
      _manualCostController.text = widget.product.costPrice.toStringAsFixed(2);
    }

    _qtyFocusNode.addListener(() {
      if (_qtyFocusNode.hasFocus) {
        _smartInputController.selectAll();
      }
    });
    _costFocusNode.addListener(() {
      if (_costFocusNode.hasFocus) {
        _manualCostController.selectAll();
      }
    });
    _discountFocusNode.addListener(() {
      if (_discountFocusNode.hasFocus) {
        _overridePriceController.selectAll();
      }
    });
  }

  @override
  void dispose() {
    _qtyFocusNode.dispose();
    _costFocusNode.dispose();
    _discountFocusNode.dispose();
    _descFocusNode.dispose();
    _smartInputController.dispose();
    _overridePriceController.dispose();
    _manualCostController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _parseInput(String val) {
    if (widget.product.stockType == 'unit') return;
    
    final bUnit = widget.product.baseUnit ?? 'g';
    double qty = QuantityParser.parse(val, bUnit);
    setState(() {
      _quantity = qty;
      _parsedFeedback = _quantity > 0 ? "Adding: ${UnitFormatter.format(_quantity, bUnit)}" : "";
      _errorMessage = null; // Clear error on change
    });
  }

  // Submit Handler (Extracted for Enter Key)
  void _submit() {
     // Helper for Conversion
     double conversionFactor = 1.0;
     if (widget.product.stockType != 'unit' && widget.product.stockType != 'service') {
        final bUnit = (widget.product.baseUnit ?? 'g').trim().toLowerCase();
        if (bUnit == 'g' || bUnit == 'ml') {
           conversionFactor = 1000.0;
        } else if (bUnit == 'cm') {
           conversionFactor = 100.0;
        }
     }

     // Financial Calcs for Validation
     double standardTotal = _effectiveUnitPrice * _quantity;
     double finalTotalSelling = standardTotal;
     double? inputVal = double.tryParse(_overridePriceController.text);
     
     if (inputVal != null && inputVal >= 0) {
       if (widget.product.isVariablePrice) {
          double ratePerBase = inputVal / conversionFactor;
          finalTotalSelling = ratePerBase * _quantity;
       } else {
          // Discount Logic
          if (_isFixedDiscount) {
             double discountPerBase = inputVal / conversionFactor;
             finalTotalSelling = standardTotal - (discountPerBase * _quantity);
          } else {
             if (inputVal <= 100) {
                finalTotalSelling = standardTotal - (standardTotal * (inputVal / 100));
             }
          }
       }
     }

     if (_quantity > 0 && finalTotalSelling >= 0 
          && !(widget.product.isVariablePrice && (double.tryParse(_overridePriceController.text) ?? 0) <= 0)
          && !(widget.product.isVariablePrice && (double.tryParse(_manualCostController.text) ?? -1) < 0) 
      ) { 
                final cart = ref.read(cartProvider);
                final existingItem = cart[widget.product.id];
                final currentQtyInCart = existingItem?.quantity ?? 0.0;
                final totalRequested = currentQtyInCart + _quantity;
                
                // Stock Check - Skip for Services
                if (widget.product.productType != 'SERVICE') {
                  if (totalRequested > widget.product.currentStock) {
                     final available = widget.product.currentStock - currentQtyInCart;
                     setState(() {
                        _errorMessage = available > 0 
                          ? "Only ${UnitFormatter.format(available, widget.product.baseUnit)} remaining!"
                          : "No stock left! (Already in cart: ${UnitFormatter.format(currentQtyInCart, widget.product.baseUnit)})";
                     });
                     return;
                  }
                }

                // Determine Final Unit Price for Cart
                double finalUnitPrice = _effectiveUnitPrice; 
                
                if (inputVal != null && inputVal >= 0) {
                   if (widget.product.isVariablePrice) {
                      finalUnitPrice = inputVal / conversionFactor;
                   } else {
                      if (_isFixedDiscount) {
                         double discountPerBase = inputVal / conversionFactor;
                         finalUnitPrice = _effectiveUnitPrice - discountPerBase;
                      } else {
                         if (inputVal <= 100) {
                            double discountAmount = standardTotal * (inputVal / 100);
                            // Final = Standard - Discount (Total)
                            double finalTotal = standardTotal - discountAmount;
                            if (_quantity > 0) finalUnitPrice = finalTotal / _quantity;
                         }
                      }
                   }
                }

                // Determine Cost Price - ALLOW FOR SERVICE TOO
                double? finalCostPrice;
                double manualCost = double.tryParse(_manualCostController.text) ?? -1;
                if (manualCost >= 0) {
                    finalCostPrice = manualCost;
                } else {
                    finalCostPrice = widget.product.costPrice;
                }

                ref.read(cartProvider.notifier).addToCart(
                   widget.product, 
                   quantity: _quantity,
                   overridePrice: finalUnitPrice, 
                   overrideCostPrice: finalCostPrice, 
                   description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
                );
                
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("Added ${UnitFormatter.format(_quantity, widget.product.baseUnit)} to cart"),
                  duration: const Duration(milliseconds: 800),
                ));
      }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).valueOrNull;
    final canGiveDiscount = user == null ? true : (user.isAdmin || user.hasPermission(AppPermissions.canGiveDiscount));
    final canViewCost = user == null ? true : (user.isAdmin || user.hasPermission(AppPermissions.canViewCostPrice));

    // Financial Calcs
    
    // 1. Calculate Standard Totals using EFFECTIVE Rate (from batch selection)
    // Missing Variables Restoration
    
    // Helper for Conversion
    double conversionFactor = 1.0;
    String displayUnitLabel = "/${widget.product.baseUnit ?? 'unit'}";
    
    if (widget.product.stockType != 'unit' && widget.product.stockType != 'service') {
       final bUnit = (widget.product.baseUnit ?? 'g').trim().toLowerCase();
       if (bUnit == 'g' || bUnit == 'ml') {
          conversionFactor = 1000.0;
          displayUnitLabel = bUnit == 'g' ? "/kg" : "/L";
       } else if (bUnit == 'cm') {
          conversionFactor = 100.0;
          displayUnitLabel = "/m";
       } else if (bUnit == 'kg') {
          conversionFactor = 1.0;
          displayUnitLabel = "/kg";
       } else if (bUnit == 'l') {
          conversionFactor = 1.0;
          displayUnitLabel = "/L";
       } else if (bUnit == 'm') {
          conversionFactor = 1.0;
          displayUnitLabel = "/m";
       }
    }

    // Check for User Input (Override or Discount)
    double? inputVal = double.tryParse(_overridePriceController.text);

    // Display Rate: Scaled UP to Main Unit (e.g. Price per Kg)
    double displayRate = widget.product.isVariablePrice 
        ? (inputVal ?? 0) 
        : _effectiveUnitPrice * conversionFactor; 
        
    String perUnitLabel = (widget.product.stockType == 'unit' || widget.product.stockType == 'service')
        ? "/item" 
        : displayUnitLabel;

    // Financial Calcs using SCALED Discount
    double standardTotal = _effectiveUnitPrice * _quantity;
    
    double costPerUnit = widget.product.costPrice;
    if (widget.product.isVariablePrice) {
       costPerUnit = double.tryParse(_manualCostController.text) ?? 0.0;
    }
    double totalCost = costPerUnit * _quantity;

    double finalTotalSelling = standardTotal;
    
    if (inputVal != null && inputVal >= 0) {
      if (widget.product.isVariablePrice) {
         // Variable Price: Input is UNIT PRICE (already per unit/kg usually? No, per item).
         // If variable, usually it's "Enter Price".
         // Is "Enter Price" per Gram or per Kg?
         // User likely enters "Price for this amount" OR "Price per Kg"?
         // Label says: "Enter Unit Price". "Price for 1 item".
         // For measurable, it should probably be "Price per Kg".
         // If so, we need to divide by factor.
         // Let's assume Variable input is ALSO Per Main Unit (e.g. Price per Kg provided by user).
         
         double ratePerBase = inputVal / conversionFactor;
         finalTotalSelling = ratePerBase * _quantity;
         
         // Fix display variables for Variable logic
         // displayRate is just inputVal (already scaled by definition if user enters per kg)
         displayRate = inputVal;
         
      } else {
         // Standard: Discount Logic
         if (_isFixedDiscount) {
            // Fix Amount Off Per Main Unit (e.g. 20 Rs off per Kg)
            // We need to convert this "20" into "Rs off per Gram"
            double discountPerBase = inputVal / conversionFactor;
            
            double totalDiscount = discountPerBase * _quantity;
            finalTotalSelling = standardTotal - totalDiscount;
         } else {
            // Percentage Discount
            if (inputVal <= 100) {
               finalTotalSelling = standardTotal - (standardTotal * (inputVal / 100));
            }
         }
      }
    }

    double profit = finalTotalSelling - totalCost;

    // INPUT FIELD CONFIG
    String labelText;
    String hintText;
    String helperText;
    Widget? prefixConfig;
    Widget? suffixConfig;
    
    if (widget.product.isVariablePrice) {
       labelText = "Enter Unit Price";
       hintText = "Price for 1 item";
       helperText = "Total will be calculated based on quantity";
       prefixConfig = const Text("Rs. ");
       suffixConfig = null;
    } else {
       if (_isFixedDiscount) {
           String unitName = (widget.product.stockType == 'unit' || widget.product.stockType == 'service')
               ? "Item" 
               : (widget.product.baseUnit ?? 'Unit');
               
           labelText = "Discount Amount (Per $unitName)";
           hintText = "e.g. 20";
           helperText = inputVal != null && inputVal > 0 
              ? "Total Discount: Rs. ${(inputVal * _quantity).toStringAsFixed(2)}" 
              : "Enter amount off per 1 $unitName";
           prefixConfig = const Text("Rs. ");
           suffixConfig = null;
        } else {
          labelText = "Discount Percentage (%)";
          hintText = "e.g. 10";
          helperText = inputVal != null && inputVal > 0 
             ? "Discount: Rs. ${(standardTotal * (inputVal/100)).toStringAsFixed(2)}" 
             : "Enter discount % (0 for none)";
          prefixConfig = null;
          suffixConfig = const Text("%");
       }
    }

    return Container(
      padding: EdgeInsets.only(
        top: 24, 
        left: 24, 
        right: 24, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 24
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent, // Transparent for GlassEffect
      ),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 50, height: 5,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),


            // Header
            Text(widget.product.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            // Only show stock for physical items
            if (widget.product.productType != 'SERVICE')
              Text(
                "Stock: ${UnitFormatter.format(widget.product.currentStock, widget.product.baseUnit)}", 
                textAlign: TextAlign.center,
                style: TextStyle(color: widget.product.currentStock <= 0 ? Colors.red : Colors.grey[600]),
              ),
            
            // Show Selected Rate explicitly
            Padding(
               padding: const EdgeInsets.only(top: 8),
               child: Text(
                 "Rate: Rs. ${displayRate.toStringAsFixed(2)} $perUnitLabel",
                 textAlign: TextAlign.center,
                 style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent),
               ),
            ),
            
            const Divider(height: 32),

            // INPUT SECTION
            // Wrap in Keyboard Listener for TAB support throughout the form
            Focus(
              onKeyEvent: (node, event) {
                 if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
                    setState(() {
                      _isFixedDiscount = !_isFixedDiscount;
                    });
                    return KeyEventResult.handled;
                 }
                 return KeyEventResult.ignored; 
              },
              child: Column(
                children: [
                    if (widget.product.stockType == 'unit' || widget.product.stockType == 'service') 
                      _buildUnitCounter()
                    else 
                      _buildSmartInput(),
                    
                    const SizedBox(height: 16),
                    
                    // DISCOUNT TYPE TOGGLE
                    if (!widget.product.isVariablePrice && canGiveDiscount)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isFixedDiscount = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_isFixedDiscount ? Colors.cyan.withValues(alpha: 0.2) : Colors.white10,
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                    border: Border.all(color: !_isFixedDiscount ? Colors.cyanAccent : Colors.white24)
                                  ),
                                  child: Center(child: Text("Percentage (%)", style: TextStyle(color: !_isFixedDiscount ? (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent) : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54), fontWeight: FontWeight.bold))),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isFixedDiscount = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _isFixedDiscount ? (Theme.of(context).brightness == Brightness.dark ? Colors.cyan.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.1)) : (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12),
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                                    border: Border.all(color: _isFixedDiscount ? (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent) : Colors.transparent)
                                  ),
                                  child: Center(child: Text("Fixed Amount (Rs)", style: TextStyle(color: _isFixedDiscount ? (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent) : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54), fontWeight: FontWeight.bold))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // COST FIELD (Variable OR SERVICE)
                    if ((widget.product.isVariablePrice || widget.product.productType == 'SERVICE') && canViewCost) ...[
                       TextField(
                         controller: _manualCostController,
                         focusNode: _costFocusNode,
                         keyboardType: const TextInputType.numberWithOptions(decimal: true),
                         textInputAction: TextInputAction.next,
                         onSubmitted: (_) {
                            if (widget.product.productType == 'SERVICE') {
                               FocusScope.of(context).requestFocus(_descFocusNode);
                            } else {
                               FocusScope.of(context).requestFocus(_discountFocusNode);
                            }
                         },
                         onChanged: (val) => setState((){}), 
                         onTap: () => _manualCostController.selectAll(),
                         decoration: InputDecoration(
                           labelText: "Cost Price (Per Unit)",
                           hintText: "Cost for 1 item (e.g. Labor + Parts)",
                           prefixIcon: const Icon(Icons.money_off),
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                           fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                           filled: true,
                           errorText: (widget.product.isVariablePrice && (double.tryParse(_manualCostController.text) ?? -1) < 0) ? "Required for Profit Calc" : null,
                         ),
                       ),
                       const SizedBox(height: 12),
                    ],

                    // DISCOUNT / OVERRIDE / VARIABLE PRICE FIELD
                    if (widget.product.isVariablePrice || canGiveDiscount)
                    TextField(
                      controller: _overridePriceController,
                      focusNode: _discountFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      onChanged: (val) => setState((){}), 
                      onTap: () => _overridePriceController.selection = TextSelection(baseOffset: 0, extentOffset: _overridePriceController.text.length),
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: labelText,
                        hintText: hintText,
                        labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                        prefixIcon: prefixConfig != null ? Padding(padding: const EdgeInsets.all(12), child: prefixConfig) : null,
                        suffixIcon: suffixConfig != null ? Padding(padding: const EdgeInsets.all(12), child: suffixConfig) : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent)),
                        filled: true,
                        fillColor: widget.product.isVariablePrice 
                            ? Colors.green.withValues(alpha: 0.1) 
                            : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                        helperText: helperText,
                        helperStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
                        errorText: (widget.product.isVariablePrice && (inputVal ?? 0) <= 0) 
                            ? "Required (Selling Price)" 
                            : (inputVal != null && !widget.product.isVariablePrice && inputVal > 100) ? "Invalid %" : null
                      ),
                    ),
                ],
              ),
            ),

            
            // DESCRIPTION FIELD (New for SERVICES)
            if (widget.product.productType == 'SERVICE') ...[
               const SizedBox(height: 16),
               TextField(
                 controller: _descriptionController,
                 focusNode: _descFocusNode,
                 textInputAction: TextInputAction.done,
                 onSubmitted: (_) => _submit(),
                 decoration: InputDecoration(
                   labelText: "Description / Notes",
                   hintText: "e.g. Reload - 077xxxxxxx",
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                   filled: true,
                   fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50,
                   prefixIcon: const Icon(Icons.description),
                 ),
               ),
            ],

            const SizedBox(height: 16),

          // Total Preview Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total Selling Price:", style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
                    Text("Rs. ${finalTotalSelling.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  ],
                ),
                if (canViewCost) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total Cost:", style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey)), 
                      Text("Rs. ${totalCost.toStringAsFixed(2)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Profit Margin:", style: TextStyle(fontSize: 14, color: Colors.greenAccent)),
                      Text("Rs. ${profit.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // ERROR MESSAGE
          if (_errorMessage != null)
             Padding(
               padding: const EdgeInsets.only(bottom: 12),
               child: Center(
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                   decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                   child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                 ),
               ),
             ),

          // ADD BUTTON
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: (_quantity > 0 && finalTotalSelling >= 0 
                  && !(widget.product.isVariablePrice && (double.tryParse(_overridePriceController.text) ?? 0) <= 0)
                  && !(widget.product.isVariablePrice && (double.tryParse(_manualCostController.text) ?? -1) < 0) 
              ) ? _submit : null, 
              icon: const Icon(Icons.shopping_cart),
              label: const Text("ADD TO CART", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent,
                foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                elevation: 10,
                shadowColor: (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
              ),
            ),
          )
        ],
      ),
      ),
      ),
    );
  }

  Widget _buildUnitCounter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          onPressed: _quantity > 1 ? () {
             setState(() {
               _quantity--;
               _smartInputController.text = _quantity.toInt().toString();
             });
          } : null,
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 16),
        // Editable Quantity Field
        SizedBox(
          width: 80,
          child: TextField(
            controller: _smartInputController,
            focusNode: _qtyFocusNode,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
               if (widget.product.isVariablePrice || widget.product.productType == 'SERVICE') {
                  FocusScope.of(context).requestFocus(_costFocusNode);
               } else {
                  FocusScope.of(context).requestFocus(_discountFocusNode);
               }
            },
            onChanged: (val) {
               double? parsed = double.tryParse(val);
               if (parsed != null) {
                 setState(() => _quantity = parsed);
               }
            },
            onTap: () => _smartInputController.selectAll(),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        IconButton.filledTonal(
          onPressed: () {
             setState(() {
               _quantity++;
               _smartInputController.text = _quantity.toInt().toString();
             });
          },
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _buildSmartInput() {
    return Column(
      children: [
        TextField(
          controller: _smartInputController,
          focusNode: _qtyFocusNode,
          autofocus: true, // Focus here by default for Measurable items
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
             // Move to cost or discount
             if (widget.product.isVariablePrice || widget.product.productType == 'SERVICE') {
                FocusScope.of(context).requestFocus(_costFocusNode);
             } else {
                FocusScope.of(context).requestFocus(_discountFocusNode);
             }
          },
          onChanged: _parseInput,
          onTap: () => _smartInputController.selection = TextSelection(baseOffset: 0, extentOffset: _smartInputController.text.length),
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            labelText: "Enter Amount (e.g. 1kg 500g, 2L, 5ft)",
            hintText: "Try '500g' or '1.5kg'",
            labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent)),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            prefixIcon: Icon(Icons.scale, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent),
          ),
        ),
        if (_parsedFeedback.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_parsedFeedback, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

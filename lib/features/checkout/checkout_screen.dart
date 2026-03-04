import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/home/cart_provider.dart';
import 'package:sme_buddy/features/credit/customer_model.dart';
import 'package:sme_buddy/features/credit/customer_repository.dart';
import 'package:sme_buddy/features/credit/customer_list_screen.dart';
import 'package:sme_buddy/features/credit/customer_list_screen.dart';
import 'package:sme_buddy/features/reports/sales_repository.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/reports/receipt_screen.dart';
import 'package:sme_buddy/features/subscription/subscription_guard.dart';
import 'package:sme_buddy/utils/analytics_service.dart';
import 'package:sme_buddy/utils/rating_service.dart';

import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _paymentMethod = 'CASH'; // CASH, CARD, CREDIT
  double _cashGiven = 0;
  Customer? _selectedCustomer;

  @override
  Widget build(BuildContext context) {
    final total = ref.watch(cartTotalProvider);
    final cart = ref.watch(cartProvider);

    return GlassScaffold(
      appBar: AppBar(title: const Text("Checkout"), backgroundColor: Colors.transparent),
      body: Column(
        children: [
          // 1. Total Amount (Huge)
          GlassCard(
            margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            borderRadius: 24,
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5), width: 1.5),
            child: SizedBox(
               width: double.infinity,
               child: Column(
                children: [
                  const Text("TOTAL TO PAY", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  Text("Rs. ${total.toStringAsFixed(2)}", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
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
                      Expanded(child: _buildPaymentToggle("CASH", Icons.money, Colors.greenAccent)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildPaymentToggle("CARD", Icons.credit_card, Colors.blueAccent)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildPaymentToggle("CREDIT", Icons.person, Colors.redAccent)),
                    ],
                  ),
                  
                  const SizedBox(height: 32),

                  // 3. Method Specific UI
                  if (_paymentMethod == 'CASH') ...[
                    Text("Quick Cash Suggestions:", style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _getQuickCashOptions(total).map((amount) {
                         final isSelected = _cashGiven == amount;
                         return GlassCard(
                           borderRadius: 20,
                           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                           color: isSelected ? Colors.cyan.withValues(alpha: 0.5) : null,
                           onTap: () {
                             HapticFeedback.selectionClick();
                             setState(() => _cashGiven = amount);
                           },
                           child: Text("Rs. ${amount.toInt()}", style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                         );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    GlassCard(
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 18),
                        decoration: InputDecoration(
                          labelText: "Custom Amount Given",
                          labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none, 
                          prefixText: "Rs. ",
                          prefixStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                        ),
                        onChanged: (val) => setState(() => _cashGiven = double.tryParse(val) ?? 0),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_cashGiven >= total)
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             const Text("CHANGE DUE:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                             Text("Rs. ${_cashGiven - total}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
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
                                ? Text("Tap to Select Customer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_selectedCustomer!.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                                      Text("Current Due: Rs. ${_selectedCustomer!.currentBalance}", style: const TextStyle(color: Colors.redAccent)),
                                    ],
                                  ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white54),
                          ],
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),

          // 4. Complete Action
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : () {
                if (_paymentMethod == 'CREDIT' && _selectedCustomer == null) {
                  _selectCustomer();
                } else if (_paymentMethod == 'CASH' && _cashGiven < total) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                       content: Text("Insufficient Cash! Short by Rs. ${(total - _cashGiven).toStringAsFixed(2)}"),
                       backgroundColor: Colors.redAccent,
                     )
                   );
                } else {
                  // Process Sale
                  _processSale(total);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _paymentMethod == 'CREDIT' ? Colors.redAccent : Colors.greenAccent,
                foregroundColor: Colors.black, // Dark text on bright buttons
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                : Text(
                _paymentMethod == 'CREDIT' 
                    ? (_selectedCustomer == null ? "SELECT CUSTOMER" : "ADD TO POTHA (CREDIT)") 
                    : "COMPLETE SALE",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
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

  Widget _buildPaymentToggle(String label, IconData icon, Color color) {
    final isSelected = _paymentMethod == label;
    
    return GlassCard( // Use GlassCard for toggle
      onTap: () async {
        if (label == 'CREDIT') {
           if (!await SubscriptionGuard.check(context, ref, SubscriptionAction.accessCreditBook)) {
              return;
           }
        }
        
        setState(() {
          _paymentMethod = label;
          _cashGiven = 0; // reset
          _selectedCustomer = null; 
        });
        HapticFeedback.mediumImpact();
      },
      padding: const EdgeInsets.symmetric(vertical: 16),
      borderRadius: 12,
      // Use color override for selected state
      color: isSelected ? color.withValues(alpha: 0.2) : null,
      border: Border.all(
         color: isSelected ? color : Colors.white.withValues(alpha: 0.1), 
         width: isSelected ? 2 : 1
      ),
      child: Column(
        children: [
          Icon(icon, color: isSelected ? color : Colors.grey, size: 32),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: isSelected ? color : Colors.grey, fontWeight: FontWeight.bold)),
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

   bool _isLoading = false;

   void _processSale(double total) async {
     setState(() => _isLoading = true);
     
     try {
       if (_paymentMethod == 'CREDIT' && _selectedCustomer != null) {
         await ref.read(customerRepositoryProvider).updateBalance(_selectedCustomer!.id, total);
       }
       
       final cart = ref.read(cartProvider); // Map<String, CartItem>
       
       // Save to DB (FireStore)
       // Returns Sale object
       // We need to transform Cart map to what recordSale expects.
       // Originally recordSale expected Map<Product, double> which was passed as `cart`.
       // We should update recordSale signature OR manually map it here.
       // Let's look at `recordSale`. It probably takes `Map<Product, double>`.
       // We need to update `recordSale` in repository too.
       // But for now, let's fix the call.
       
       // Wait, `recordSale` needs to know about `effectivePrice`.
       // If I pass old map, I lose price info.
       // I MUST update `SalesRepository.recordSale`.
       
       // Let's pass the new cart map directly and update Repo in next step.
       final sale = await ref.read(salesRepositoryProvider).recordSale(
         total, 
         _paymentMethod, 
         _paymentMethod == 'CREDIT' ? _selectedCustomer?.id : null,
         cart 
       );

       // Update Stock Logic
       // CartItem has product and qty
       // Update Stock Logic
       // CartItem has product and qty
       final stockUpdates = cart.values.map((item) => BatchSaleItem(
         productId: item.product.id, 
         quantity: item.quantity,
         soldPrice: item.effectivePrice,
       )).toList();
       await ref.read(productRepositoryProvider).processSale(stockUpdates);

       // Clear Cart
       ref.read(cartProvider.notifier).clearCart();
       
       HapticFeedback.heavyImpact(); // Success Haptic

       // Analytics: track every completed sale
       AnalyticsService.logSaleCompleted(
         totalAmount: total,
         paymentMethod: _paymentMethod,
         itemCount: cart.length,
       );
       if (_paymentMethod == 'CREDIT') {
         AnalyticsService.logCreditSale(amount: total);
       }

       // Rating: nudge after 10th sale
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

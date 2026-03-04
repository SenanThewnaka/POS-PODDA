import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/credit/customer_model.dart';
import 'package:sme_buddy/features/reports/sale_model.dart';
import 'package:sme_buddy/features/reports/sales_repository.dart';
import 'package:sme_buddy/features/reports/receipt_screen.dart';
import 'package:sme_buddy/features/credit/customer_repository.dart';
import 'package:sme_buddy/features/credit/settlement_receipt_screen.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/shimmer_skeletons.dart';

final customerSalesProvider = StreamProvider.family<List<Sale>, String>((ref, customerId) {
  return ref.watch(salesRepositoryProvider).getSalesByCustomer(customerId);
});

class CustomerHistoryScreen extends ConsumerStatefulWidget {
  final Customer customer;
  const CustomerHistoryScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends ConsumerState<CustomerHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerId = widget.customer.id;
    // We listen to the specific document stream for this customer to always get the latest balance
    final customersAsync = ref.watch(customersStreamProvider);
    final salesAsync = ref.watch(customerSalesProvider(customerId));

    // Find our specific customer from the list stream to get live balance
    final liveCustomer = customersAsync.value?.firstWhere(
      (c) => c.id == customerId, 
      orElse: () => widget.customer
    ) ?? widget.customer;

    return Scaffold(
      appBar: AppBar(
        title: Text(liveCustomer.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Outstanding"),
            Tab(text: "Settled History"),
          ],
        ),
        actions: [
          // Total Balance Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20)
            ),
            child: Text(
              "Due: Rs. ${liveCustomer.currentBalance}", 
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.red : Colors.redAccent, fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
      body: salesAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: List.generate(4, (_) => const ShimmerListTile()),
        ),
        error: (e, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 64, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text('Failed to load history', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
        data: (sales) {
          final outstanding = sales.where((s) => !s.isFullyPaid).toList();
          final settled = sales.where((s) => s.isFullyPaid).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildSalesList(outstanding, liveCustomer, isSettled: false),
              _buildSalesList(settled, liveCustomer, isSettled: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSalesList(List<Sale> sales, Customer liveCustomer, {required bool isSettled}) {
    if (sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Icon(isSettled ? Icons.history : Icons.assignment_turned_in, size: 60, color: Colors.grey.shade300),
             const SizedBox(height: 16),
             Text(isSettled ? "No settled bills yet." : "No outstanding bills!", 
               style: TextStyle(color: Colors.grey.shade600, fontSize: 18)
             ),
          ],
        )
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Added bottom padding for FAB/Navbar
      itemCount: sales.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final sale = sales[index];
        final remaining = sale.totalAmount - sale.amountPaid;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            borderRadius: 16,
            border: Border.all(
              color: isSettled 
                ? (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade300)
                : (Theme.of(context).brightness == Brightness.dark ? Colors.redAccent.withValues(alpha: 0.5) : Colors.red.shade200)
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSettled ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: isSettled ? Colors.green : Colors.orange, width: 2)
                      ), 
                      child: Icon(isSettled ? Icons.check : Icons.history, color: isSettled ? Colors.green : Colors.orange, size: 20)
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                          Text(DateFormat('dd MMM yyyy, hh:mm a').format(sale.timestamp), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                    if (!isSettled && (ref.watch(userProfileProvider).value?.hasPermission(AppPermissions.canSettleCredit) ?? false))
                      ElevatedButton(
                        onPressed: () => _showPaymentDialog(context, ref, sale, liveCustomer.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent, 
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: const Size(60, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          shadowColor: Colors.blueAccent.withValues(alpha: 0.4)
                        ),
                        child: const Text("PAY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    else 
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                           color: Colors.green.withValues(alpha: 0.1), 
                           borderRadius: BorderRadius.circular(12),
                           border: Border.all(color: Colors.green.withValues(alpha: 0.5))
                        ),
                        child: const Text("PAID", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Paid: Rs. ${sale.amountPaid.toStringAsFixed(2)}", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey[700])),
                    if (!isSettled)
                      Text("Due: Rs. ${remaining.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))
                    else
                      const Text("Settled", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (isSettled) ...[
                   const SizedBox(height: 8),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.end,
                     children: [
                       TextButton.icon(
                         icon: Icon(Icons.receipt_long, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blue),
                         label: Text("View Receipt", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blue)),
                         onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => SettlementReceiptScreen(
                              customerName: liveCustomer.name,
                              amountPaid: sale.amountPaid,
                              previousDue: sale.totalAmount, 
                              remainingDue: 0,
                              billId: sale.id,
                              timestamp: sale.timestamp,
                              isHistoryView: true,
                            )));
                         },
                       ),
                     ],
                   )
                ] else ...[
                   const SizedBox(height: 8),
                   Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Share (Outstanding)
                        IconButton.filledTonal(
                           icon: const Icon(Icons.share, color: Colors.green),
                           style: IconButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.1)),
                           onPressed: () async {
                               String mobile = liveCustomer.mobile;
                               if (mobile.startsWith("0")) mobile = "94${mobile.substring(1)}";
                               final text = "Bill Reminder: Rs. ${remaining.toStringAsFixed(2)} due for bill dated ${DateFormat('dd MMM').format(sale.timestamp)}.";
                               final url = "https://wa.me/$mobile?text=${Uri.encodeComponent(text)}";
                               try { if (await canLaunchUrlString(url)) await launchUrlString(url, mode: LaunchMode.externalApplication); } catch (_) {}
                           },
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: Icon(Icons.receipt_long, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blue),
                          label: Text("View Status", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blue)),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => SettlementReceiptScreen(
                              customerName: liveCustomer.name,
                              amountPaid: sale.amountPaid,
                              previousDue: sale.totalAmount, 
                              remainingDue: remaining,
                              billId: sale.id,
                              timestamp: sale.timestamp,
                              isHistoryView: true,
                            )));
                          },
                        ),
                      ],
                   )
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  // Moved Dialog Logic to method for cleaner build()
  void _showPaymentDialog(BuildContext parentContext, WidgetRef ref, Sale sale, String customerId) {
    final TextEditingController amountCtrl = TextEditingController();
    final remaining = sale.totalAmount - sale.amountPaid;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        // We use StatefulBuilder to update error message inside dialog
        return StatefulBuilder(
          builder: (innerContext, setState) {
            
            return _PaymentDialogContent(
               remaining: remaining,
               amountCtrl: amountCtrl,
               onPay: (amount) async {
                  try {
                    // Determine live customer name (best effort)
                    String custName = widget.customer.name;
                    
                    await ref.read(salesRepositoryProvider).recordPayment(sale.id, customerId, amount);
                    
                    if (innerContext.mounted) {
                       // Use pushReplacement to replace the Dialog with the Receipt Screen
                       Navigator.pushReplacement(
                         innerContext,
                         MaterialPageRoute(
                           builder: (_) => SettlementReceiptScreen(
                             customerName: custName,
                             amountPaid: amount,
                             previousDue: remaining,
                             remainingDue: remaining - amount,
                             billId: sale.id,
                             timestamp: DateTime.now(),
                           )
                         )
                       );
                    }
                  } catch (e) {
                    if(innerContext.mounted) ScaffoldMessenger.of(innerContext).showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
               }
            );
          },
        );
      } 
    );
  }

}

class _PaymentDialogContent extends StatefulWidget {
  final double remaining;
  final TextEditingController amountCtrl;
  final Function(double) onPay;

  const _PaymentDialogContent({
    required this.remaining, 
    required this.amountCtrl, 
    required this.onPay
  });

  @override
  State<_PaymentDialogContent> createState() => _PaymentDialogContentState();
}

class _PaymentDialogContentState extends State<_PaymentDialogContent> {
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Settle Bill", style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3))
            ),
            child: Text("Outstanding: Rs. ${widget.remaining.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16)),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: widget.amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
            textAlign: TextAlign.center,
            onTap: () => widget.amountCtrl.selection = TextSelection(baseOffset: 0, extentOffset: widget.amountCtrl.text.length),
            decoration: InputDecoration(
              labelText: "Enter Payment",
              labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white24)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent)),
              prefixText: "Rs. ",
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              errorText: _errorText, // Show error here
            ),
            onChanged: (val) {
               if (_errorText != null) setState(() => _errorText = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ElevatedButton(
          onPressed: () {
            final double? amount = double.tryParse(widget.amountCtrl.text);
            
            if (amount == null || amount <= 0) {
              setState(() => _errorText = "Please enter a valid positive amount");
              return;
            }

            // Tolerance for floating point precision (0.01)
            if (amount > widget.remaining + 0.01) {
              setState(() => _errorText = "Amount cannot exceed outstanding balance (Rs. ${widget.remaining.toStringAsFixed(2)})");
              return;
            }

            widget.onPay(amount);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
          ),
          child: const Text("PAY NOW", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/credit/customer_model.dart';
import 'package:sme_buddy/features/credit/customer_repository.dart';
import 'package:sme_buddy/features/credit/customer_history_screen.dart';
import 'package:url_launcher/url_launcher_string.dart'; 
// Note: url_launcher needs to be added to yaml, but we'll implement logic and user can add dep later if needed.
// For now, we will just print or mock the action to avoid crashes if dep missing.

import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';

import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/glass_dialog.dart';
import 'package:sme_buddy/utils/shimmer_skeletons.dart';

class CustomerListScreen extends ConsumerWidget {
  final bool isSelectionMode;
  final Function(Customer)? onSelect;

  const CustomerListScreen({
    super.key,
    this.isSelectionMode = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).value;
    final customersAsync = ref.watch(customersStreamProvider);

    // If used in Dashboard, we might want transparent background, but GlassScaffold is safe for both.
    // However, to match InventoryScreen pattern and avoid drawing background twice in Dashboard:
    // We can check if we are in a selection mode (pushed) or not. 
    // Actually, simpler: Use GlassScaffold. If it's in a PageView, it's fine.

    return GlassScaffold(
      appBar: AppBar(
        title: Text(isSelectionMode ? "Select Customer" : "Credit Book (Potha)", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: customersAsync.when(
        loading: () => ListView.builder(
          itemCount: 8,
          itemBuilder: (_, __) => const ShimmerListTile(),
        ),
        error: (err, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text("Failed to load customers", style: TextStyle(color: Colors.red.shade300, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Check your connection and try again.", style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
        data: (customers) {
          if (customers.isEmpty) return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 80, color: Colors.white30),
                const SizedBox(height: 16),
                const Text("No Customers Yet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 8),
                const Text("Tap the + button to add your first customer.", style: TextStyle(color: Colors.white38)),
              ],
            ),
          );
          
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 300), // Increased to 300 to clear lifted FAB (Aggressive fix)
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              final isHighBalance = customer.currentBalance > 5000;
              
              return GlassCard(
                borderRadius: 16,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                border: isHighBalance ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5)) : null,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.8),
                    child: Text(customer.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(customer.name, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                  subtitle: Text("Due: Rs. ${customer.currentBalance.toStringAsFixed(2)}", 
                    style: TextStyle(
                      color: customer.currentBalance > 0 ? Colors.redAccent : Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: isSelectionMode 
                      ? const Icon(Icons.check_circle_outline, color: Colors.cyanAccent)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (userProfile?.hasPermission(AppPermissions.canEditCreditors) ?? false)
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orangeAccent),
                              onPressed: () => _showCustomerDialog(context, ref, customer: customer),
                            ),
                            IconButton(
                              icon: const Icon(Icons.call, color: Colors.blueAccent),
                              onPressed: () async {
                                final url = "tel:${customer.mobile}";
                                if (await canLaunchUrlString(url)) {
                                  await launchUrlString(url);
                                } else {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch dialer")));
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.message, color: Colors.greenAccent),
                              onPressed: () {
                                _showMessageOptions(context, customer);
                              },
                            ),
                          ],
                        ),
                  onTap: isSelectionMode ? () {
                    if (onSelect != null) onSelect!(customer);
                    Navigator.pop(context);
                  } : () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerHistoryScreen(customer: customer)));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: (userProfile?.hasPermission(AppPermissions.canEditCreditors) ?? false) 
       ? Padding(
          padding: const EdgeInsets.only(bottom: 80), // Lift above Bottom Nav
          child: FloatingActionButton.extended(
            onPressed: () => _showCustomerDialog(context, ref),
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
            label: const Text("New Customer", style: TextStyle(fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.person_add),
          ),
        ) : null,
    );
  }

  void _showMessageOptions(BuildContext context, Customer customer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Important for glass effect
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark 
                ? [Colors.black.withValues(alpha: 0.9), const Color(0xFF0D0025).withValues(alpha: 0.9)] 
                : [Colors.white.withValues(alpha: 0.95), Colors.blue.shade50.withValues(alpha: 0.95)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4, width: 40, 
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2))
              ),
              Text("Contact Customer", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.cyanAccent : Colors.blueAccent)),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.message, color: Colors.blue),
                ),
                title: Text("Send SMS", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                onTap: () async {
                   Navigator.pop(context);
                   final Uri smsLaunchUri = Uri(
                     scheme: 'sms',
                     path: customer.mobile,
                     queryParameters: <String, String>{
                       'body': "Hello ${customer.name}, friendly reminder regarding your balance of Rs. ${customer.currentBalance.toStringAsFixed(2)}",
                     },
                   );
                   if (await canLaunchUrlString(smsLaunchUri.toString())) {
                      await launchUrlString(smsLaunchUri.toString());
                   } else {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch SMS")));
                   }
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.chat, color: Colors.green),
                ),
                title: Text("Send via WhatsApp", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                onTap: () async {
                  Navigator.pop(context);
                  String mobile = customer.mobile;
                  if (mobile.startsWith("0")) {
                    mobile = "94${mobile.substring(1)}";
                  }
                  final url = "https://wa.me/$mobile?text=Hello ${customer.name}, just a friendly reminder about your balance of Rs. ${customer.currentBalance.toStringAsFixed(2)}";
                  
                  if (await canLaunchUrlString(url)) {
                    await launchUrlString(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch WhatsApp")));
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  void _showCustomerDialog(BuildContext context, WidgetRef ref, {Customer? customer}) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening..."), duration: Duration(milliseconds: 200)));
    final nameController = TextEditingController(text: customer?.name ?? '');
    final mobileController = TextEditingController(text: customer?.mobile ?? '');
    final isEdit = customer != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void onSave() {
      final name = nameController.text.trim();
      final mobile = mobileController.text.trim();

      if (name.isEmpty || mobile.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields are required!"), backgroundColor: Colors.red));
          return;
      }

      if (mobile.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(mobile)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mobile number must be exactly 10 digits!"), backgroundColor: Colors.red));
          return;
      }

      if (isEdit) {
          ref.read(customerRepositoryProvider).updateCustomer(customer.id, name, mobile);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Customer Updated!")));
      } else {
          ref.read(customerRepositoryProvider).addCustomer(name, mobile);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Customer Added!")));
      }
      Navigator.pop(context);
    }

    GlassDialog.show(
      context,
      title: isEdit ? "Edit Customer" : "Add New Customer",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController, 
            autofocus: true,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: "Name",
              labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
              border: const OutlineInputBorder()
            )
          ),
          const SizedBox(height: 16),
          TextField(
            controller: mobileController, 
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSave(),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: "Mobile Number (10 digits)", 
              counterText: "",
              labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
              border: const OutlineInputBorder()
            ), 
            keyboardType: TextInputType.phone,
            maxLength: 10,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54))),
        ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
            minimumSize: const Size(100, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ),
          child: Text(isEdit ? "SAVE" : "ADD", style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

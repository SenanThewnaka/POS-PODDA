import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';

class InvoiceSettingsScreen extends ConsumerStatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  ConsumerState<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends ConsumerState<InvoiceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _shopNameCtrl;
  late TextEditingController _shopAddressCtrl;
  late TextEditingController _shopMobileCtrl;
  late TextEditingController _footerMsgCtrl;
  late TextEditingController _contactInfoCtrl;
  // Removed _logoUrlCtrl

  @override
  void initState() {
    super.initState();
    _shopNameCtrl = TextEditingController();
    _shopAddressCtrl = TextEditingController();
    _shopMobileCtrl = TextEditingController();
    _footerMsgCtrl = TextEditingController();
    _contactInfoCtrl = TextEditingController();
    // Removed _logoUrlCtrl
  }

  void _init(UserModel user) {
    if (_shopNameCtrl.text.isEmpty) {
      _shopNameCtrl.text = user.shopName ?? '';
      _shopAddressCtrl.text = user.shopAddress ?? '';
      _shopMobileCtrl.text = user.shopMobile ?? '';
      _footerMsgCtrl.text = user.invoiceFooterMessage ?? 'Thank You! Come Again.';
      _contactInfoCtrl.text = user.invoiceContactInfo ?? '';
      // Removed _logoUrlCtrl
    }
  }

  void _save(UserModel user) async {
    if (!_formKey.currentState!.validate()) return;
    
    final updated = UserModel(
      uid: user.uid,
      email: user.email,
      name: user.name,
      mobile: user.mobile,
      role: user.role,
      shopId: user.shopId,
      permissions: user.permissions,
      shopCode: user.shopCode,
      username: user.username,
      isActive: user.isActive,
      // Updated Fields
      shopName: _shopNameCtrl.text.trim(),
      shopAddress: _shopAddressCtrl.text.trim(),
      shopMobile: _shopMobileCtrl.text.trim(),
      // shopLogo: _logoUrlCtrl.text.trim(), // Keep existing logo if any, or clear it? User asked to remove option to add. 
      // Safest is to just ignore it, or set to null if we want to enforce removal. 
      // But for now, just removing the capability to edit it.
      shopLogo: user.shopLogo, // Preserve existing or maybe user wants to REMOVE logo? "remove the option to add alogo" often implies UI.
      invoiceFooterMessage: _footerMsgCtrl.text.trim(),
      invoiceContactInfo: _contactInfoCtrl.text.trim(),
    );

    try {
      await ref.read(userProfileRepositoryProvider).saveUserProfile(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invoice settings saved!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Bill Customization")),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,s) => Center(child: Text("Error: $e")),
        data: (user) {
          if (user == null || !user.isAdmin) return const Center(child: Text("Access Denied"));
          _init(user);
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header("Header Information"),
                  _input("Shop Name", _shopNameCtrl, Icons.store),
                  _input("Shop Address", _shopAddressCtrl, Icons.location_on, maxLines: 2),
                  _input("Shop Phone (Header)", _shopMobileCtrl, Icons.phone),
                  
                  const SizedBox(height: 20),
                  // Logo Section Removed
                  
                  const SizedBox(height: 20),
                  _header("Footer Information"),
                  _input("Custom Message", _footerMsgCtrl, Icons.message, hint: "Thank You! Come Again."),
                  _input("Contact Info (Footer)", _contactInfoCtrl, Icons.contact_phone, hint: "For inquiries: 077xxxxxxx"),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _save(user),
                      child: const Text("SAVE SETTINGS"),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
    );
  }

  Widget _input(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

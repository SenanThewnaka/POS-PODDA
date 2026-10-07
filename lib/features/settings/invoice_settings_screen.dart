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
  late TextEditingController _vatNumberCtrl;
  late TextEditingController _vatPercentageCtrl;

  bool _isVatRegistered = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _shopNameCtrl = TextEditingController();
    _shopAddressCtrl = TextEditingController();
    _shopMobileCtrl = TextEditingController();
    _footerMsgCtrl = TextEditingController();
    _contactInfoCtrl = TextEditingController();
    _vatNumberCtrl = TextEditingController();
    _vatPercentageCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    _shopMobileCtrl.dispose();
    _footerMsgCtrl.dispose();
    _contactInfoCtrl.dispose();
    _vatNumberCtrl.dispose();
    _vatPercentageCtrl.dispose();
    super.dispose();
  }

  void _init(UserModel user) {
    if (!_initialized) {
      _shopNameCtrl.text = user.shopName ?? '';
      _shopAddressCtrl.text = user.shopAddress ?? '';
      _shopMobileCtrl.text = user.shopMobile ?? '';
      _footerMsgCtrl.text = user.invoiceFooterMessage ?? 'Thank You! Come Again.';
      _contactInfoCtrl.text = user.invoiceContactInfo ?? '';
      
      _isVatRegistered = user.isVatRegistered;
      _vatNumberCtrl.text = user.vatNumber ?? '';
      _vatPercentageCtrl.text = user.vatPercentage.toString();
      
      _initialized = true;
    }
  }

  void _save(UserModel user) async {
    if (!_formKey.currentState!.validate()) return;
    
    final updated = user.copyWith(
      shopName: _shopNameCtrl.text.trim(),
      shopAddress: _shopAddressCtrl.text.trim(),
      shopMobile: _shopMobileCtrl.text.trim(),
      invoiceFooterMessage: _footerMsgCtrl.text.trim(),
      invoiceContactInfo: _contactInfoCtrl.text.trim(),
      isVatRegistered: _isVatRegistered,
      vatNumber: _vatNumberCtrl.text.trim().isEmpty ? null : _vatNumberCtrl.text.trim(),
      vatPercentage: double.tryParse(_vatPercentageCtrl.text.trim()) ?? 18.0,
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
                  _header("Tax & VAT Configuration (IRD Format)"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.cyanAccent.withValues(alpha: 0.1) 
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          title: const Text("Enable Tax Invoice Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text("Formats receipts as 'TAX INVOICE' and separates VAT amounts. Ideal for VAT registered businesses."),
                          value: _isVatRegistered,
                          activeColor: Colors.cyanAccent,
                          onChanged: (val) => setState(() => _isVatRegistered = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_isVatRegistered) ...[
                          const SizedBox(height: 12),
                          _input("VAT Registration Number (TIN)", _vatNumberCtrl, Icons.numbers),
                          _input("VAT Rate (%)", _vatPercentageCtrl, Icons.percent, keyboardType: TextInputType.number),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  _header("Header Information"),
                  _input("Shop Name", _shopNameCtrl, Icons.store),
                  _input("Shop Address", _shopAddressCtrl, Icons.location_on, maxLines: 2),
                  _input("Shop Phone (Header)", _shopMobileCtrl, Icons.phone),
                  
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
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
    );
  }

  Widget _input(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1, String? hint, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
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

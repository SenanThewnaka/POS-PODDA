import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/settings/printer_settings_screen.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/utils/glass_card.dart';

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
  String _previewRollSize = '80mm'; // '80mm' or '58mm' for live preview simulation

  // Sinhala & English footer presets for 1-tap selection
  static const List<Map<String, String>> _footerPresets = [
    {
      'label': '🇱🇰 ස්තූතියි! නැවත එන්න.',
      'text': 'ස්තූතියි! නැවත එන්න.',
    },
    {
      'label': '🇬🇧 Thank You! Come Again.',
      'text': 'Thank You! Come Again.',
    },
    {
      'label': '🔄 බිල්පත නැතිව මාරු නොකෙරේ',
      'text': 'බිල්පත නොමැතිව භාණ්ඩ මාරු නොකෙරේ (No exchange without bill)',
    },
    {
      'label': '⏳ දින 7ක් තුළ මාරු කළ හැක',
      'text': 'භාණ්ඩ මාරු කිරීම දින 7ක් ඇතුළත පමණි (Exchange within 7 days)',
    },
    {
      'label': '🚫 මුදල් ආපසු නොගෙවේ',
      'text': 'ආපසු මුදල් ගෙවනු නොලැබේ (No cash refunds)',
    },
    {
      'label': '📲 WhatsApp ඇණවුම්',
      'text': 'WhatsApp මගින් ඇණවුම් ලබාදීමට අප අමතන්න.',
    },
  ];

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

  void _applyFooterPreset(String presetText) {
    setState(() {
      _footerMsgCtrl.text = presetText;
    });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Receipt customization saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefer shop owner profile so settings persist correctly for the entire store
    final userAsync = ref.watch(shopOwnerProfileProvider).value != null 
        ? AsyncData(ref.watch(shopOwnerProfileProvider).value) 
        : ref.watch(userProfileProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bill & Receipt Customization", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: "Printer & Roll Settings",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
        data: (user) {
          if (user == null || !user.isAdmin) return const Center(child: Text("Access Denied"));
          _init(user);
          
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _buildFormFields(user, isDark)),
                                const SizedBox(width: 24),
                                Expanded(flex: 2, child: _buildLiveThermalPreview(isDark)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildFormFields(user, isDark),
                                const SizedBox(height: 32),
                                _buildLiveThermalPreview(isDark),
                              ],
                            ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFormFields(UserModel user, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Banner linking to Printer Hardware
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.print, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Configure Thermal Printer & Paper Roll (80mm / 58mm)",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blueAccent),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Section 1: Store & Header Branding
        _header("1. Store Header & Information"),
        _input("Shop / Store Name", _shopNameCtrl, Icons.store, hint: "e.g. Perera Grocery & Stores"),
        _input("Store Address", _shopAddressCtrl, Icons.location_on, maxLines: 2, hint: "e.g. No. 45, Galle Road, Colombo 03"),
        _input("Store Phone / Mobile (Header)", _shopMobileCtrl, Icons.phone, hint: "e.g. 0112345678 / 0771234567"),
        _input(
          "Business Reg. No. / Tax ID", 
          _vatNumberCtrl, 
          Icons.badge_outlined, 
          hint: "e.g. BR No: PV-12345 or TIN: 102938475",
        ),
        
        const SizedBox(height: 20),

        // Section 2: Tax & VAT Configuration
        _header("2. Tax & VAT Mode (IRD Format)"),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.cyanAccent.withValues(alpha: 0.08) : Colors.cyan.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text("Enable IRD Tax Invoice Format", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text("Prints 'TAX INVOICE' heading and calculates VAT breakdown according to Inland Revenue regulations."),
                value: _isVatRegistered,
                activeColor: Colors.cyanAccent,
                onChanged: (val) => setState(() => _isVatRegistered = val),
                contentPadding: EdgeInsets.zero,
              ),
              if (_isVatRegistered) ...[
                const SizedBox(height: 12),
                _input("VAT Rate (%)", _vatPercentageCtrl, Icons.percent, keyboardType: TextInputType.number, hint: "18.0"),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Section 3: Custom Footer & Sinhala/English Presets
        _header("3. Receipt Footer & Policies"),
        Text(
          "Tap a preset to instantly add common Sri Lankan retail messages:",
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 8),

        // Quick Preset Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _footerPresets.map((preset) {
            return ActionChip(
              label: Text(preset['label']!, style: const TextStyle(fontSize: 12)),
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
              onPressed: () => _applyFooterPreset(preset['text']!),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),
        _input(
          "Custom Footer Message", 
          _footerMsgCtrl, 
          Icons.message, 
          maxLines: 2, 
          hint: "e.g. ස්තූතියි! නැවත එන්න. / Thank You! Come Again.",
        ),
        _input(
          "Additional Contact / Social Info", 
          _contactInfoCtrl, 
          Icons.contact_phone, 
          hint: "e.g. WhatsApp: 077xxxxxxx | Web: www.myshop.lk",
        ),

        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _save(user),
            icon: const Icon(Icons.save),
            label: const Text("SAVE RECEIPT SETTINGS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.cyanAccent : const Color(0xFF2563EB),
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveThermalPreview(bool isDark) {
    final shopName = _shopNameCtrl.text.trim().isEmpty ? "POS Podda Store" : _shopNameCtrl.text.trim();
    final address = _shopAddressCtrl.text.trim();
    final phone = _shopMobileCtrl.text.trim();
    final regNo = _vatNumberCtrl.text.trim();
    final footerMsg = _footerMsgCtrl.text.trim().isEmpty ? "Thank You! Come Again." : _footerMsgCtrl.text.trim();
    final contact = _contactInfoCtrl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Live Thermal Receipt Preview", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.cyanAccent),
            ),
            // Roll Width Toggle for Preview
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '80mm', label: Text('80mm')),
                ButtonSegment(value: '58mm', label: Text('58mm')),
              ],
              selected: {_previewRollSize},
              onSelectionChanged: (val) => setState(() => _previewRollSize = val.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Simulated Paper Receipt Card
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: _previewRollSize == '58mm' ? 14 : 20, 
            vertical: 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Store Name
              Text(
                shopName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),

              if (address.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  address,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ],

              if (phone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  "Tel: $phone",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ],

              if (_isVatRegistered) ...[
                const SizedBox(height: 4),
                const Text(
                  "TAX INVOICE",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (regNo.isNotEmpty)
                  Text(
                    "VAT Reg No: $regNo",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
              ] else if (regNo.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  "Reg No: $regNo",
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 4),
              Text(
                "Bill #: INV-00421",
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                textAlign: TextAlign.center,
              ),
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                textAlign: TextAlign.center,
              ),

              const Divider(height: 20, thickness: 1),

              // Sample Items
              _previewItem("1 x White Bread 450g", "180.00"),
              _previewItem("2 x Highland Butter 200g", "1,500.00"),
              _previewItem("0.500kg x Keeri Samba", "130.00"),

              const Divider(height: 20, thickness: 1),

              // Totals
              _previewTotalRow("SUBTOTAL", "Rs. 1,810.00", isBold: false),
              if (_isVatRegistered) ...[
                _previewTotalRow("VAT (18% included)", "Rs. 276.10", isBold: false),
              ],
              _previewTotalRow("TOTAL", "Rs. 1,810.00", isBold: true, fontSize: 16),
              const SizedBox(height: 4),
              _previewTotalRow("Cash Tendered:", "Rs. 2,000.00", isBold: false, fontSize: 12),
              _previewTotalRow("Change Due:", "Rs. 190.00", isBold: true, fontSize: 13, color: Colors.green),

              const SizedBox(height: 12),
              // Simulated barcode
              Center(
                child: Container(
                  height: 24,
                  width: 140,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text("|| | |||| || | |||| ||", style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 2)),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 8, thickness: 0.5),

              // Custom Footer Message
              const SizedBox(height: 6),
              Text(
                footerMsg,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),

              if (contact.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  contact,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 8),
              Text(
                "Powered by POS Podda",
                style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewItem(String name, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
          Text(price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _previewTotalRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  Widget _header(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
    );
  }

  Widget _input(
    String label, 
    TextEditingController ctrl, 
    IconData icon, 
    {int maxLines = 1, String? hint, TextInputType? keyboardType}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}), // Live preview update
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white.withValues(alpha: 0.04) 
              : Colors.black.withValues(alpha: 0.02),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/features/inventory/simple_scanner_screen.dart';
import 'package:sme_buddy/features/inventory/product_dashboard_screen.dart'; // Added Import
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math'; 
import 'package:sme_buddy/utils/quantity_parser.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/features/subscription/subscription_guard.dart';
import 'package:sme_buddy/utils/barcode_utils.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/inventory/services/barcode_lookup_service.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final String? initialBarcode;
  final String? initialName;
  final double? initialPrice;
  final double? initialCost;

  const AddProductScreen({
    super.key,
    this.initialBarcode,
    this.initialName,
    this.initialPrice,
    this.initialCost,
  });

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form Keys
  final _unitFormKey = GlobalKey<FormState>();
  final _measurableFormKey = GlobalKey<FormState>();
  final _serviceFormKey = GlobalKey<FormState>();

  // TEXT CONTROLLERS
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  
  // Unit Tab Controllers
  final _unitPriceController = TextEditingController();
  final _unitCostController = TextEditingController();
  final _unitStockController = TextEditingController();
  final _unitLowStockController = TextEditingController(); // NEW

  // Measurable Tab Controllers
  final _measPriceController = TextEditingController();
  final _measCostController = TextEditingController();
  final _measStockController = TextEditingController();
  final _measLowStockController = TextEditingController(); // NEW

  // Service Tab Controllers
  final _servicePriceController = TextEditingController();
  
  // STATE
  bool _isVariablePrice = false;
  bool _isTaxable = true;
  bool _isLoading = false;
  bool _isLookingUpBarcode = false;
  String? _lookupMessage;
  String _measureType = 'weight'; // weight (Kg), volume (L), length (M)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      _barcodeController.text = widget.initialBarcode!;
    }
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _nameController.text = widget.initialName!;
    }
    if (widget.initialPrice != null && widget.initialPrice! > 0) {
      _unitPriceController.text = widget.initialPrice!.toStringAsFixed(2);
    }
    if (widget.initialCost != null && widget.initialCost! > 0) {
      _unitCostController.text = widget.initialCost!.toStringAsFixed(2);
    }
    if (widget.initialBarcode != null && (widget.initialName == null || widget.initialName!.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performBarcodeLookup(widget.initialBarcode!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _unitPriceController.dispose();
    _unitCostController.dispose();
    _unitStockController.dispose();
    _unitLowStockController.dispose();
    _measPriceController.dispose();
    _measCostController.dispose();
    _measStockController.dispose();
    _measLowStockController.dispose();
    _servicePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassScaffold(
      appBar: AppBar(
        title: Text("Add New Product", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.cyanAccent : Colors.blueAccent,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          indicatorColor: isDark ? Colors.cyanAccent : Colors.blueAccent,
          tabs: const [
             Tab(icon: Icon(Icons.numbers_outlined), text: "Standard Unit"),
             Tab(icon: Icon(Icons.scale_outlined), text: "Measurable Item"),
             Tab(icon: Icon(Icons.cleaning_services), text: "Service"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUnitForm(),
          _buildMeasurableForm(),
          _buildServiceForm(),
        ],
      ),
    );
  }

  // --- REUSABLE CARD STYLES ---
  // --- REUSABLE CARD STYLES ---
  Widget _buildPremiumCard({required List<Widget> children, required String title, IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           Row(
             children: [
               if(icon != null) ...[Icon(icon, color: isDark ? Colors.cyanAccent : Colors.blueAccent, size: 20), const SizedBox(width: 8)],
               Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
             ],
           ),
           const SizedBox(height: 16),
           ...children
        ],
      ),
    );
  }

  // --- TAB 1: UNIT PER ITEM ---
  Widget _buildUnitForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _unitFormKey,
        child: Column(
          children: [
            _buildCommonSection(),
            
            _buildPremiumCard(
              title: "Inventory",
              icon: Icons.inventory,
              children: [
                _buildTextField(_unitLowStockController, "Low Stock Alert", suffix: "Units", isNumber: true, hint: "Default: 5", isRequired: false),
                const SizedBox(height: 8),
                const Text("Note: Add Stock & Price in the next step (Receive Stock).", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
            
            const SizedBox(height: 20),
            _buildSaveButton("SAVE STANDARD PRODUCT", () => _saveProduct(isMeasurable: false)),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: MEASURABLE (SMART CONVERSION) ---
  Widget _buildMeasurableForm() {
    String unitLabel = "";
    if (_measureType == 'weight') { unitLabel = "KG"; }
    else if (_measureType == 'volume') { unitLabel = "Liters"; }
    else { unitLabel = "Meters"; }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _measurableFormKey,
        child: Column(
          children: [
            _buildCommonSection(),
            
            _buildPremiumCard(
              title: "Measurement Details",
              icon: Icons.info_outline,
              children: [
                 DropdownButtonFormField<String>(
                  value: _measureType,
                  decoration: const InputDecoration(labelText: "Measurement Type", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                  items: const [
                    DropdownMenuItem(value: 'weight', child: Text("Weight (Sold in KG)")),
                    DropdownMenuItem(value: 'volume', child: Text("Volume (Sold in Liters)")),
                    DropdownMenuItem(value: 'length', child: Text("Length (Sold in Meters)")),
                  ],
                  onChanged: (val) => setState(() => _measureType = val!),
                ),
              ],
            ),

            _buildPremiumCard(
              title: "Inventory",
              icon: Icons.inventory,
              children: [
                 _buildTextField(
                   _measLowStockController, 
                   "Low Stock Alert Level", 
                   suffix: "e.g. 1kg 500g", 
                   isNumber: false, // Allow text like '1kg'
                   isRequired: false,
                   helper: "Notify when stock drops below this amount"
                 ),
                 const SizedBox(height: 8),
                 const Text("Note: Add Stock & Price in the next step (Receive Stock).", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          
            const SizedBox(height: 20),
            _buildSaveButton("SAVE MEASURABLE PRODUCT", () => _saveProduct(isMeasurable: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _serviceFormKey,
        child: Column(
          children: [
            _buildCommonSection(),
            
            _buildPremiumCard(
              title: "Pricing & Details",
              icon: Icons.monetization_on_outlined,
              children: [
                if (!_isVariablePrice)
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(_servicePriceController, "Selling Price", prefix: "Rs. ", isNumber: true),
                      ),
                      const SizedBox(width: 16),
                      // Add Cost Price for Services (Labor/Overhead)
                      Expanded(
                         child: _buildTextField(_unitCostController, "Cost Price", prefix: "Rs. ", isNumber: true, isRequired: false, helper: "For profit calc"),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 16),
                
                SwitchListTile(
                   title: const Text("Variable Price?"),
                   subtitle: const Text("Enter price manually at checkout (e.g. Repair jobs)"),
                   value: _isVariablePrice,
                   activeColor: Colors.cyanAccent,
                   contentPadding: EdgeInsets.zero,
                   onChanged: (val) {
                      setState(() {
                         _isVariablePrice = val;
                         if (val) _servicePriceController.clear();
                      });
                   },
                ),

                if (_isVariablePrice)
                  Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                     child: const Row(
                       children: [
                         Icon(Icons.info, color: Colors.blue),
                         SizedBox(width: 8),
                         Expanded(child: Text("Price will be entered manually during checkout.")),
                       ],
                     ),
                  )
              ],
            ),
            
            const SizedBox(height: 20),
            _buildSaveButton("SAVE SERVICE", _saveService),
          ],
        ),
      ),
    );
  }

  Future<void> _saveService() async {
    // 0. Subscription Check
    if (!await SubscriptionGuard.check(context, ref, SubscriptionAction.addItem)) return;

    if (_serviceFormKey.currentState!.validate()) {
       double selling = _isVariablePrice ? 0.0 : double.parse(_servicePriceController.text);
       double cost = double.tryParse(_unitCostController.text) ?? 0.0;

       Future<void> executeSave() async {
          setState(() => _isLoading = true);
          try {
            if (_barcodeController.text.isNotEmpty) {
               final existing = await ref.read(productRepositoryProvider).getProductByBarcode(_barcodeController.text);
               if (existing != null) {
                  throw "Barcode already exists for '${existing.name}'";
               }
            }
   
           final product = Product(
             id: '',
             name: _nameController.text,
             sellingPrice: selling,
             costPrice: cost, 
             currentStock: 0.0, 
             stockType: 'service',
             productType: 'SERVICE',
             isVariablePrice: _isVariablePrice, 
             barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
             createdAt: DateTime.now(),
           );
           final newProduct = await ref.read(productRepositoryProvider).addProduct(product);
           if (mounted) {
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProductDashboardScreen(product: newProduct)));
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Service Added!"), backgroundColor: Colors.green));
           }
          } catch (e) {
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString().replaceAll("Exception: ", "")}"), backgroundColor: Colors.red));
                setState(() => _isLoading = false);
             }
          }
       }

       // VALIDATION
       if (!_isVariablePrice && selling < cost) {
          showDialog(
             context: context,
             builder: (c) => AlertDialog(
                title: const Text("Check Pricing"),
                content: const Text("The Selling Price is lower than the Cost (Optional).\nDo you want to continue?"),
                actions: [
                   TextButton(onPressed: () => Navigator.pop(c), child: const Text("EDIT")),
                   ElevatedButton(
                      onPressed: () {
                         Navigator.pop(c);
                         executeSave();
                      }, 
                      child: const Text("CONTINUE")
                   ),
                ],
             )
          );
       } else {
          executeSave();
       }
    }
  }

  /* Removed stray brace/comment block */
  Widget _buildCommonSection() {
    return Column(
      children: [
        _buildPremiumCard(
          title: "Product Info",
          icon: Icons.inventory_2_outlined,
          children: [
             _buildTextField(_nameController, "Product Name", hint: "e.g. Anchor Milk Powder"),
             const SizedBox(height: 12),
             SwitchListTile(
               title: const Text("Taxable Item (VAT Applicable)"),
               subtitle: const Text("Uncheck for exempt items (e.g. Dhal, Milk)"),
               value: _isTaxable,
               activeColor: Colors.cyanAccent,
               contentPadding: EdgeInsets.zero,
               onChanged: (val) => setState(() => _isTaxable = val),
             ),
          ]
        ),
        
        _buildPremiumCard(
          title: "Barcode Settings",
          icon: Icons.qr_code_2,
          children: [
             Row(
               children: [
                  Expanded(
                    child: _buildTextField(
                      _barcodeController, 
                      "Barcode", 
                      hint: "Scan or Generate",
                      onChanged: (val) => setState((){}),
                      suffixIcon: _barcodeController.text.isNotEmpty 
                         ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _barcodeController.clear()))
                         : null
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.camera_alt),
                    tooltip: "Scan",
                  ),
               ],
             ),
             const SizedBox(height: 12),
             Row(
               children: [
                 Expanded(
                   child: OutlinedButton.icon(
                     onPressed: _barcodeController.text.isEmpty ? _generateBarcode : null,
                     icon: const Icon(Icons.autorenew),
                     label: const Text("Generate"),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: OutlinedButton.icon(
                     onPressed: (_barcodeController.text.isNotEmpty && !_isLookingUpBarcode)
                         ? () => _performBarcodeLookup(_barcodeController.text)
                         : null,
                     icon: _isLookingUpBarcode
                         ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                         : const Icon(Icons.travel_explore),
                     label: const Text("Auto-Fill"),
                   ),
                 ),
                 const SizedBox(width: 8),
                 IconButton.outlined(
                   onPressed: _barcodeController.text.isNotEmpty ? () => _printBarcode(_barcodeController.text) : null,
                   icon: const Icon(Icons.print),
                   tooltip: "Print Label",
                 ),
               ],
             ),
             if (_isLookingUpBarcode) ...[
               const SizedBox(height: 8),
               const LinearProgressIndicator(minHeight: 2),
               const SizedBox(height: 4),
               const Text("Searching Sri Lanka catalog & online database...", style: TextStyle(fontSize: 12, color: Colors.cyanAccent)),
             ] else if (_lookupMessage != null) ...[
               const SizedBox(height: 8),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                 decoration: BoxDecoration(
                   color: Colors.cyan.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                 ),
                 child: Row(
                   children: [
                     const Icon(Icons.info_outline, size: 16, color: Colors.cyanAccent),
                     const SizedBox(width: 6),
                     Expanded(
                       child: Text(
                         _lookupMessage!,
                         style: const TextStyle(fontSize: 12, color: Colors.cyanAccent),
                         maxLines: 2,
                         overflow: TextOverflow.ellipsis,
                       ),
                     ),
                   ],
                 ),
               ),
             ]
          ]
        )
      ],
    );
  }

  // --- HELPERS ---

  Widget _buildTextField(TextEditingController controller, String label, {String? hint, String? prefix, String? suffix, bool isNumber = false, String? helper, Widget? suffixIcon, Function(String)? onChanged, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      onTap: isNumber ? () {
         if (controller.text == '0.00' || controller.text == '0') controller.clear();
      } : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        suffixText: suffix,
        helperText: helper,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.grey[50],
      ),
      validator: (v) => isRequired && (v == null || v.isEmpty) ? "Required" : null,
    );
  }

  Widget _buildSaveButton(String text, VoidCallback onPressed) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyanAccent, 
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: Colors.cyanAccent.withValues(alpha: 0.4),
        ),
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
    );
  }

  // --- LOGIC ---

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const SimpleScannerScreen()));
    if (result != null && result.isNotEmpty) {
      setState(() => _barcodeController.text = result);
      await _performBarcodeLookup(result);
    }
  }

  Future<void> _performBarcodeLookup(String barcode) async {
    final clean = barcode.trim();
    if (clean.length < 4) return;

    setState(() {
      _isLookingUpBarcode = true;
      _lookupMessage = "Searching catalog & online database...";
    });

    try {
      final lookupService = ref.read(barcodeLookupServiceProvider);
      final result = await lookupService.lookup(clean);
      if (!mounted) return;

      if (result != null) {
        setState(() {
          if (_nameController.text.trim().isEmpty) {
            _nameController.text = result.name;
          }
          if (_unitPriceController.text.trim().isEmpty && result.suggestedPrice != null) {
            _unitPriceController.text = result.suggestedPrice!.toStringAsFixed(2);
          }
          if (_unitCostController.text.trim().isEmpty && result.suggestedCost != null) {
            _unitCostController.text = result.suggestedCost!.toStringAsFixed(2);
          }
          _lookupMessage = "Found in ${result.source}: ${result.name}";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Auto-filled: ${result.name} (${result.source})",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _lookupMessage = "No match found in catalog (enter details manually)";
        });
      }
    } catch (_) {
      if (mounted) setState(() => _lookupMessage = null);
    } finally {
      if (mounted) setState(() => _isLookingUpBarcode = false);
    }
  }

  void _generateBarcode() {
    final user = ref.read(userProfileProvider).value;
    setState(() {
      _barcodeController.text = BarcodeUtils.generateStoreBarcode(user?.shopId);
    });
  }

  Future<void> _printBarcode(String barcodeData) async {
     // Generate PDF
     final pdf = pw.Document();
     final productName = _nameController.text.isEmpty ? "Product" : _nameController.text;

     pdf.addPage(
       pw.Page(
         pageFormat: PdfPageFormat.roll80, // Receipt style width
         build: (pw.Context context) {
           return pw.Center(
             child: pw.Column(
               mainAxisSize: pw.MainAxisSize.min,
               children: [
                 pw.Text(productName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                 pw.SizedBox(height: 5),
                 pw.BarcodeWidget(
                   data: barcodeData,
                   barcode: pw.Barcode.code128(),
                   width: 150,
                   height: 50,
                 ),
                 pw.SizedBox(height: 5),
                 pw.Text(barcodeData, style: const pw.TextStyle(fontSize: 8)),
               ],
             )
           );
         }
       )
     );

     await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _saveProduct({required bool isMeasurable}) async {
    // 0. Subscription Check
    if (!await SubscriptionGuard.check(context, ref, SubscriptionAction.addItem)) return;

    // Shared Barcode Check
    // Shared Barcode Check
    setState(() => _isLoading = true);
    
    try {
      if (_barcodeController.text.isNotEmpty) {
         final existing = await ref.read(productRepositoryProvider).getProductByBarcode(_barcodeController.text);
         if (existing != null) {
            throw "Barcode already exists for '${existing.name}'";
         }
      }

      if (isMeasurable) {
        if (_measurableFormKey.currentState!.validate()) {
           String baseUnit = _measureType == 'weight' ? 'g' : (_measureType == 'volume' ? 'ml' : 'cm');

           // Smart Parse Low Stock
           double lowStockInBase = 0.0;
           if (_measLowStockController.text.isNotEmpty) {
              lowStockInBase = QuantityParser.parse(_measLowStockController.text, baseUnit);
           }

           final product = Product(
             id: '',
             name: _nameController.text,
             sellingPrice: 0.0, // Set later via Batch
             costPrice: 0.0,    // Set later via Batch
             currentStock: 0.0, // Set later via Batch
             stockType: 'weight', // Model uses 'weight' for any measurable
             baseUnit: baseUnit,
             lowStockThreshold: lowStockInBase > 0 ? lowStockInBase : null,
             barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
             buyingOptions: [],
             isTaxable: _isTaxable,
             createdAt: DateTime.now(),
           );
           
           final newProduct = await ref.read(productRepositoryProvider).addProduct(product);
           if (mounted) {
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProductDashboardScreen(product: newProduct)));
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Measurable Product Created. Now Add Stock!"), backgroundColor: Colors.green));
           }
        } else {
           setState(() => _isLoading = false);
        }
      } else {
        if (_unitFormKey.currentState!.validate()) {
           final product = Product(
             id: '',
             name: _nameController.text,
             sellingPrice: 0.0, // Set later via Batch
             costPrice: 0.0,    // Set later via Batch
             currentStock: 0.0, // Set later via Batch
             stockType: 'unit',
             lowStockThreshold: double.tryParse(_unitLowStockController.text),
             barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
             createdAt: DateTime.now(),
           );
           final newProduct = await ref.read(productRepositoryProvider).addProduct(product);
           if (mounted) {
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProductDashboardScreen(product: newProduct)));
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Created. Now Add Stock!"), backgroundColor: Colors.green));
           }
        } else {
           setState(() => _isLoading = false);
        }
      }
    } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString().replaceAll("Exception: ", "")}"), backgroundColor: Colors.red));
          setState(() => _isLoading = false);
       }
    }
  }
}

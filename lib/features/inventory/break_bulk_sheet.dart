import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/inventory/product_repository.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/unit_formatter.dart';
import 'package:sme_buddy/utils/barcode_utils.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/home/product_search_delegate.dart';

class BreakBulkSheet extends ConsumerStatefulWidget {
  final Product sourceProduct;

  const BreakBulkSheet({super.key, required this.sourceProduct});

  @override
  ConsumerState<BreakBulkSheet> createState() => _BreakBulkSheetState();
}

class _BreakBulkSheetState extends ConsumerState<BreakBulkSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // SHARED STATE
  final _sourceQtyController = TextEditingController(text: "1");
  final _targetQtyController = TextEditingController(); // Ratio validation
  
  // EXISTING TAB STATE
  Product? _selectedTarget;
  final _existingPriceController = TextEditingController(); // NEW for custom selling price

  // NEW PRODUCT TAB STATE
  final _newNameController = TextEditingController();
  final _newBarcodeController = TextEditingController(); // NEW Barcode Controller
  final _newPriceController = TextEditingController();
  final _newUnitController = TextEditingController(text: "unit"); // Default unit
  String _calculatedCostPreview = "0.00";

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Listeners for Cost Calculation
    _sourceQtyController.addListener(_calculateCost);
    _targetQtyController.addListener(_calculateCost);
  }

  void _calculateCost() {
    double srcQty = double.tryParse(_sourceQtyController.text) ?? 0;
    double tgtQty = double.tryParse(_targetQtyController.text) ?? 0;
    
    if (srcQty > 0 && tgtQty > 0) {
      double totalCostTransferred = widget.sourceProduct.costPrice * srcQty;
      double costPerTargetUnit = totalCostTransferred / tgtQty;
      
      setState(() {
        _calculatedCostPreview = costPerTargetUnit.toStringAsFixed(2);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
       height: MediaQuery.of(context).size.height * 0.9, // Increased height slightly
       decoration: BoxDecoration(
         color: isDark ? Colors.grey[900] : Colors.white,
         borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
       ),
       child: Column(
         children: [
           const SizedBox(height: 12),
           Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
           const SizedBox(height: 16),
           
           // Header
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 24),
             child: Row(
               children: [
                 Icon(Icons.call_split_rounded, color: Colors.cyanAccent, size: 28),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text("Break Bulk / Split Stock", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                       Text("Source: ${widget.sourceProduct.name}", style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
                     ],
                   )
                 ),
                 IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
               ],
             ),
           ),
           
           const SizedBox(height: 16),
           TabBar(
             controller: _tabController,
             indicatorColor: Colors.cyanAccent,
             labelColor: isDark ? Colors.white : Colors.black,
             tabs: const [
               Tab(text: "Convert to Existing"),
               Tab(text: "Create New Item"),
             ]
           ),
           
           Expanded(
             child: TabBarView(
               controller: _tabController,
               children: [
                 _buildExistingTab(isDark),
                 _buildNewTab(isDark),
               ],
             ),
           ),
         ],
       ),
    );
  }

  Widget _buildExistingTab(bool isDark) {
    final productsAsync = ref.watch(productsStreamProvider);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TARGET SELECTOR
          productsAsync.when(
            data: (products) {
               final candidates = products.where((p) => p.id != widget.sourceProduct.id && p.productType != 'SERVICE').toList();
               
               return Column(
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   InkWell(
                     onTap: () async {
                       final selected = await showSearch<Product?>(
                         context: context, 
                         delegate: ProductSearchDelegate(candidates)
                       );
                       if (selected != null) {
                         setState(() {
                           _selectedTarget = selected;
                           // Pre-fill price with current selling price of target
                           _existingPriceController.text = selected.sellingPrice.toStringAsFixed(2); 
                         });
                       }
                     },
                     borderRadius: BorderRadius.circular(12),
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(12),
                         color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                         border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
                       ),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(
                             _selectedTarget?.name ?? "Select Target Product",
                             style: TextStyle(
                               color: _selectedTarget == null 
                                 ? (isDark ? Colors.white54 : Colors.black54)
                                 : (isDark ? Colors.white : Colors.black),
                               fontSize: 16,
                               fontWeight: _selectedTarget != null ? FontWeight.bold : FontWeight.normal
                             ),
                           ),
                           const Icon(Icons.search, color: Colors.blueAccent),
                         ],
                       ),
                     ),
                   ),
                   if (_selectedTarget != null)...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _existingPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Selling Price of New Batch",
                          prefixText: "Rs. ",
                          border: OutlineInputBorder(),
                          helperText: "Leave default or change for this specific conversion"
                        ),
                      ),
                   ]
                 ],
               );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_,__) => const Text("Error loading products"),
          ),
          
          const SizedBox(height: 24),
          _buildRatioInputs(isDark),
          
          const Spacer(),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitExisting,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              child: _isLoading ? const CircularProgressIndicator() : const Text("CONVERT STOCK"),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNewTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // NEW DETAILS
          TextField(
            controller: _newNameController,
            decoration: const InputDecoration(labelText: "New Item Name (e.g. Single Sheet)", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          // Barcode Input
          TextField(
            controller: _newBarcodeController,
            decoration: InputDecoration(
                labelText: "Barcode (Optional)", 
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.autorenew, color: Colors.blueAccent),
                      tooltip: "Generate Store Unique",
                      onPressed: () {
                         final user = ref.read(userProfileProvider).value;
                         _newBarcodeController.text = BarcodeUtils.generateStoreBarcode(user?.shopId);
                      }
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: "Scan",
                      onPressed: () {
                         // TODO: Implement Scanner or simple random generator
                         // For now, simple random gen
                         String code = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
                         _newBarcodeController.text = code;
                      }
                    ),
                  ],
                )
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Selling Price", prefixText: "Rs. ", border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _newUnitController,
                  decoration: const InputDecoration(labelText: "Unit (e.g. unit/g)", border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          _buildRatioInputs(isDark),
          
          const SizedBox(height: 16),
          // AUTO COST PREVIEW
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                 const Icon(Icons.auto_graph, color: Colors.green),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text("Auto-Calculated Unit Cost", style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                       Text("Rs. $_calculatedCostPreview", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                     ],
                   ),
                 )
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitNew,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              child: _isLoading ? const CircularProgressIndicator() : const Text("CREATE & CONVERT"),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRatioInputs(bool isDark) {
     return Row(
       children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Take FROM Source", style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                const SizedBox(height: 4),
                TextField(
                  controller: _sourceQtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                     filled: true,
                     fillColor: Colors.orange.withValues(alpha: 0.1),
                     border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
                     suffixText: widget.sourceProduct.baseUnit ?? 'Unit'
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Icon(Icons.arrow_forward, color: isDark ? Colors.white24 : Colors.black26),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Create INTO Target", style: TextStyle(fontSize: 11, color: Colors.greenAccent)),
                const SizedBox(height: 4),
                TextField(
                  controller: _targetQtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                     hintText: "?",
                     filled: true,
                     fillColor: Colors.green.withValues(alpha: 0.1),
                     border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
       ],
     );
  }

  Future<void> _submitExisting() async {
    if (_selectedTarget == null || _sourceQtyController.text.isEmpty || _targetQtyController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      double? customPrice;
      if (_existingPriceController.text.isNotEmpty) {
         customPrice = double.tryParse(_existingPriceController.text);
      }

      await ref.read(productRepositoryProvider).breakBulk(
        widget.sourceProduct.id,
        _selectedTarget!.id,
        double.parse(_sourceQtyController.text),
        double.parse(_targetQtyController.text),
        newSellingPrice: customPrice
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Converted Successfully"), backgroundColor: Colors.green));
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitNew() async {
    if (_newNameController.text.isEmpty || _sourceQtyController.text.isEmpty || _targetQtyController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      double srcQty = double.parse(_sourceQtyController.text);
      double tgtQty = double.parse(_targetQtyController.text);
      double costPrice = double.parse(_calculatedCostPreview);
      
      final newProduct = Product(
         id: '', // Repo generates
         name: _newNameController.text,
         barcode: _newBarcodeController.text.isEmpty ? null : _newBarcodeController.text, // Add Barcode
         sellingPrice: double.tryParse(_newPriceController.text) ?? 0.0,
         costPrice: costPrice,
         stockType: 'unit', // Default simple unit for broken bulk
         baseUnit: _newUnitController.text,
         currentStock: 0, // Will be filled by breakBulk logic or direct add
         isActive: true,
         productType: 'PHYSICAL',
         createdAt: DateTime.now(),
      );

      // We need a specialized repo method for "Create Product AND Break Bulk into it"
      // Or we do it in two steps (Create with 0 stock, then Break).
      // Two steps is safer for existing APIs.
      
      final createdProduct = await ref.read(productRepositoryProvider).addProduct(newProduct);
      
      await ref.read(productRepositoryProvider).breakBulk(
        widget.sourceProduct.id,
        createdProduct.id,
        srcQty,
        tgtQty,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Created & Converted Successfully"), backgroundColor: Colors.green));
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }
}

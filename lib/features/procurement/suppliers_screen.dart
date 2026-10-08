import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/procurement/procurement_repository.dart';
import 'package:sme_buddy/features/procurement/supplier_model.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/responsive_layout.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showSupplierDialog({SupplierModel? supplier}) {
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final companyCtrl = TextEditingController(text: supplier?.companyName ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final emailCtrl = TextEditingController(text: supplier?.email ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final notesCtrl = TextEditingController(text: supplier?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: Text(
            supplier == null ? "Add Supplier" : "Edit Supplier",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Supplier / Contact Name *",
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6366F1)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? "Name is required" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: companyCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Company / Business Name",
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        prefixIcon: const Icon(Icons.business_outlined, color: Color(0xFF6366F1)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Phone Number",
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF6366F1)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Email Address",
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6366F1)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Office / Delivery Address",
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF6366F1)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Notes / Payment Terms",
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        prefixIcon: const Icon(Icons.note_alt_outlined, color: Color(0xFF6366F1)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => isSaving = true);
                      try {
                        final toSave = SupplierModel(
                          id: supplier?.id ?? '',
                          name: nameCtrl.text.trim(),
                          companyName: companyCtrl.text.trim().isEmpty ? null : companyCtrl.text.trim(),
                          phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                          address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          isActive: true,
                          createdAt: supplier?.createdAt ?? DateTime.now(),
                        );
                        await ref.read(procurementRepositoryProvider).saveSupplier(toSave);
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(supplier == null ? "Supplier created" : "Supplier updated"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(supplier == null ? "Add Supplier" : "Save Changes",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(SupplierModel supplier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Remove Supplier?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Are you sure you want to remove '${supplier.name}'? Past records and purchase notes will remain intact.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(procurementRepositoryProvider).deleteSupplier(supplier.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Supplier removed"), backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text("Remove", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return GlassScaffold(
      appBar: AppBar(
        title: const Text("Suppliers Directory", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => _showSupplierDialog(),
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: "Add Supplier",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        onPressed: () => _showSupplierDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NEW SUPPLIER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search & Filter bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search suppliers by name, company, or phone...",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),
          ),

          // Suppliers List / Grid
          Expanded(
            child: suppliersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
              error: (err, _) => Center(
                child: Text("Error: $err", style: const TextStyle(color: Colors.redAccent)),
              ),
              data: (suppliers) {
                final filtered = suppliers.where((s) {
                  if (_searchQuery.isEmpty) return true;
                  final matchName = s.name.toLowerCase().contains(_searchQuery);
                  final matchCompany = s.companyName?.toLowerCase().contains(_searchQuery) ?? false;
                  final matchPhone = s.phone?.toLowerCase().contains(_searchQuery) ?? false;
                  return matchName || matchCompany || matchPhone;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? "No suppliers found yet"
                              : "No suppliers match '$_searchQuery'",
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                          onPressed: () => _showSupplierDialog(),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text("Add First Supplier", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }

                if (isDesktop) {
                  // Grid Layout on Desktop
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 450,
                      mainAxisExtent: 220,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _buildSupplierCard(filtered[i]),
                  );
                }

                // List Layout on Mobile/Tablet
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildSupplierCard(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierCard(SupplierModel s) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                child: Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : "S",
                  style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.companyName != null && s.companyName!.isNotEmpty)
                      Text(
                        s.companyName!,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                color: const Color(0xFF1E293B),
                onSelected: (val) {
                  if (val == 'edit') _showSupplierDialog(supplier: s);
                  if (val == 'delete') _confirmDelete(s);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text("Edit", style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8),
                        Text("Remove", style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          if (s.phone != null && s.phone!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 15, color: Colors.cyanAccent),
                  const SizedBox(width: 6),
                  Text(s.phone!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          if (s.email != null && s.email!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, size: 15, color: Colors.amberAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.email!,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (s.address != null && s.address!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: Colors.white54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.address!,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (s.notes != null && s.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                s.notes!,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

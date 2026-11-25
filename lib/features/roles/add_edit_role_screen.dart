import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/roles/role_model.dart';
import 'package:sme_buddy/features/roles/role_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:uuid/uuid.dart';

class AddEditRoleScreen extends ConsumerStatefulWidget {
  final String shopId;
  final RoleModel? role; // null = new

  const AddEditRoleScreen({super.key, required this.shopId, this.role});

  @override
  ConsumerState<AddEditRoleScreen> createState() => _AddEditRoleScreenState();
}

class _AddEditRoleScreenState extends ConsumerState<AddEditRoleScreen> {
  final _nameCtrl = TextEditingController();
  final Map<String, bool> _permissions = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.role != null) {
      _nameCtrl.text = widget.role!.name;
      _permissions.addAll(widget.role!.permissions);
    }
  }

  void _save() async {
    if (_nameCtrl.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Role Name Required")));
       return;
    }
    
    setState(() => _isLoading = true);
    try {
      final roleId = widget.role?.id ?? const Uuid().v4();
      final newRole = RoleModel(
        id: roleId,
        shopId: widget.shopId,
        name: _nameCtrl.text.trim(),
        permissions: _permissions,
      );

      await ref.read(roleRepositoryProvider).saveRole(newRole);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _delete() async {
     if (widget.role == null) return;
     setState(() => _isLoading = true);
     try {
       await ref.read(roleRepositoryProvider).deleteRole(widget.shopId, widget.role!.id);
       if(mounted) Navigator.pop(context);
     } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        if (mounted) setState(() => _isLoading = false);
     }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.role != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Role" : "New Role"),
        actions: [
          if (isEditing) 
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _isLoading ? null : _delete),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: "Role Name (e.g. Manager)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            const Align(alignment: Alignment.centerLeft, child: Text("Role Permissions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const Text("Define what actions users assigned to this role can perform.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),

            _buildSection("Sales & POS Operations", [
              AppPermissions.canCheckout,
              AppPermissions.canGiveDiscount,
            ]),
            _buildSection("Inventory, Cost Privacy & Procurement", [
              AppPermissions.canManageInventory,
              AppPermissions.canAddProducts,
              AppPermissions.canDeleteProducts,
              AppPermissions.canViewCostPrice,
              AppPermissions.canManageGRN,
            ]),
            _buildSection("Cash Balancing, Shifts & Analytics", [
              AppPermissions.canManageShifts,
              AppPermissions.canViewSalesReports,
            ]),
            _buildSection("Customer Credit (Potha) & CRM", [
              AppPermissions.canViewCredit,
              AppPermissions.canEditCreditors,
              AppPermissions.canSettleCredit,
            ]),
            _buildSection("Staff Management", [
              AppPermissions.canViewEmployees,
              AppPermissions.canAddEmployees,
              AppPermissions.canEditEmployees,
              AppPermissions.canDeleteEmployees,
            ]),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading ? const CircularProgressIndicator() : Text(isEditing ? "UPDATE ROLE" : "CREATE ROLE"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> permissionKeys) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8, color: Color(0xFF818CF8)),
            ),
          ),
          ...permissionKeys.map((key) {
            return CheckboxListTile(
              dense: true,
              title: Text(AppPermissions.getLabel(key), style: const TextStyle(fontSize: 14)),
              value: _permissions[key] ?? false,
              onChanged: (val) {
                setState(() {
                  _permissions[key] = val ?? false;
                });
              },
            );
          }),
        ],
      ),
    );
  }
}

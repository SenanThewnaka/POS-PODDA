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
            const Align(alignment: Alignment.centerLeft, child: Text("Permissions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const Text("What can users with this role do?", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),

            ...AppPermissions.allValues.map((key) {
               return CheckboxListTile(
                 title: Text(AppPermissions.getLabel(key)),
                 value: _permissions[key] ?? false,
                 onChanged: (val) {
                    setState(() {
                       _permissions[key] = val ?? false;
                    });
                 },
               );
            }).toList(),

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
}

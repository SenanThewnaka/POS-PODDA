import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/features/users/edit_employee_screen.dart';
import 'package:sme_buddy/features/roles/role_list_screen.dart';
import 'package:sme_buddy/features/roles/role_model.dart';
import 'package:sme_buddy/features/roles/role_repository.dart';

class EmployeeManagementScreen extends ConsumerWidget {
  const EmployeeManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: "Manage Roles",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleListScreen())),
            )
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Active Team"),
              Tab(text: "Inactive / Past"),
            ],
          ),
        ),
        body: userAsync.when(
          data: (currentUser) {
            if (currentUser == null) return const SizedBox();
            if (!currentUser.isAdmin && !currentUser.hasPermission(AppPermissions.canViewEmployees)) {
               return const Center(child: Text("Access Denied: Insufficient Permissions"));
            }
            
            return _EmployeeContent(currentUser: currentUser);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e,st) => Center(child: Text("Error: $e")),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
             // Add Employee
             userAsync.whenData((user) {
               if (user != null && (user.isAdmin || user.hasPermission(AppPermissions.canAddEmployees))) {
                 showDialog(
                   context: context, 
                   builder: (_) => AddEmployeeDialog(
                      shopId: user.shopId, 
                      shopName: user.shopName ?? "Shop",
                      shopCode: user.shopCode ?? "", // Pass Code
                   ),
                 );
               } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You do not have permission to add employees")));
               }
             });
          },
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }
}

class _EmployeeContent extends ConsumerWidget {
  final UserModel currentUser;
  const _EmployeeContent({required this.currentUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch employees here
    final employeesAsync = ref.watch(shopEmployeesProvider(currentUser.shopId));

    return employeesAsync.when(
      data: (allEmployees) {
        // Split lists
        final active = allEmployees.where((e) => e.isActive).toList();
        final inactive = allEmployees.where((e) => !e.isActive).toList();

        return TabBarView(
          children: [
            _EmployeeList(employees: active, currentUser: currentUser, isInactiveList: false),
            _EmployeeList(employees: inactive, currentUser: currentUser, isInactiveList: true),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e,st) => Center(child: Text("Error: $e")),
    );
  }
}

class _EmployeeList extends ConsumerWidget {
  final List<UserModel> employees;
  final UserModel currentUser;
  final bool isInactiveList;

  const _EmployeeList({
    required this.employees, 
    required this.currentUser,
    required this.isInactiveList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (employees.isEmpty) {
      return Center(child: Text(isInactiveList ? "No inactive employees." : "No active employees."));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final emp = employees[index];
        if (emp.uid == currentUser.uid) return const SizedBox.shrink(); // Hide self

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isInactiveList ? Theme.of(context).disabledColor : null,
              child: Text(emp.name[0].toUpperCase()),
            ),
            title: Text(emp.name, style: TextStyle(decoration: isInactiveList ? TextDecoration.lineThrough : null)),
            subtitle: Text(emp.username != null ? "User: ${emp.username}" : emp.email),
            onTap: () {
               if (isInactiveList) return; // Cannot edit inactive
               
               if (currentUser.isAdmin || currentUser.hasPermission(AppPermissions.canEditEmployees)) {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => EditEmployeeScreen(employee: emp)));
               } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permission Denied: Cannot Edit Employees")));
               }
            },
            trailing: isInactiveList 
            ? IconButton( // REACTIVATE BUTTON
                icon: const Icon(Icons.restore_from_trash, color: Colors.green),
                tooltip: "Reactivate Employee",
                onPressed: () {
                   // Reactivate Logic
                   if (currentUser.isAdmin || currentUser.hasPermission(AppPermissions.canAddEmployees)) { // Using Add permission for reactivate essentially
                      _confirmAction(context, ref, emp, "Reactivate", "restored to active status", true);
                   } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permission Denied")));
                   }
                },
              )
            : IconButton( // DEACTIVATE BUTTON
                icon: Icon(Icons.delete, color: (currentUser.isAdmin || currentUser.hasPermission(AppPermissions.canDeleteEmployees)) ? Colors.red : Colors.grey),
                onPressed: () {
                   if (currentUser.isAdmin || currentUser.hasPermission(AppPermissions.canDeleteEmployees)) {
                      _confirmAction(context, ref, emp, "Deactivate", "deactivated", false);
                   } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permission Denied: Cannot Deactivate")));
                   }
                },
              ),
          ),
        );
      },
    );
  }

  void _confirmAction(BuildContext context, WidgetRef ref, UserModel emp, String actionName, String pastTense, bool isReactivating) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$actionName Employee?"),
        content: Text("Are you sure you want to $actionName ${emp.name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL")
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                 if (isReactivating) {
                   await ref.read(userProfileRepositoryProvider).reactivateUserProfile(emp.uid);
                 } else {
                   await ref.read(userProfileRepositoryProvider).deactivateUserProfile(emp.uid);
                 }
                 
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${emp.name} has been $pastTense.")));
                 }
              } catch (e) {
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                 }
              }
            },
            style: TextButton.styleFrom(foregroundColor: isReactivating ? Colors.green : Colors.red),
            child: Text(actionName.toUpperCase()),
          ),
        ],
      ),
    );
  }
}

// Temporary Provider for employees. 
// Ideally define in user_repository but creating here for colocation or modify repository.
final shopEmployeesProvider = StreamProvider.family<List<UserModel>, String>((ref, shopId) {
   return ref.watch(userProfileRepositoryProvider).getShopEmployees(shopId);
});

class AddEmployeeDialog extends ConsumerStatefulWidget {
  final String shopId;
  final String shopName;
  final String shopCode;
  const AddEmployeeDialog({super.key, required this.shopId, required this.shopName, required this.shopCode});

  @override
  ConsumerState<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends ConsumerState<AddEmployeeDialog> {
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedRoleId;
  String _selectedRoleName = 'Cashier';
  Map<String, bool> _permissions = Map.from(AppPermissions.defaultCashierPermissions);
  bool _isLoading = false;

  void _addEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final syntheticEmail = "${_usernameCtrl.text.trim().toLowerCase()}@${widget.shopCode.toLowerCase()}.sme";

      final repo = ref.read(authRepositoryProvider);
      final newUid = await repo.createEmployeeAccount(
        syntheticEmail, 
        _passCtrl.text.trim(),
      );
      
      if (newUid != null) {
        final newEmp = UserModel(
          uid: newUid,
          email: syntheticEmail,
          name: _nameCtrl.text.trim(),
          mobile: _mobileCtrl.text.trim(), 
          role: _selectedRoleName.toLowerCase(),
          roleId: _selectedRoleId,
          shopId: widget.shopId,
          shopName: widget.shopName,
          username: _usernameCtrl.text.trim(),
          storedPassword: _passCtrl.text.trim(),
          permissions: _permissions,
        );
        
        await ref.read(userProfileRepositoryProvider).saveUserProfile(newEmp);
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Employee '${newEmp.name}' added with role '$_selectedRoleName'!"))
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(shopRolesStreamProvider(widget.shopId));

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_add_alt_1, color: Color(0xFF6366F1)),
          SizedBox(width: 8),
          Text("Add Employee"),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Full Name *",
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? "Name is required" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobileCtrl, 
                  decoration: const InputDecoration(
                    labelText: "Mobile Number",
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ), 
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameCtrl, 
                  decoration: const InputDecoration(
                    labelText: "Username (Staff ID / Name) *",
                    prefixIcon: Icon(Icons.alternate_email),
                    border: OutlineInputBorder(),
                  ), 
                  validator: (v) => v == null || v.trim().isEmpty ? "Username is required" : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl, 
                  decoration: const InputDecoration(
                    labelText: "Initial Password *",
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ), 
                  obscureText: true,
                  validator: (v) => v == null || v.length < 6 ? "Minimum 6 characters" : null,
                ),
                const SizedBox(height: 16),

                // Role Selector
                const Text("ASSIGN ROLE TEMPLATE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                rolesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                  data: (customRoles) {
                    return DropdownButtonFormField<String>(
                      value: _selectedRoleId ?? _selectedRoleName,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF6366F1)),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: 'Cashier',
                          child: Text("Cashier (POS Checkout & Credit)"),
                        ),
                        const DropdownMenuItem(
                          value: 'Manager',
                          child: Text("Store Manager (Full Operations)"),
                        ),
                        const DropdownMenuItem(
                          value: 'Stock Keeper',
                          child: Text("Stock Keeper (Inventory & GRN)"),
                        ),
                        ...customRoles.map((r) => DropdownMenuItem(
                          value: r.id,
                          child: Text("${r.name} (Custom Role)"),
                        )),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          if (val == 'Cashier') {
                            _selectedRoleId = null;
                            _selectedRoleName = 'Cashier';
                            _permissions = Map.from(AppPermissions.defaultCashierPermissions);
                          } else if (val == 'Manager') {
                            _selectedRoleId = null;
                            _selectedRoleName = 'Manager';
                            _permissions = Map.from(AppPermissions.defaultManagerPermissions);
                          } else if (val == 'Stock Keeper') {
                            _selectedRoleId = null;
                            _selectedRoleName = 'Stock Keeper';
                            _permissions = Map.from(AppPermissions.defaultStockKeeperPermissions);
                          } else {
                            final custom = customRoles.firstWhere((r) => r.id == val);
                            _selectedRoleId = custom.id;
                            _selectedRoleName = custom.name;
                            _permissions = Map.from(custom.permissions);
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Permissions summary banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF818CF8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Role: $_selectedRoleName • ${_permissions.values.where((v) => v).length} permissions active",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Login ID: ${_usernameCtrl.text.trim().isEmpty ? 'username' : _usernameCtrl.text.trim().toLowerCase()}@${widget.shopCode}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text("CANCEL"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _addEmployee,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text("ADD EMPLOYEE"),
        ),
      ],
    );
  }
}

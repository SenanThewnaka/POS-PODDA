import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/features/users/edit_employee_screen.dart';
import 'package:sme_buddy/features/roles/role_list_screen.dart';

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
  final _passCtrl = TextEditingController();   final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _addEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // CONSTRUCT SYNTHETIC EMAIL
      // Format: username@shopcode.sme
      // e.g. kasun@X92A1.sme
      // This is unique globally if ShopCode+Username is unique.
      final syntheticEmail = "${_usernameCtrl.text.trim().toLowerCase()}@${widget.shopCode.toLowerCase()}.sme";

      final repo = ref.read(authRepositoryProvider);
      final newUid = await repo.createEmployeeAccount(
        syntheticEmail, 
        _passCtrl.text.trim()
      );
      
      if (newUid != null) {
        // 2. Create Profile linked to this Shop
        final newEmp = UserModel(
          uid: newUid,
          email: syntheticEmail, // Store synthetic email for auth reference
          name: _nameCtrl.text.trim(),
          mobile: _mobileCtrl.text.trim(), 
          role: 'cashier',
          shopId: widget.shopId,
          shopName: widget.shopName,
          username: _usernameCtrl.text.trim(), // Store plain username for display
          storedPassword: _passCtrl.text.trim(), // Store for recovery
        );
        
        await ref.read(userProfileRepositoryProvider).saveUserProfile(newEmp);
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Employee Added Successfully!")));
      }
      
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Employee"),
      content: SingleChildScrollView(
         child: Form(
           key: _formKey,
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Full Name"), validator: (v)=>v!.isEmpty?"Req":null),
               const SizedBox(height: 12),
               TextFormField(
                 controller: _mobileCtrl, 
                 decoration: const InputDecoration(labelText: "Mobile Number", prefixIcon: Icon(Icons.phone)), 
                 keyboardType: TextInputType.phone
               ),
               const SizedBox(height: 12),
               TextFormField(
                 controller: _usernameCtrl, 
                 decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person_pin)), 
                 validator: (v)=>v!.isEmpty?"Req":null
               ),
               const SizedBox(height: 12),
               TextFormField(
                 controller: _passCtrl, 
                 decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock)), 
                 validator: (v)=>v!.length>5?null:"Too short"
               ),
               const SizedBox(height: 16),
               Container(
                 padding: const EdgeInsets.all(8),
                  color: Colors.white10,
                 child: Text("Login: ${_usernameCtrl.text}@${widget.shopCode}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
               )
             ],
           ),
         ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ElevatedButton(onPressed: _isLoading ? null : _addEmployee, child: _isLoading ? const CircularProgressIndicator() : const Text("ADD")),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart'; // Import AuthRepo
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/features/roles/role_model.dart';
import 'package:sme_buddy/features/roles/role_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class EditEmployeeScreen extends ConsumerStatefulWidget {
  final UserModel employee;
  const EditEmployeeScreen({super.key, required this.employee});

  @override
  ConsumerState<EditEmployeeScreen> createState() => _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends ConsumerState<EditEmployeeScreen> {
  late Map<String, bool> _permissions;
  late TextEditingController _nameCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _passCtrl; // New
  String? _selectedRoleId;              // New
  late String _selectedRoleName;        // New: Track role name for display/save
  bool _isPasswordVisible = false;      // New
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _permissions = Map<String, bool>.from(widget.employee.permissions);
    _selectedRoleId = widget.employee.roleId; // Init
    _selectedRoleName = widget.employee.role; // Init
    _nameCtrl = TextEditingController(text: widget.employee.name);
    _userCtrl = TextEditingController(text: widget.employee.username ?? "");
    _mobileCtrl = TextEditingController(text: widget.employee.mobile);
    _passCtrl = TextEditingController(text: widget.employee.storedPassword ?? ""); // Init
  }
  
  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _mobileCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      // PASSWORD UPDATE LOGIC
      String? newPassword = widget.employee.storedPassword;
      
      // If password field changed and is valid
      if (_passCtrl.text.isNotEmpty && _passCtrl.text != widget.employee.storedPassword) {
         if (widget.employee.storedPassword == null) {
            throw "Cannot reset password for legacy accounts locally. Please delete and recreate.";
         }
         
         // Call Repository to update Auth
         await ref.read(authRepositoryProvider).updateEmployeePassword(
            widget.employee.email, 
            widget.employee.storedPassword!, 
            _passCtrl.text.trim()
         );
         newPassword = _passCtrl.text.trim();
      }

      final updatedUser = UserModel(
        uid: widget.employee.uid,
        email: widget.employee.email,
        name: _nameCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        role: _selectedRoleName.toLowerCase(), // Save selected role name (lowercased standard)
        roleId: _selectedRoleId, // Save Role ID
        shopId: widget.employee.shopId,
        shopCode: widget.employee.shopCode,
        username: _userCtrl.text.trim(),
        storedPassword: newPassword, // Save new password
        permissions: _permissions,
        shopName: widget.employee.shopName,
      );

      await ref.read(userProfileRepositoryProvider).saveUserProfile(updatedUser);
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Employee Updated!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchUri(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch app")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.employee.name),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blueAccent,
                    child: Text(
                      widget.employee.name.isNotEmpty ? widget.employee.name[0].toUpperCase() : "?",
                      style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  Text(widget.employee.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(_selectedRoleName.toUpperCase(), style: TextStyle(color: Colors.grey[600], fontSize: 12, letterSpacing: 1.2)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Contact Actions
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(Icons.call, "Call", Colors.green, "tel:${_mobileCtrl.text}"),
                    _buildActionButton(Icons.message, "Message", Colors.blue, "sms:${_mobileCtrl.text}"),
                    _buildActionButton(Icons.chat, "WhatsApp", Colors.green, "https://wa.me/${_formatMobileForWa(_mobileCtrl.text)}"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Edit Details Form
            const Align(alignment: Alignment.centerLeft, child: Text("DETAILS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person_outline), border: InputBorder.none),
                      onTap: () => _nameCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _nameCtrl.text.length),
                    ),
                    const Divider(),
                    TextField(
                      controller: _mobileCtrl,
                      decoration: const InputDecoration(labelText: "Mobile Number", prefixIcon: Icon(Icons.phone_outlined), border: InputBorder.none),
                      keyboardType: TextInputType.phone,
                      onChanged: (val) => setState((){}), // rebuild to update contact link
                      onTap: () => _mobileCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _mobileCtrl.text.length),
                    ),
                    const Divider(),
                    TextField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(labelText: "Username (Login ID)", prefixIcon: Icon(Icons.badge_outlined), border: InputBorder.none),
                      onTap: () => _userCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _userCtrl.text.length),
                    ),
                    if (widget.employee.storedPassword != null) ...[
                       const Divider(),
                       TextField(
                         controller: _passCtrl,
                         obscureText: !_isPasswordVisible,
                         decoration: InputDecoration(
                           labelText: "Login Password", 
                           prefixIcon: const Icon(Icons.lock_outline), 
                           border: InputBorder.none,
                           suffixIcon: IconButton(
                             icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                             onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                           )
                         ),
                         onTap: () => _passCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _passCtrl.text.length),
                       ),
                    ] else ...[
                       const Divider(),
                       const Padding(
                         padding: EdgeInsets.symmetric(vertical: 12),
                         child: Row(children: [
                           Icon(Icons.warning, color: Colors.orange),
                           SizedBox(width: 8),
                           Expanded(child: Text("Legacy Account: Password not viewable/editable.", style: TextStyle(color: Colors.orange))),
                         ]),
                       )
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Role Selection (New)
            const Align(alignment: Alignment.centerLeft, child: Text("ROLE TEMPLATE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                 child: Consumer(
                   builder: (context, ref, child) {
                     final rolesAsync = ref.watch(shopRolesStreamProvider(widget.employee.shopId));
                     return rolesAsync.when(
                       data: (roles) {
                         // Find current role name if possible
                         final currentRoleName = roles.firstWhere((r) => r.id == (widget.employee.roleId ?? ""), orElse: () => RoleModel(id: '', shopId: '', name: 'Custom', permissions: {})).name;
                         
                         return DropdownButtonHideUnderline(
                           child: DropdownButton<String>(
                             value: _selectedRoleId,
                             hint: Text("Current: ${currentRoleName == 'Custom' && widget.employee.roleId == null ? 'Custom' : currentRoleName}"),
                             isExpanded: true,
                             items: [
                               const DropdownMenuItem(value: null, child: Text("Custom Permissions (Manual)")),
                               ...roles.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))),
                             ], 
                             onChanged: (val) {
                               if (val != null) {
                                 // Apply Role Template
                                 final selectedRole = roles.firstWhere((r) => r.id == val);
                                 setState(() {
                                    _permissions = Map.from(selectedRole.permissions);
                                    _selectedRoleId = val;
                                    _selectedRoleName = selectedRole.name;
                                 });
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Applied permissions from ${selectedRole.name}"), duration: const Duration(seconds: 1)));
                               } else {
                                  setState(() {
                                    _selectedRoleId = null;
                                    _selectedRoleName = 'Custom';
                                  });
                               }
                             }
                           ),
                         );
                       },
                       loading: () => const LinearProgressIndicator(), 
                       error: (_,__) => const Text("Error loading roles"),
                     );
                   }
                 ),
              ),
            ),
            const SizedBox(height: 24),

            // Permissions
            const Align(alignment: Alignment.centerLeft, child: Text("PERMISSIONS (Customizable)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: Column(
                children: AppPermissions.allValues.map((key) {
                  return Column(
                    children: [
                      SwitchListTile(
                        title: Text(AppPermissions.getLabel(key), style: const TextStyle(fontWeight: FontWeight.w500)),
                        value: _permissions[key] ?? false,
                        activeColor: Colors.cyanAccent,
                        onChanged: (val) => setState(() => _permissions[key] = val),
                      ),
                      if (key != AppPermissions.allValues.last) const Divider(height: 1, indent: 16),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE CHANGES", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, String uriString) {
    return InkWell(
      onTap: () {
        if (_mobileCtrl.text.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a mobile number first")));
           return;
        }
        _launchUri(Uri.parse(uriString));
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _formatMobileForWa(String mobile) {
    mobile = mobile.trim();
    if (mobile.startsWith("0")) return "94${mobile.substring(1)}";
    return mobile;
  }
}

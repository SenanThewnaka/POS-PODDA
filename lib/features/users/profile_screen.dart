import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/auth/verification_service.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/subscription/plans_screen.dart';
import 'dart:math';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _emailCtrl; // Added
  late TextEditingController _shopNameCtrl;
  late TextEditingController _shopAddressCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _mobileCtrl = TextEditingController();
    _emailCtrl = TextEditingController(); // Added
    _shopNameCtrl = TextEditingController();
    _shopAddressCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    super.dispose();
  }

  void _initData(UserModel user) {
    if (_nameCtrl.text.isEmpty) {
        _nameCtrl.text = user.name;
        _mobileCtrl.text = user.mobile;
        _emailCtrl.text = user.email; // Added
        _shopNameCtrl.text = user.shopName ?? "";
        _shopAddressCtrl.text = user.shopAddress ?? "";
        
        // Auto-Generate Shop Code if missing (for Owners)
        if (user.isAdmin && (user.shopCode == null || user.shopCode!.isEmpty)) {
           _generateShopCode(user);
        }
    }
  }

  void _generateShopCode(UserModel user) async {
     // Simple random 6-char code
     const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I,1,O,0 to avoid confusion
     final rnd = DateTime.now().microsecondsSinceEpoch;
     final code = List.generate(6, (index) => chars[(rnd >> (index * 5)) % chars.length]).join();
     
     final updated = UserModel(
       uid: user.uid,
       email: user.email,
       name: user.name,
       mobile: user.mobile,
       role: user.role,
       shopId: user.shopId,
       shopName: user.shopName,
       shopAddress: user.shopAddress,
       shopCode: code, // Set code
     );
     
     await ref.read(userProfileRepositoryProvider).saveUserProfile(updated);
     setState(() {}); // Refresh
  }

  void _saveProfile(UserModel originalUser) async {
    if (!_formKey.currentState!.validate()) return;
    
    final newEmail = _emailCtrl.text.trim();
    final emailChanged = newEmail != originalUser.email;
    // 1. Handle Email Change
    if (emailChanged) {
       try {
         final user = ref.read(authRepositoryProvider).currentUser;
         if (user == null) throw "No Auth User";
         
         await user.updateEmail(newEmail);
       } catch (e) {
          String msg = "Email Update Failed: $e";
          if (e.toString().contains("email-already-in-use")) msg = "Email already in use.";
          if (e.toString().contains("requires-recent-login")) msg = "Please re-login to change email.";
          
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
          return; // Abort
       }
    }

    final updatedUser = UserModel(
      uid: originalUser.uid,
      email: newEmail,
      role: originalUser.role,
      shopId: originalUser.shopId,
      shopCode: originalUser.shopCode, 
      permissions: originalUser.permissions, // Keep existing permissions
      name: _nameCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      shopName: originalUser.isAdmin ? _shopNameCtrl.text.trim() : originalUser.shopName,
      shopAddress: originalUser.isAdmin ? _shopAddressCtrl.text.trim() : originalUser.shopAddress,
      // Verification Status Update
      isVerified: true,
      verificationCode: null,
      // Preserve others (Wait, if I use constructor I MUST providing others or defaults?)
      // Ah, UserModel constructor uses defaults for optional fields.
      // But fields like `welcomeSent`, `billingCycle`, etc. might be lost if not passed?
      // YES! The current `_saveProfile` was LOSING data because it wasn't passing everything.
      // The previous implementation was:
      /*
        final updatedUser = UserModel(
           uid: originalUser.uid,
           email: originalUser.email,
           role: originalUser.role,
      */
      // Wait, `UserModel` fields are final.
      // If `expiryDate`, `welcomeSent`, etc. are not passed, they use defaults (null or false).
      // EXISTING BUG: `_saveProfile` was resetting `welcomeSent` to false and `expiryDate` to null (or default) if not copied!
      // I MUST FIX THIS using `.copyWith`.
      // The original code was potentially destructive for fields not in constructor call.
    );
     // BUT `copyWith` is safer. Let's use `copyWith`.
     
    final finalUser = originalUser.copyWith(
       email: newEmail,
       name: _nameCtrl.text.trim(),
       mobile: _mobileCtrl.text.trim(),
       shopName: originalUser.isAdmin ? _shopNameCtrl.text.trim() : originalUser.shopName,
       shopAddress: originalUser.isAdmin ? _shopAddressCtrl.text.trim() : originalUser.shopAddress,
       isVerified: true,
       verificationCode: null,
    );

    // Save
    await ref.read(userProfileRepositoryProvider).saveUserProfile(finalUser);
    
    setState(() => _isEditing = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
               if (_isEditing) {
                 // Save
                 userAsync.whenData((user) {
                   if (user != null) _saveProfile(user);
                 });
               } else {
                 setState(() => _isEditing = true);
               }
            },
          )
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text("User not found"));
          _initData(user); // Initialize controllers if empty
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSectionHeader("Personal Info"),
                   _buildTextField("Full Name", _nameCtrl, Icons.person),
                   _buildTextField("Mobile", _mobileCtrl, Icons.phone, inputType: TextInputType.phone),
                   
                   const SizedBox(height: 24),
                   if (user.isAdmin) ...[
                      _buildSectionHeader("Shop Details"),
                      
                      // SHOP CODE DISPLAY
                      GlassCard(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(24),
                        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                        color: Colors.cyan.withValues(alpha: 0.05),
                        child: Column(
                          children: [
                            Text("SHOP CODE (Share with Employees)", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            SelectableText(
                              user.shopCode ?? "GENERATING...", 
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      _buildTextField("Shop Name", _shopNameCtrl, Icons.store),
                      _buildTextField("Shop Address", _shopAddressCtrl, Icons.location_on),
                   ] else ...[
                      _buildSectionHeader("Shop Info (Managed by Owner)"),
                      ListTile(
                        leading: const Icon(Icons.store),
                        title: Text(user.shopName ?? "Unnamed Shop"),
                        subtitle: const Text("Shop Name"),
                      ),
                   ],

                   const SizedBox(height: 24),
                   _buildSectionHeader("Account Info"),
                   _buildTextField("Email", _emailCtrl, Icons.email, inputType: TextInputType.emailAddress), // Made editable
                   ListTile(
                     leading: const Icon(Icons.badge),
                     title: Text(user.role.toUpperCase()),
                     subtitle: const Text("Role"),
                   ),
                   const SizedBox(height: 24),
                   _buildSectionHeader("Subscription & Plan"),
                   ListTile(
                     leading: const Icon(Icons.workspace_premium_rounded, color: Colors.amberAccent),
                     title: Text(user.plan.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                     subtitle: Text(
                       user.expiryDate != null
                           ? (DateTime.now().isAfter(user.expiryDate!)
                               ? "Expired on ${DateFormat('MMM dd, yyyy').format(user.expiryDate!)}"
                               : "Expires on ${DateFormat('MMM dd, yyyy').format(user.expiryDate!)}")
                           : "No active subscription / Inactive",
                       style: TextStyle(
                         color: (user.expiryDate == null || DateTime.now().isAfter(user.expiryDate!))
                             ? Colors.redAccent
                             : null,
                       ),
                     ),
                     trailing: ElevatedButton(
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                         foregroundColor: Colors.cyanAccent,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       ),
                       onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen())),
                       child: const Text("MANAGE / EXTEND"),
                     ),
                   ),
                   const SizedBox(height: 32),
                   _buildSectionHeader("Danger Zone", isDestructive: true),
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: Colors.redAccent.withValues(alpha: 0.08),
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text(
                           "Delete Account",
                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
                         ),
                         const SizedBox(height: 6),
                         Text(
                           "Permanently remove your account and all associated shop data. This action is irreversible.",
                           style: TextStyle(
                             fontSize: 13,
                             color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                           ),
                         ),
                         const SizedBox(height: 16),
                         OutlinedButton.icon(
                           style: OutlinedButton.styleFrom(
                             foregroundColor: Colors.redAccent,
                             side: const BorderSide(color: Colors.redAccent),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                           ),
                           icon: const Icon(Icons.delete_forever, size: 18),
                           label: const Text("DELETE ACCOUNT"),
                           onPressed: () => _confirmDeleteAccount(user),
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title, 
        style: TextStyle(
          fontSize: 18, 
          fontWeight: FontWeight.bold, 
          color: isDestructive ? Colors.redAccent : Colors.cyanAccent,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, {TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        enabled: _isEditing,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: !_isEditing,
          fillColor: _isEditing ? null : Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.5),
        ),
        validator: (v) => v!.isEmpty ? "Required" : null,
      ),
    );
  }

  Future<void> _confirmDeleteAccount(UserModel user) async {
    final passwordCtrl = TextEditingController();
    final authUser = ref.read(authRepositoryProvider).currentUser;
    final isGoogleUser = authUser?.providerData
        .any((p) => p.providerId == 'google.com') ?? false;
    bool isDeleting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 8),
              Text("Delete Account?", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Are you sure you want to permanently delete your account?",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "• All your shop data, inventory, sales, and employee accounts will be permanently deactivated.\n"
                "• You will lose any remaining days on your trial or subscription.\n"
                "• Note: Creating another account with this email will NOT grant a new free trial.",
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                ),
              ),
              if (!isGoogleUser) ...[
                const SizedBox(height: 16),
                const Text(
                  "Enter your password to confirm:",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: isDeleting
                  ? null
                  : () async {
                      if (!isGoogleUser && passwordCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter your password to confirm deletion.")),
                        );
                        return;
                      }

                      setDialogState(() => isDeleting = true);
                      try {
                        final authRepo = ref.read(authRepositoryProvider);
                        final userProfileRepo = ref.read(userProfileRepositoryProvider);

                        // 1. Record deletion in trial_history and deactivate profile
                        await userProfileRepo.deleteUserAccount(user: user);

                        // 2. Delete Firebase Auth account
                        await authRepo.deleteCurrentUserAccount(
                          currentPassword: isGoogleUser ? null : passwordCtrl.text.trim(),
                        );

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          Navigator.of(context).popUntil((route) => route.isFirst);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Your account has been permanently deleted."),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isDeleting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Deletion failed: ${e.toString().replaceAll('Exception:', '').trim()}"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("PERMANENTLY DELETE"),
            ),
          ],
        ),
      ),
    );
    passwordCtrl.dispose();
  }
}

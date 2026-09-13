import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/profile_screen.dart';
import 'package:sme_buddy/features/users/employee_management_screen.dart';
import 'package:sme_buddy/features/roles/role_list_screen.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/features/settings/theme_provider.dart';
import 'package:sme_buddy/features/settings/invoice_settings_screen.dart';
import 'package:sme_buddy/features/settings/printer_settings_screen.dart';

import 'package:sme_buddy/features/subscription/subscription_guard.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/biometric_lock_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final currentTheme = ref.watch(themeModeProvider);

    return GlassScaffold(
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [


            // THEME SWITCHER
            Builder(
              builder: (context) {
                 final themeMode = currentTheme;
                 final isDark = themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
                 
                 return GlassCard(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   child: SwitchListTile(
                     title: Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                     secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: isDark ? Colors.cyanAccent : Colors.orangeAccent),
                     value: isDark,
                     activeColor: Colors.cyanAccent,
                     onChanged: (val) {
                        ref.read(themeModeProvider.notifier).setTheme(val ? ThemeMode.dark : ThemeMode.light);
                     },
                   ),
                 );
              }
            ),
            const SizedBox(height: 12),

            // BIOMETRIC LOCK TOGGLE
            FutureBuilder<bool>(
              future: BiometricLockService.isAvailable(),
              builder: (context, availSnap) {
                if (availSnap.data != true) return const SizedBox.shrink();
                return StatefulBuilder(
                  builder: (context, setS) {
                    return FutureBuilder<bool>(
                      future: BiometricLockService.isEnabled(),
                      builder: (context, enabledSnap) {
                        final isEnabled = enabledSnap.data ?? false;
                        return GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: SwitchListTile(
                            title: Text('Biometric Lock', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                            subtitle: Text(
                              isEnabled ? 'App locks when minimised' : 'Enable fingerprint / face lock',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
                            ),
                            secondary: Icon(Icons.fingerprint, color: isEnabled ? Colors.cyanAccent : Colors.grey),
                            value: isEnabled,
                            activeColor: Colors.cyanAccent,
                            onChanged: (val) async {
                              final confirmed = await BiometricLockService.authenticate();
                              if (confirmed) {
                                await BiometricLockService.setEnabled(val);
                                setS(() {}); // Rebuild the StatefulBuilder
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // PROFILE LINK
            InkWell(
              onTap: () {
                 if (user != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                 }
              },
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                borderRadius: 16,
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.person, size: 30, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.email ?? "No Email",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                          ),
                          const SizedBox(height: 4),
                          Text("Edit Profile & Shop", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blueAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.cyanAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // ACTION BUTTONS
            Consumer(
              builder: (context, ref, child) {
                 final userProfileAsync = ref.watch(userProfileProvider);
                 return userProfileAsync.when(
                   data: (profile) {
                     if (profile == null) return const SizedBox();
                     
                     return Column(
                       children: [
                         if (profile.isAdmin || profile.hasPermission(AppPermissions.canViewEmployees))
                            GlassCard(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                title: Text("Team Management", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                                subtitle: Text("Add / Remove Cashiers", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.people, color: Colors.orange),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
                                onTap: () async {
                                   if (await SubscriptionGuard.check(context, ref, SubscriptionAction.manageTeam)) {
                                      if (context.mounted) {
                                         Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeManagementScreen()));
                                      }
                                   }
                                },
                              ),
                            ),

                          if (profile.isAdmin)
                            GlassCard(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                title: Text("Bill Customization", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                                subtitle: Text("Headers, Footers", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.pink.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.receipt_long, color: Colors.pinkAccent),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
                                onTap: () {
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceSettingsScreen()));
                                },
                              ),
                            ),

                          GlassCard(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              title: Text("Printer & Hardware", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                              subtitle: Text("Thermal roll (80mm/58mm), Auto-print, USB/BT printers", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.print, color: Colors.tealAccent),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
                              onTap: () {
                                 Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()));
                              },
                            ),
                          ),
                         
                         if (profile.isAdmin) // Only Owners can manage Roles
                            GlassCard(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.shield, color: Colors.purpleAccent),
                                ),
                                title: Text("Manage Roles & Permissions", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleListScreen())),
                              ),
                            ),
                       ],
                     );
                   },
                   loading: () => const LinearProgressIndicator(), 
                   error: (_,__) => const SizedBox(),
                 );
              }
            ),
            
            GlassCard(
              margin: const EdgeInsets.only(bottom: 24),
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                subtitle: Text("Update your password securely", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.password, color: Colors.blueAccent),
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
                onTap: () {
                   _showChangePasswordDialog(context, ref);
                },
              ),
            ),
            
            ElevatedButton.icon(
              onPressed: () async {
                 // Sign Out
                 await ref.read(authRepositoryProvider).signOut();
                 if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                 }
              },
              icon: const Icon(Icons.logout),
              label: const Text("SIGN OUT"),
              style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(inherit: false),
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5))),
              ),
            ),
            
            const SizedBox(height: 32),
            const Center(
              child: Text("POS Podda v1.4.0", style: TextStyle(color: Colors.white30)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>(); // Minimal validation

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldPassCtrl,
                decoration: const InputDecoration(labelText: "Current Password"),
                obscureText: true,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPassCtrl,
                decoration: const InputDecoration(labelText: "New Password"),
                obscureText: true,
                validator: (v) => v!.length < 6 ? "Min 6 chars" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  Navigator.pop(context); // Close dialog first to show loading/snack
                  // or show loading indicator. Keeping it simple: close and snack.
                  
                  await ref.read(authRepositoryProvider).changePassword(
                    oldPassCtrl.text.trim(), 
                    newPassCtrl.text.trim()
                  );
                  
                  if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text("Password Updated Successfully!"), backgroundColor: Colors.green)
                     );
                  }
                } catch (e) {
                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text("Failed: ${e.toString()}"), backgroundColor: Colors.red)
                     );
                   }
                }
              }
            },
            child: const Text("UPDATE"),
          )
        ],
      ),
    );
  }
}

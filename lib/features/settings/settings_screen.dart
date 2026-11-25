import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/profile_screen.dart';
import 'package:sme_buddy/features/users/employee_management_screen.dart';
import 'package:sme_buddy/features/roles/role_list_screen.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:sme_buddy/features/users/app_permissions.dart';
import 'package:sme_buddy/features/settings/theme_provider.dart';
import 'package:sme_buddy/features/settings/invoice_settings_screen.dart';
import 'package:sme_buddy/features/settings/printer_settings_screen.dart';

import 'package:sme_buddy/features/subscription/subscription_guard.dart';
import 'package:sme_buddy/features/subscription/subscription_info_card.dart';
import 'package:sme_buddy/features/subscription/plans_screen.dart';
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
            const SizedBox(height: 24),

            // SUBSCRIPTION & BILLING
            const SubscriptionInfoCard(),
            const SizedBox(height: 32),

            // ==========================================
            // PLUS SECTION
            // ==========================================
            _buildSectionHeader(context, "Plus Section", isPro: false),
            
            // THEME SWITCHER
            Builder(
              builder: (context) {
                 final themeMode = currentTheme;
                 final isDark = themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
                 
                 return GlassCard(
                   margin: const EdgeInsets.only(bottom: 12),
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
                          margin: const EdgeInsets.only(bottom: 12),
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
                                setS(() {});
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

            GlassCard(
              margin: const EdgeInsets.only(bottom: 12),
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
            
            GlassCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                subtitle: Text("Update your password securely", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.lock_outline, color: Colors.blueAccent),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
                onTap: () => _showChangePasswordDialog(context, ref),
              ),
            ),

            Consumer(
              builder: (context, ref, child) {
                final profile = ref.watch(userProfileProvider).value;
                if (profile == null) return const SizedBox.shrink();
                final isVat = profile.isVatRegistered;

                return Column(
                  children: [
                    // Prominent Tax & VAT Configuration Card
                    GlassCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      border: Border.all(
                        color: isVat 
                            ? (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.teal)
                            : (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12),
                        width: isVat ? 1.5 : 1,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isVat ? Colors.cyanAccent : Colors.grey).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.account_balance, 
                                  color: isVat ? (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.teal) : Colors.grey, 
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Tax Invoice / VAT (IRD 18%)",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 15,
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isVat 
                                        ? "Active • ${profile.vatPercentage.toStringAsFixed(0)}% VAT${profile.vatNumber != null ? ' (TIN: ${profile.vatNumber})' : ''}" 
                                        : "OFF • Standard receipts without VAT",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isVat 
                                            ? (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.teal) 
                                            : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                                        fontWeight: isVat ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isVat,
                                activeColor: Colors.cyanAccent,
                                onChanged: (val) async {
                                  final updated = profile.copyWith(isVatRegistered: val);
                                  await ref.read(userProfileRepositoryProvider).saveUserProfile(updated);
                                  if (context.mounted) {
                                    if (val) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Tax Invoice mode enabled! Configure your TIN number below."),
                                          backgroundColor: Colors.teal,
                                        ),
                                      );
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceSettingsScreen()));
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Tax Invoice mode disabled. Standard bills active.")),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          if (isVat) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceSettingsScreen()));
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Configure VAT TIN, Rate & Format",
                                      style: TextStyle(
                                        fontSize: 12, 
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.teal, 
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios, 
                                      size: 12, 
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.teal,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (profile.isAdmin)
                      GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          title: Text(
                            "Bill Customization", 
                            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                          ),
                          subtitle: Text(
                            "Shop Name, Address, Phone, Footers", 
                            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                          ),
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
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ==========================================
            // PRO SECTION
            // ==========================================
            _buildSectionHeader(context, "Pro Section", isPro: true),

            Consumer(
              builder: (context, ref, child) {
                 final profile = ref.watch(userProfileProvider).value;
                 if (profile == null) return const SizedBox.shrink();
                 
                 return Column(
                   children: [
                     // Always show it, but block on tap, so users know it exists!
                     GlassCard(
                       margin: const EdgeInsets.only(bottom: 12),
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

                     if (profile.isAdmin) // Only Owners can manage Roles
                       GlassCard(
                         margin: const EdgeInsets.only(bottom: 12),
                         padding: EdgeInsets.zero,
                         child: ListTile(
                           leading: Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                             child: const Icon(Icons.shield, color: Colors.purpleAccent),
                           ),
                           title: Text("Manage Roles & Permissions", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                           trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54),
                           onTap: () async {
                              // Guard it as a manageTeam feature
                              if (await SubscriptionGuard.check(context, ref, SubscriptionAction.manageTeam)) {
                                 if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleListScreen()));
                              }
                           },
                         ),
                       ),
                   ],
                 );
              }
            ),
            
            _buildSectionHeader(context, "Legal Section"),
            
            GlassCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text("Terms, Privacy & Policies", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                subtitle: Text("View legal documents and rules", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.policy_outlined, color: Colors.grey),
                ),
                trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.white54),
                onTap: () async {
                   const url = 'https://pos-podda.web.app/legal.html';
                   if (await canLaunchUrlString(url)) {
                     await launchUrlString(url);
                   }
                },
              ),
            ),
            
            GlassCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.zero,
              child: ListTile(
                title: const Text("Delete Account", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                subtitle: Text("Permanently delete shop and personal data", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_forever, color: Colors.redAccent),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
                onTap: () {
                  if (user != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  }
                },
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
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

  Widget _buildSectionHeader(BuildContext context, String title, {bool isPro = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 16),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPro ? Colors.indigoAccent : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
            ),
          ),
          if (isPro) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.indigoAccent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text("PRO", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ],
        ],
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

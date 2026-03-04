import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/roles/add_edit_role_screen.dart';
import 'package:sme_buddy/features/roles/role_model.dart';
import 'package:sme_buddy/features/roles/role_repository.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/utils/shimmer_skeletons.dart';

class RoleListScreen extends ConsumerWidget {
  const RoleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Manage Roles")),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();
           final rolesAsync = ref.watch(shopRolesStreamProvider(user.shopId));

           return rolesAsync.when(
             data: (roles) {
                if (roles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.admin_panel_settings_outlined, size: 72, color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text('No Custom Roles Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white54)),
                        const SizedBox(height: 8),
                        const Text('Tap + to create a role\n(e.g. Manager, Cashier)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white30)),
                      ],
                    ),
                  );
               }
               return ListView.separated(
                 padding: const EdgeInsets.all(16),
                 itemCount: roles.length,
                 separatorBuilder: (_,__) => const Divider(),
                 itemBuilder: (context, index) {
                    final role = roles[index];
                    return ListTile(
                      title: Text(role.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${role.permissions.values.where((v)=>v).length} Permissions"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditRoleScreen(shopId: user.shopId, role: role)));
                      },
                    );
                 },
               );
             },
             loading: () => ListView(
               padding: const EdgeInsets.all(16),
               children: List.generate(3, (_) => const ShimmerListTile()),
             ),
             error: (e, st) => Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                   const SizedBox(height: 12),
                   const Text('Failed to load roles', style: TextStyle(color: Colors.white54)),
                 ],
               ),
             ),
           );
        },
        loading: () => const ShimmerListTile(),
        error: (e, st) => const Center(child: Text('Error loading user')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           final user = ref.read(userProfileProvider).value;
           if(user != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditRoleScreen(shopId: user.shopId)));
           }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

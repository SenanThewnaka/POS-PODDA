import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';

class SetupShopScreen extends ConsumerStatefulWidget {
  const SetupShopScreen({super.key});

  @override
  ConsumerState<SetupShopScreen> createState() => _SetupShopScreenState();
}

class _SetupShopScreenState extends ConsumerState<SetupShopScreen> {
  final _nameCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) return; // Should not happen

      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? "",
        name: _nameCtrl.text.trim(),
        mobile: "", // Optional update later
        role: 'owner', // First setup is always owner
        shopId: user.uid,
        shopName: _shopNameCtrl.text.trim(),
        
        // Subscription Initialization (Completely Free Lifetime)
        plan: 'free',
        subscriptionStatus: 'active',
        billingCycle: 'lifetime',
        expiryDate: null,
        isVerified: true,
      );

      await ref.read(userProfileRepositoryProvider).saveUserProfile(userModel);
      // AuthGate will react to stream update and redirect to Home
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Your Shop")),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.store_mall_directory, size: 64, color: Colors.cyanAccent),
              const SizedBox(height: 24),
              const Text("Welcome! Let's set up your profile.", style: TextStyle(fontSize: 18)),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Your Full Name", prefixIcon: Icon(Icons.person)),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _shopNameCtrl,
                decoration: const InputDecoration(labelText: "Shop Name", prefixIcon: Icon(Icons.store)),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading ? const CircularProgressIndicator() : const Text("COMPLETE SETUP"),
                ),
              ),
              TextButton(
                 onPressed: () => ref.read(authRepositoryProvider).signOut(),
                 child: const Text("Sign Out"),
              )
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}

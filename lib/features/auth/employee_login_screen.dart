import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';

class EmployeeLoginScreen extends ConsumerStatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  ConsumerState<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends ConsumerState<EmployeeLoginScreen> {
  final _shopCodeCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Reconstruct Synthetic Email
      final syntheticEmail = "${_usernameCtrl.text.trim().toLowerCase()}@${_shopCodeCtrl.text.trim().toLowerCase()}.sme";

      await ref.read(authRepositoryProvider).signInWithEmail(
        syntheticEmail, 
        _passCtrl.text.trim()
      );
      
      // AuthGate will redirect
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);

    } catch (e) {
      if (mounted) {
         String message = "Login Failed";
         if (e.toString().contains("user-not-found")) message = "Invalid Shop Code or Username";
         else if (e.toString().contains("wrong-password")) message = "Incorrect Password";
         else message = "Error: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim()}";

         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
             backgroundColor: Colors.red,
             behavior: SnackBarBehavior.floating,
           )
         );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GlassScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.badge, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  Text(
                    "Staff Access",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.blueAccent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter your Shop Code and credentials",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 32),

                  // SHOP CODE
                  TextFormField(
                    controller: _shopCodeCtrl,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: _inputDeco("Shop Code (e.g. X72A1)", Icons.store, isDark),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => v!.length < 4 ? "Invalid Code" : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // USERNAME
                  TextFormField(
                    controller: _usernameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: _inputDeco("Username", Icons.person, isDark),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // PASSWORD
                  TextFormField(
                    controller: _passCtrl,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: "Password", 
                      prefixIcon: Icon(Icons.lock, color: isDark ? Colors.white70 : Colors.black54),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: isDark ? Colors.white70 : Colors.black54),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 8,
                      shadowColor: Colors.blueAccent.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("LOGIN TO SHOP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Back", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, bool isDark) {
     return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
        border: const OutlineInputBorder(),
     );
  }
}

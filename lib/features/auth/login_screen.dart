import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/auth/signup_screen.dart';
import 'package:sme_buddy/features/auth/employee_login_screen.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(
        _emailCtrl.text.trim(), 
        _passCtrl.text.trim()
      );
      // Navigation handled by AuthGate
    } catch (e) {
      if (mounted) {
         String message = "Login Failed";
         if (e.toString().contains("user-not-found") || e.toString().contains("wrong-password") || e.toString().contains("invalid-credential")) {
            message = "Invalid email or password";
         }
         else if (e.toString().contains("invalid-email")) message = "Invalid email format.";
         else message = "Login Failed: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim()}";

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
    return GlassScaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: GlassCard(
              borderRadius: 24,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.store_mall_directory_rounded, size: 80, color: Colors.cyanAccent),
                    const SizedBox(height: 16),
                    Text(
                      "POS Podda",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Login to your shop",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _emailCtrl,
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: "Email", 
                        prefixIcon: Icon(Icons.email, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                        labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                      ),
                      validator: (v) => v!.contains('@') ? null : "Invalid Email",
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: "Password", 
                        prefixIcon: Icon(Icons.lock, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                        labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                      obscureText: !_isPasswordVisible,
                      validator: (v) => v!.length > 5 ? null : "Password too short",
                    ),
                    
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                             if (_emailCtrl.text.isNotEmpty) {
                                 ref.read(authRepositoryProvider).resetPassword(_emailCtrl.text.trim());
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password Reset Email Sent!")));
                             } else {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter Email first!")));
                             }
                        },
                        child: const Text("Forgot Password?", style: TextStyle(color: Colors.cyanAccent)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        shadowColor: Colors.cyanAccent.withValues(alpha: 0.5),
                        elevation: 8,
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text("LOGIN"),
                    ),

                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text("Don't have an account?", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                        TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                          },
                          child: const Text("Sign Up", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                       onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeLoginScreen()));
                       },
                       icon: const Icon(Icons.badge, color: Colors.white),
                       label: const Text("LOGIN AS EMPLOYEE"),
                       style: OutlinedButton.styleFrom(
                         foregroundColor: Colors.white,
                         side: const BorderSide(color: Colors.white54),
                       ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

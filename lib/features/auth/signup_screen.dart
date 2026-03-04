import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'dart:math';
import 'package:sme_buddy/features/auth/verification_service.dart';

import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match!")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signUpWithEmail(
        _emailCtrl.text.trim(), 
        _passCtrl.text.trim()
      );
      
      final code = (100000 + Random().nextInt(900000)).toString();
      
      if (user != null) {
         // Create Firestore Profile with Verification Code
         final userModel = UserModel(
           uid: user.uid,
           email: user.email!, // Email is non-null after signup
           name: _nameCtrl.text.trim(),
           mobile: _mobileCtrl.text.trim(),
           role: 'owner', // Default to owner for new signups
           shopId: user.uid, // Owner's Shop ID is their own UID
           shopName: "${_nameCtrl.text.trim()}'s Shop", // Default Shop Name
           plan: 'trial',
           subscriptionStatus: 'active',
           billingCycle: 'trial',
           expiryDate: DateTime.now().add(const Duration(days: 15)),
           isVerified: false,
           verificationCode: code,
           welcomeSent: false,
         );
         await ref.read(userProfileRepositoryProvider).saveUserProfile(userModel);
         
         // Send OTP
         await VerificationService.sendCode(user.email!, code);
      }
      
      // Auto-send verification email -> REPLACED WITH OTP
      // await repo.sendEmailVerification();

      if (mounted) {
         // Pop back to let AuthGate handle the flow (it will see user is logged in, then check verified)
         // Actually, if we just registered, AuthGate will trigger.
         // We should just close this screen if pushed, or let AuthGate replace logic.
         // Since Signup was Pushed from Login, we can pop to ensure we are back at root which is controlled by Gate?
         // No, AuthGate is the root. If we are pushed, we are on top.
         // We should pop all the way back.
         Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
         String message = "Signup Failed: ${e.toString()}";
         if (e.toString().contains("email-already-in-use")) {
            message = "This email is already registered.";
         } else if (e.toString().contains("weak-password")) {
            message = "Password is too weak.";
         } else if (e.toString().contains("invalid-email")) {
            message = "Invalid email address.";
         }
         
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.app_registration, size: 60, color: Colors.cyanAccent),
                  const SizedBox(height: 16),
                  Text(
                    "Start your journey",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create a free account to secure your data.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 32),

                  _buildTextField(_nameCtrl, "Full Name", Icons.person, isDark),
                  const SizedBox(height: 16),
                  _buildTextField(_mobileCtrl, "Mobile Number", Icons.phone, isDark, isPhone: true),
                  const SizedBox(height: 16),
                  _buildTextField(_emailCtrl, "Email", Icons.email, isDark),
                  const SizedBox(height: 16),
                  
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
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: (v) => v!.length > 5 ? null : "Password too short",
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _confirmPassCtrl,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: "Confirm Password", 
                      prefixIcon: Icon(Icons.lock_outline, color: isDark ? Colors.white70 : Colors.black54),
                      suffixIcon: IconButton(
                        icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off, color: isDark ? Colors.white70 : Colors.black54),
                        onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                      ),
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                    ),
                    obscureText: !_isConfirmPasswordVisible,
                    validator: (v) => v!.isNotEmpty ? null : "Confirm Password",
                  ),
                  
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 8,
                      shadowColor: Colors.cyanAccent.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("CREATE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Back to Login", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, bool isDark, {bool isPhone = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
        border: const OutlineInputBorder(),
      ),
      validator: (v) => v!.isNotEmpty ? null : "$label Required",
    );
  }
}

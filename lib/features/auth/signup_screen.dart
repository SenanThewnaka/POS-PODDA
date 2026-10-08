import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/auth/widgets/google_sign_in_button.dart';
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
  bool _isGoogleLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match!")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final userProfileRepo = ref.read(userProfileRepositoryProvider);
      final rawEmail = _emailCtrl.text.trim();
      final hasUsedTrial = await userProfileRepo.checkEmailHasUsedTrial(rawEmail);

      final user = await repo.signUpWithEmail(
        rawEmail, 
        _passCtrl.text.trim()
      );
      
      if (user != null) {
        if (hasUsedTrial) {
          // Trial already used or account previously deleted: mark trial expired
          final pastDate = DateTime.now().subtract(const Duration(days: 1));
          final userModel = UserModel(
            uid: user.uid,
            email: user.email!,
            name: _nameCtrl.text.trim(),
            mobile: _mobileCtrl.text.trim(),
            role: 'owner',
            shopId: user.uid,
            shopName: "${_nameCtrl.text.trim()}'s Shop",
            plan: 'trial',
            subscriptionStatus: 'expired',
            billingCycle: 'trial',
            expiryDate: pastDate,
            isVerified: true,
            verificationCode: null,
            welcomeSent: false,
          );
          await userProfileRepo.saveUserProfile(userModel);
        } else {
          // New user: grant 14-day free trial
          final trialExpiry = DateTime.now().add(const Duration(days: 14));
          final userModel = UserModel(
            uid: user.uid,
            email: user.email!,
            name: _nameCtrl.text.trim(),
            mobile: _mobileCtrl.text.trim(),
            role: 'owner',
            shopId: user.uid,
            shopName: "${_nameCtrl.text.trim()}'s Shop",
            plan: 'trial',
            subscriptionStatus: 'active',
            billingCycle: 'trial',
            expiryDate: trialExpiry,
            isVerified: true,
            verificationCode: null,
            welcomeSent: false,
          );
          await userProfileRepo.saveUserProfile(userModel);
          await userProfileRepo.recordTrialGranted(user.email!, uid: user.uid, expiryDate: trialExpiry);
        }
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

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isGoogleLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final cred = await authRepo.signInWithGoogle();
      if (cred == null || cred.user == null) {
        // User cancelled the sign-in flow
        return;
      }

      // Automatically provision owner profile if this is a first-time sign-in
      final userProfileRepo = ref.read(userProfileRepositoryProvider);
      await userProfileRepo.ensureUserProfileForGoogle(cred.user!);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('popup_closed_by_user') ||
          errorStr.contains('cancelled') ||
          errorStr.contains('canceled') ||
          errorStr.contains('sign_in_canceled')) {
        return;
      }

      String message = "Google Sign-Up Failed";
      if (errorStr.contains("network")) {
        message = "Network error. Please check your internet connection.";
      } else if (errorStr.contains("account-exists-with-different-credential")) {
        message = "An account already exists with this email using another method.";
      } else {
        message = "Sign up failed: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim()}";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
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
                    onPressed: (_isLoading || _isGoogleLoading) ? null : _signup,
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
                  
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "OR",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  GoogleSignInButton(
                    onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignUp,
                    isLoading: _isGoogleLoading,
                    label: "Sign up with Google",
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

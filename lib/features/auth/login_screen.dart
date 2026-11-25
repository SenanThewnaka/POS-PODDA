import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/auth/signup_screen.dart';
import 'package:sme_buddy/features/auth/employee_login_screen.dart';
import 'package:sme_buddy/features/auth/widgets/google_sign_in_button.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/login_rate_limiter.dart';
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
  bool _isGoogleLoading = false;
  bool _isPasswordVisible = false;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _startLockoutCountdown(int seconds) {
    _countdownTimer?.cancel();
    if (seconds <= 0) {
      if (mounted) setState(() => _remainingSeconds = 0);
      return;
    }
    if (mounted) setState(() => _remainingSeconds = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return '${s}s';
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter Email first!"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Email format validation
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid email address."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password Reset Email Sent!"),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString().toLowerCase();
      String message = "Failed to send reset email. Please try again.";
      if (errorStr.contains("user-not-found")) {
        message = "No account found with this email address.";
      } else if (errorStr.contains("invalid-email")) {
        message = "Invalid email format.";
      } else if (errorStr.contains("too-many-requests")) {
        message = "Too many reset attempts. Please wait a few minutes.";
      } else if (errorStr.contains("network")) {
        message = "Network error. Please check your internet connection.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _login() async {
    if (_remainingSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Account temporarily locked for security. Please wait ${_formatDuration(_remainingSeconds)}.",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange.shade900,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailCtrl.text.trim();
    final lockState = await LoginRateLimiter.getLockoutState(email);
    if (lockState.isLocked) {
      if (mounted) {
        setState(() => _isLoading = false);
        _startLockoutCountdown(lockState.remainingSeconds);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Account locked out. Please try again in ${_formatDuration(lockState.remainingSeconds)}.",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orange.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      await ref.read(authRepositoryProvider).signInWithEmail(
        email, 
        _passCtrl.text.trim()
      );
      // Login successful: reset failed attempt counter
      await LoginRateLimiter.clearAttempts(email);
      // Navigation handled by AuthGate
    } catch (e) {
      if (mounted) {
         final errorStr = e.toString();
         final isCredentialError = errorStr.contains("user-not-found") ||
             errorStr.contains("wrong-password") ||
             errorStr.contains("invalid-credential");
         final isFirebaseBlocked = errorStr.contains("too-many-requests");

         String message = "Login Failed";
         if (isFirebaseBlocked || isCredentialError) {
           final newState = await LoginRateLimiter.recordFailedAttempt(
             email,
             isFirebaseBlocked: isFirebaseBlocked,
           );
           if (!mounted) return;
           if (newState.isLocked) {
             _startLockoutCountdown(newState.remainingSeconds);
             message = isFirebaseBlocked
                 ? "Access temporarily blocked due to unusual activity. Try again in ${newState.formattedRemainingTime}."
                 : "Account locked out for security (${newState.formattedRemainingTime}). Please wait or reset password.";
           } else {
             message = "Invalid email or password";
           }
         } else if (errorStr.contains("invalid-email")) {
           message = "Invalid email format.";
         } else {
           message = "Login Failed: ${errorStr.replaceAll(RegExp(r'\[.*?\]'), '').trim()}";
         }

         if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
             backgroundColor: (_remainingSeconds > 0) ? Colors.orange.shade900 : Colors.red,
             behavior: SnackBarBehavior.floating,
             duration: const Duration(seconds: 4),
           )
         );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_remainingSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Account locked out for security. Please wait ${_formatDuration(_remainingSeconds)}."),
          backgroundColor: Colors.orange.shade900,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isGoogleLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final cred = await authRepo.signInWithGoogle();
      if (cred == null || cred.user == null) {
        // User cancelled or closed the sign-in flow
        return;
      }

      // Automatically provision owner profile if this is a first-time sign-in
      final userProfileRepo = ref.read(userProfileRepositoryProvider);
      await userProfileRepo.ensureUserProfileForGoogle(cred.user!);

      // Clear any previous failed attempts
      if (cred.user!.email != null) {
        await LoginRateLimiter.clearAttempts(cred.user!.email!);
      }
      // AuthGate will automatically redirect to Dashboard upon authState update
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('popup_closed_by_user') ||
          errorStr.contains('cancelled') ||
          errorStr.contains('canceled') ||
          errorStr.contains('sign_in_canceled')) {
        return;
      }

      String message = "Google Sign-In Failed";
      if (errorStr.contains("network")) {
        message = "Network error. Please check your internet connection.";
      } else if (errorStr.contains("account-exists-with-different-credential")) {
        message = "An account already exists with this email using another method.";
      } else {
        message = "Sign in failed: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim()}";
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
                        onPressed: _handleForgotPassword,
                        child: const Text("Forgot Password?", style: TextStyle(color: Colors.cyanAccent)),
                      ),
                    ),
                    if (_remainingSeconds > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.redAccent, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Account Locked for Security",
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Too many failed attempts. Try again in ${_formatDuration(_remainingSeconds)}.",
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      const SizedBox(height: 24),
                    ],

                    ElevatedButton(
                      onPressed: (_isLoading || _remainingSeconds > 0) ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _remainingSeconds > 0 ? Colors.grey : Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        shadowColor: Colors.cyanAccent.withValues(alpha: 0.5),
                        elevation: 8,
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text(
                            _remainingSeconds > 0 
                              ? "LOCKED (${_formatDuration(_remainingSeconds)})" 
                              : "LOGIN",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "OR",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black45,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    GoogleSignInButton(
                      onPressed: (_isLoading || _isGoogleLoading || _remainingSeconds > 0) ? null : _handleGoogleSignIn,
                      isLoading: _isGoogleLoading,
                      label: "Continue with Google",
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

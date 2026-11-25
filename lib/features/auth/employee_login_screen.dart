import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/login_rate_limiter.dart';
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
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(_checkInputsForLockout);
    _shopCodeCtrl.addListener(_checkInputsForLockout);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _usernameCtrl.removeListener(_checkInputsForLockout);
    _shopCodeCtrl.removeListener(_checkInputsForLockout);
    _shopCodeCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String get _employeeIdentifier {
    final code = _shopCodeCtrl.text.trim().toLowerCase();
    final user = _usernameCtrl.text.trim().toLowerCase();
    if (code.isEmpty || user.isEmpty) return '';
    return '${code}_$user';
  }

  void _checkInputsForLockout() async {
    final id = _employeeIdentifier;
    if (id.isEmpty) return;
    final state = await LoginRateLimiter.getLockoutState(id);
    if (!mounted) return;
    if (state.isLocked) {
      _startLockoutCountdown(state.remainingSeconds);
    } else if (_remainingSeconds > 0 && state.remainingSeconds == 0) {
      setState(() => _remainingSeconds = 0);
    }
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

  void _showEmployeeForgotPasswordHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text("Staff Password Reset"),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Staff and cashier accounts are managed directly by your shop owner or manager.",
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              "If you forgot your password, please ask your shop owner or manager to update it for you under Shop Settings > Employee Management.",
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("OK, Got It"),
          ),
        ],
      ),
    );
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

    final id = _employeeIdentifier;
    final lockState = await LoginRateLimiter.getLockoutState(id);
    if (lockState.isLocked) {
      _startLockoutCountdown(lockState.remainingSeconds);
      if (mounted) {
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

    setState(() => _isLoading = true);

    try {
      // Reconstruct Synthetic Email
      final syntheticEmail = "${_usernameCtrl.text.trim().toLowerCase()}@${_shopCodeCtrl.text.trim().toLowerCase()}.sme";

      await ref.read(authRepositoryProvider).signInWithEmail(
        syntheticEmail, 
        _passCtrl.text.trim()
      );
      
      // Clear attempts on success
      await LoginRateLimiter.clearAttempts(id);

      // AuthGate will redirect
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);

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
             id,
             isFirebaseBlocked: isFirebaseBlocked,
           );
           if (!mounted) return;
           if (newState.isLocked) {
             _startLockoutCountdown(newState.remainingSeconds);
             message = isFirebaseBlocked
                 ? "Access temporarily blocked due to repeated failures. Try again in ${newState.formattedRemainingTime}."
                 : "Account locked out for security (${newState.formattedRemainingTime}). Please wait before trying again.";
           } else {
             final attemptsLeft = 3 - newState.failedAttempts;
             if (errorStr.contains("user-not-found")) {
               message = "Invalid Shop Code or Username ($attemptsLeft attempt${attemptsLeft == 1 ? '' : 's'} remaining)";
             } else {
               message = "Incorrect Password ($attemptsLeft attempt${attemptsLeft == 1 ? '' : 's'} remaining)";
             }
           }
         } else {
           message = "Error: ${errorStr.replaceAll(RegExp(r'\[.*?\]'), '').trim()}";
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
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showEmployeeForgotPasswordHelp,
                      child: const Text("Forgot Password?", style: TextStyle(color: Colors.cyanAccent)),
                    ),
                  ),
                  
                  if (_remainingSeconds > 0) ...[
                    const SizedBox(height: 24),
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
                                  "Login Suspended for Security",
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
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    const SizedBox(height: 32),
                  ],

                  ElevatedButton(
                    onPressed: (_isLoading || _remainingSeconds > 0) ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _remainingSeconds > 0 ? Colors.grey : Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 8,
                      shadowColor: Colors.blueAccent.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _remainingSeconds > 0 
                            ? "LOCKED (${_formatDuration(_remainingSeconds)})" 
                            : "LOGIN TO SHOP", 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
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

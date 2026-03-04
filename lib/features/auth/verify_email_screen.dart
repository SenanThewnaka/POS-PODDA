import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/auth/verification_service.dart';
import 'dart:math';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  void _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a 6-digit code")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception("User not found");

      // 1. Get Current Profile to check Code
      final profile = await ref.read(userProfileRepositoryProvider).getUserProfile(user.uid);
      
      if (profile == null) throw Exception("Profile not found");
      
      // 2. Validate
      if (profile.verificationCode == code) {
         // Success
         await ref.read(userProfileRepositoryProvider).saveUserProfile(
            profile.copyWith(isVerified: true, verificationCode: null) // Clear code ? Or keep for audit? Null is safer.
         );
         
         // 3. Refresh AuthGate
         ref.invalidate(userProfileProvider);
         // No need to invalidate authState unless we rely on emailVerified
      } else {
         throw Exception("Invalid Verification Code");
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resendCode() async {
     setState(() => _isLoading = true);
     try {
       final user = ref.read(authRepositoryProvider).currentUser;
       if (user == null) return;
       
       final newCode = (100000 + Random().nextInt(900000)).toString();
       final repo = ref.read(userProfileRepositoryProvider);
       
       // Update Code in DB
       final profile = await repo.getUserProfile(user.uid);
       if (profile != null) {
          await repo.saveUserProfile(profile.copyWith(verificationCode: newCode));
          
          // Send Email
          final success = await VerificationService.sendCode(user.email!, newCode);
          if (success) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New Code Sent! Check your email.")));
          } else {
             throw Exception("Failed to send email");
          }
       }
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
  }

  void _showUpdateEmailDialog() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Correct Email Address"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the correct email. We will send a new code."),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: "New Email", border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
               final newEmail = emailCtrl.text.trim();
               if (!newEmail.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Email")));
                  return;
               }
               
               Navigator.pop(ctx);
               setState(() => _isLoading = true);
               
               try {
                 final user = ref.read(authRepositoryProvider).currentUser;
                 if (user == null) return;
                 
                 // 1. Update Firebase Auth (Checks uniqueness automatically)
                 await user.updateEmail(newEmail);
                 
                 // 2. Update Firestore & Resend
                 final repo = ref.read(userProfileRepositoryProvider);
                 final profile = await repo.getUserProfile(user.uid);
                 
                 if (profile != null) {
                    final newCode = (100000 + Random().nextInt(900000)).toString();
                    
                    // Update Email AND Code in Firestore
                    await repo.saveUserProfile(profile.copyWith(
                      email: newEmail, 
                      verificationCode: newCode,
                      isVerified: false // Ensure it stays false
                    ));
                    
                    // Send to NEW email
                    await VerificationService.sendCode(newEmail, newCode);
                    
                    if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email Updated & Code Sent!"), backgroundColor: Colors.green));
                       setState(() {}); // Rebuild to show new email
                    }
                 }
               } catch (e) {
                 if (mounted) {
                    String msg = "Error updating email: $e";
                    if (e.toString().contains("email-already-in-use")) {
                       msg = "This email is already in use by another account.";
                    } else if (e.toString().contains("invalid-email")) {
                       msg = "Invalid email format.";
                    } else if (e.toString().contains("requires-recent-login")) {
                       msg = "Security: Please sign out and login again to change email.";
                    }
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
                 }
               } finally {
                 if (mounted) setState(() => _isLoading = false);
               }
            }, 
            child: const Text("UPDATE & RESEND")
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get user email
    final user = ref.watch(authRepositoryProvider).currentUser;
    final email = user?.email ?? "your email";

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.mark_email_unread, size: 80, color: Colors.cyanAccent),
                   const SizedBox(height: 24),
                   const Text("Verify your Email", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Flexible(
                         child: Text(
                           "We sent a custom code to $email", 
                           style: const TextStyle(color: Colors.grey), 
                           textAlign: TextAlign.center,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                       IconButton(
                         icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                         onPressed: _showUpdateEmailDialog,
                         tooltip: "Correct Email",
                       )
                     ],
                   ),
                   
                   const SizedBox(height: 32),
                   
                   TextField(
                     controller: _codeCtrl,
                     keyboardType: TextInputType.number,
                     textAlign: TextAlign.center,
                     style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                     maxLength: 6,
                     inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                     decoration: const InputDecoration(
                       hintText: "000000",
                       counterText: "",
                       border: OutlineInputBorder(),
                     ),
                   ),
                   
                   const SizedBox(height: 24),
                   
                   ElevatedButton(
                     onPressed: _isLoading ? null : _verifyCode, 
                     style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50)
                     ),
                     child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("VERIFY CODE"),
                   ),
                   
                   const SizedBox(height: 24),
                   
                   TextButton(
                     onPressed: _isLoading ? null : _resendCode,
                     child: const Text("Resend Code"),
                   ),
                   
                   const SizedBox(height: 8),
                   TextButton(
                     onPressed: () async {
                        await ref.read(authRepositoryProvider).signOut();
                     },
                     child: const Text("Cancel / Sign Out", style: TextStyle(color: Colors.grey)),
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

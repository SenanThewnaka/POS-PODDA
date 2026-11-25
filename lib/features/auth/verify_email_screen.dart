import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/user_repository.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _isLoading = false;

  Future<void> _resendVerification() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification link sent. Check your inbox and spam folder.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send the verification link: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() => _isLoading = true);
    try {
      final authRepository = ref.read(authRepositoryProvider);
      final user = await authRepository.reloadCurrentUser();
      if (user == null) throw StateError('No signed-in account was found.');
      if (!user.emailVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your email is not verified yet. Open the link in your email, then try again.')),
          );
        }
        return;
      }

      await user.getIdToken(true);
      ref.invalidate(authStateProvider);
      ref.invalidate(userProfileProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not confirm email verification: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final email = user?.email ?? 'your email address';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mark_email_unread, size: 80, color: Colors.cyanAccent),
                const SizedBox(height: 24),
                const Text('Verify your email', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  'Open the verification link sent to $email. Shop owner accounts must verify their email before continuing.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _checkVerification,
                    child: _isLoading ? const CircularProgressIndicator() : const Text("I'VE VERIFIED — CONTINUE"),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _resendVerification,
                  child: const Text('Resend verification link'),
                ),
                TextButton(
                  onPressed: _isLoading ? null : () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Use a different account / Sign out', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

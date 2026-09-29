import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/auth/login_screen.dart';
import 'package:sme_buddy/features/auth/verify_email_screen.dart';
import 'package:sme_buddy/features/home/dashboard_screen.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/auth/setup_shop_screen.dart';
import 'package:sme_buddy/utils/shimmer_skeletons.dart';
import 'package:sme_buddy/utils/biometric_lock_service.dart';
import 'package:sme_buddy/utils/analytics_service.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> with WidgetsBindingObserver {
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock app when it goes to background
    if (state == AppLifecycleState.paused) {
      BiometricLockService.isEnabled().then((enabled) {
        if (enabled && mounted) setState(() => _isLocked = true);
      });
    }
    // Prompt when app comes back to foreground
    if (state == AppLifecycleState.resumed && _isLocked) {
      _unlock();
    }
  }

  Future<void> _unlock() async {
    final success = await BiometricLockService.authenticate();
    if (success && mounted) setState(() => _isLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    // Show lock screen if biometric lock is active
    if (_isLocked) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 24),
              const Text('POS Podda is Locked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Authenticate to continue', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _unlock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }

        final userProfileAsync = ref.watch(userProfileProvider);

        return userProfileAsync.when(
          data: (profile) {
            if (profile == null) return const SetupShopScreen();
            if (!profile.isActive) {
              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Your account has been deactivated by the shop owner.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                  ),
                ),
              );
            }

            // Set Analytics user properties on every app open
            AnalyticsService.setUserProperties(
              userId: profile.uid,
              plan: profile.plan,
              role: profile.role,
            );

            return const DashboardScreen();
          },
          loading: () => const ShimmerFullPage(),
          error: (e, st) => Scaffold(body: Center(child: Text('Profile Error: $e'))),
        );
      },
      loading: () => const ShimmerFullPage(),
      error: (e, st) => Scaffold(body: Center(child: Text('Auth Error: $e'))),
    );
  }
}

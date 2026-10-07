import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/subscription/plans_screen.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/utils/device_session_service.dart';
import 'package:sme_buddy/utils/glass_card.dart';
import 'package:sme_buddy/utils/glass_scaffold.dart';

class SessionConflictScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const SessionConflictScreen({super.key, required this.user});

  @override
  ConsumerState<SessionConflictScreen> createState() => _SessionConflictScreenState();
}

class _SessionConflictScreenState extends ConsumerState<SessionConflictScreen> {
  bool _isClaiming = false;

  Future<void> _takeOverSession() async {
    setState(() => _isClaiming = true);
    try {
      await DeviceSessionService.claimActiveSession(
        user: widget.user,
        ref: ref,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Counter activated on this device!"),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to take over: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final otherDevice = widget.user.activeDeviceName ?? "Another Terminal";
    final claimedTime = widget.user.lastSessionClaimedAt != null
        ? DateFormat('hh:mm a, MMM dd').format(widget.user.lastSessionClaimedAt!)
        : "Just now";

    return GlassScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: GlassCard(
              padding: const EdgeInsets.all(32.0),
              border: Border.all(
                color: Colors.orangeAccent.withValues(alpha: 0.5),
                width: 1.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ICON HEADER
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.orangeAccent.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.phonelink_lock_rounded,
                        color: Colors.orangeAccent,
                        size: 42,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // TITLE
                  Text(
                    "Active on Another Device",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // EXPLANATION
                  Text(
                    "Your POS Podda account was opened on:\n",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),

                  // DEVICE INFO CARD
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.devices, size: 20, color: Colors.cyanAccent),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "$otherDevice • $claimedTime",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.cyanAccent : Colors.blueAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    "The Plus plan is licensed for 1 active device at a time. To run multiple counters or cashiers simultaneously, you can upgrade to the Pro plan anytime.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // CTA 1: TAKE OVER
                  ElevatedButton.icon(
                    onPressed: _isClaiming ? null : _takeOverSession,
                    icon: _isClaiming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(
                      _isClaiming ? "CONNECTING..." : "USE ON THIS DEVICE",
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // CTA 2: UPGRADE TO PRO (MULTI-DEVICE)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PlansScreen()),
                      );
                    },
                    icon: const Icon(Icons.star_rounded, color: Colors.amber),
                    label: const Text(
                      "UPGRADE TO PRO (MULTI-COUNTER)",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CTA 3: SIGN OUT
                  TextButton(
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                    child: Text(
                      "Sign Out",
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class LoginLockoutState {
  final bool isLocked;
  final int remainingSeconds;
  final int failedAttempts;
  final String? message;

  const LoginLockoutState({
    required this.isLocked,
    required this.remainingSeconds,
    required this.failedAttempts,
    this.message,
  });

  String get formattedRemainingTime {
    if (remainingSeconds <= 0) return '0s';
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    if (minutes > 0) {
      return '$minutes min ${seconds.toString().padLeft(2, '0')} sec';
    }
    return '$seconds sec';
  }
}

class LoginRateLimiter {
  static const int _decayWindowMs = 30 * 60 * 1000; // 30 minutes

  static String _keyPrefix(String identifier) {
    final sanitized = identifier
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'rate_limit_$sanitized';
  }

  /// Checks current lockout status for an identifier (email, shopCode+user, etc.)
  static Future<LoginLockoutState> getLockoutState(String identifier) async {
    if (identifier.trim().isEmpty) {
      return const LoginLockoutState(
        isLocked: false,
        remainingSeconds: 0,
        failedAttempts: 0,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final prefix = _keyPrefix(identifier);
    final now = DateTime.now().millisecondsSinceEpoch;

    final lockedUntil = prefs.getInt('${prefix}_locked_until') ?? 0;
    final lastAttempt = prefs.getInt('${prefix}_last_attempt') ?? 0;
    var attempts = prefs.getInt('${prefix}_attempts') ?? 0;

    // If locked until a future time
    if (lockedUntil > now) {
      final remainingSec = ((lockedUntil - now) / 1000).ceil();
      return LoginLockoutState(
        isLocked: true,
        remainingSeconds: remainingSec,
        failedAttempts: attempts,
        message: 'Temporarily locked out due to multiple failed login attempts.',
      );
    }

    // Auto-decay if idle for more than 30 minutes
    if (attempts > 0 && (now - lastAttempt) > _decayWindowMs) {
      await clearAttempts(identifier);
      attempts = 0;
    }

    return LoginLockoutState(
      isLocked: false,
      remainingSeconds: 0,
      failedAttempts: attempts,
    );
  }

  /// Records a failed attempt and updates lockout timers accordingly
  static Future<LoginLockoutState> recordFailedAttempt(
    String identifier, {
    bool isFirebaseBlocked = false,
  }) async {
    if (identifier.trim().isEmpty) {
      return const LoginLockoutState(
        isLocked: false,
        remainingSeconds: 0,
        failedAttempts: 0,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final prefix = _keyPrefix(identifier);
    final now = DateTime.now().millisecondsSinceEpoch;

    var attempts = (prefs.getInt('${prefix}_attempts') ?? 0) + 1;
    if (isFirebaseBlocked) {
      attempts = max(attempts, 5);
    }

    int lockoutDurationSec = 0;
    if (isFirebaseBlocked) {
      lockoutDurationSec = 300; // 5 minutes minimum for server-side block
    } else if (attempts >= 6) {
      lockoutDurationSec = 900; // 15 minutes
    } else if (attempts == 5) {
      lockoutDurationSec = 300; // 5 minutes
    } else if (attempts == 4) {
      lockoutDurationSec = 60; // 1 minute
    } else if (attempts == 3) {
      lockoutDurationSec = 30; // 30 seconds
    }

    final lockedUntil = lockoutDurationSec > 0 ? (now + (lockoutDurationSec * 1000)) : 0;

    await prefs.setInt('${prefix}_attempts', attempts);
    await prefs.setInt('${prefix}_last_attempt', now);
    await prefs.setInt('${prefix}_locked_until', lockedUntil);

    return LoginLockoutState(
      isLocked: lockoutDurationSec > 0,
      remainingSeconds: lockoutDurationSec,
      failedAttempts: attempts,
      message: lockoutDurationSec > 0
          ? 'Too many failed login attempts. Account temporarily locked for $lockoutDurationSec seconds.'
          : (attempts >= 2 ? 'Warning: ${3 - attempts} attempt(s) remaining before temporary lockout.' : null),
    );
  }

  /// Clears failed attempt tracking on successful login
  static Future<void> clearAttempts(String identifier) async {
    if (identifier.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final prefix = _keyPrefix(identifier);
    await prefs.remove('${prefix}_attempts');
    await prefs.remove('${prefix}_last_attempt');
    await prefs.remove('${prefix}_locked_until');
  }
}

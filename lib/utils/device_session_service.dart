import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/users/user_repository.dart';

class DeviceSessionService {
  static const String _sessionKey = 'pos_device_session_id';
  static String? _cachedSessionId;

  /// Retrieves or initializes a unique session ID for this specific device/browser
  static Future<String> getLocalSessionId() async {
    if (_cachedSessionId != null) return _cachedSessionId!;
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_sessionKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_sessionKey, id);
    }
    _cachedSessionId = id;
    return id;
  }

  /// Synchronous getter if already loaded
  static String? get currentLocalSessionId => _cachedSessionId;

  /// Human-readable description of current platform / browser
  static String getDeviceName() {
    if (kIsWeb) {
      return 'Web Browser (${kIsWasm ? "Wasm" : "JS"})';
    }
    try {
      if (Platform.isAndroid) return 'Android Device';
      if (Platform.isIOS) return 'Apple iOS Device';
      if (Platform.isMacOS) return 'macOS Workstation';
      if (Platform.isWindows) return 'Windows Terminal';
      if (Platform.isLinux) return 'Linux Device';
    } catch (_) {}
    return 'Authorized Terminal';
  }

  /// Determines whether the current device is in conflict with another active device
  /// Single-device constraint strictly applies to Plus and Starter tiers.
  /// Pro tier accounts enjoy unlimited concurrent devices.
  static bool hasSessionConflict({
    required UserModel user,
    required String localSessionId,
  }) {
    // Pro Tier allows unlimited multi-counter / multi-device sessions
    if (user.plan.toLowerCase() == 'pro') {
      return false;
    }

    // If no active session recorded yet, no conflict
    if (user.activeSessionId == null || user.activeSessionId!.isEmpty) {
      return false;
    }

    // Conflict exists if another device holds the active session lock
    return user.activeSessionId != localSessionId;
  }

  /// Claims this device as the single active counter, kicking any other device
  static Future<void> claimActiveSession({
    required UserModel user,
    required WidgetRef ref,
  }) async {
    final sessionId = await getLocalSessionId();
    final deviceName = getDeviceName();

    final updated = user.copyWith(
      activeSessionId: sessionId,
      activeDeviceName: deviceName,
      lastSessionClaimedAt: DateTime.now(),
    );

    await ref.read(userProfileRepositoryProvider).saveUserProfile(updated);
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Handles biometric / PIN app lock feature
class BiometricLockService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const _enabledKey = 'biometric_lock_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  // Check if device actually supports biometrics
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  // Returns true if auth passed (or if lock isn't enabled)
  static Future<bool> authenticate() async {
    final enabled = await isEnabled();
    if (!enabled) return true;
    if (!await isAvailable()) return true;

    try {
      return await _auth.authenticate(
        localizedReason: 'Verify your identity to open POS Podda',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

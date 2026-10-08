import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'sound_service_stub.dart'
    if (dart.library.js_interop) 'sound_service_web.dart';

class SoundService {
  /// Plays a laser scan confirmation sound (audible beep on Web, click + haptic on Mobile/Desktop)
  static void playScanSuccess() {
    try {
      if (kIsWeb) {
        playWebBeep(true);
      } else {
        SystemSound.play(SystemSoundType.click);
      }
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Plays a scan failure warning sound (buzz on Web, alert + vibrate on Mobile/Desktop)
  static void playScanError() {
    try {
      if (kIsWeb) {
        playWebBeep(false);
      } else {
        SystemSound.play(SystemSoundType.alert);
      }
      HapticFeedback.vibrate();
    } catch (_) {}
  }
}

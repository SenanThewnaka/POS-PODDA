import 'package:flutter/foundation.dart';
import 'web_loader_stub.dart'
    if (dart.library.js_interop) 'web_loader_web.dart';

class WebLoader {
  static void hide() {
    if (kIsWeb) {
      hideWebLoader();
    }
  }
}

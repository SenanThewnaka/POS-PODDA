import 'dart:js_interop';

@JS('hideAppLoading')
external void _hideAppLoading();

void hideWebLoader() {
  try {
    _hideAppLoading();
  } catch (_) {}
}

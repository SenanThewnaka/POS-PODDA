import 'dart:js_interop';

@JS('posPlayBeep')
external void _posPlayBeep(JSBoolean isSuccess);

void playWebBeep(bool isSuccess) {
  try {
    _posPlayBeep(isSuccess.toJS);
  } catch (_) {}
}

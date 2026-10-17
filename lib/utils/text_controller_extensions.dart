import 'package:flutter/material.dart';

extension TextEditingControllerSelectAllExtension on TextEditingController {
  /// Selects all text inside the controller if not empty.
  /// Useful for POS inputs where tapping an existing value should allow
  /// immediate overwriting without requiring double-tap or manual backspacing.
  void selectAll() {
    if (text.isNotEmpty) {
      selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sme_buddy/utils/text_controller_extensions.dart';

void main() {
  test('TextEditingController.selectAll selects entire text when not empty', () {
    final controller = TextEditingController(text: '5000');
    expect(controller.selection.baseOffset, -1);
    expect(controller.selection.extentOffset, -1);

    controller.selectAll();
    expect(controller.selection.baseOffset, 0);
    expect(controller.selection.extentOffset, 4);

    // If text is empty, it does not throw
    final emptyController = TextEditingController(text: '');
    emptyController.selectAll();
    expect(emptyController.selection.baseOffset, -1);
  });
}

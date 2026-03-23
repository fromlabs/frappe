import 'package:frappe/frappe.dart';

import '../../domain/logic/keypad.dart';
import '../../domain/models.dart';
import '../../domain/port/pump.dart';

/// Chapter 4a: Keypad-only demo — shows preset value and beeps.
class KeypadPump extends BasePump {
  /// Produces the preset LCD display value and a beep stream on valid key presses.
  @override
  Outputs create(Inputs inputs) {
    final keypad = Keypad(
      keypadStream: inputs.keypadStream,
      activeState: ValueState.constant(true),
      clearStream: EventStream.never(),
    );

    return Outputs.defaults(
      presetLcdState: keypad.valueState.map((value) => value.toString()),
      beepStream: keypad.beepStream,
    );
  }
}

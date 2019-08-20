import 'package:frappe/frappe.dart';

import '../logic/keypad.dart';
import '../model.dart';
import '../petrol_pump.dart';

class KeypadPump extends BasePump {
  @override
  Outputs create(Inputs inputs) {
    final keypad = Keypad(
      keypadStream: inputs.keypadStream,
      activeState: ValueState.constant(true),
      clearStream: EventStream.never(),
    );

    return Outputs.fromDefault(
      (builder) => builder
        ..presetLcdState = keypad.valueState.map((value) => value.toString())
        ..beepStream = keypad.beepStream,
    );
  }
}

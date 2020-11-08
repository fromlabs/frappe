import 'package:frappe/frappe.dart';
import 'package:testapp/keypad/keypad_model.dart';

// functional logic unit

class KeypadFlutOutput {
  final ValueState<int> valueState;
  final EventStream<Unit> beepStream;

  KeypadFlutOutput({required this.valueState, required this.beepStream});
}

KeypadFlutOutput keypadFlut({
  required EventStream<NumericKey> keypadStream,
}) {
  final valueStateLink = ValueStateLink<int>();

  final updateValueStream =
      keypadStream.snapshot<int, int?>(valueStateLink.state, (key, value) {
    if (key == NumericKey.clear) {
      return 0;
    } else {
      final value10 = value * 10;

      if (value10 <= 100000) {
        return value10 + NumericKey.values.indexOf(key);
      } else {
        return null;
      }
    }
  });

  valueStateLink.connect(updateValueStream.whereType<int>().toState(0));

  return KeypadFlutOutput(
      valueState: valueStateLink.state,
      beepStream: updateValueStream
          .whereNull()
          .mapToUnit()
          .orElse(keypadStream.whereValue(NumericKey.clear).mapToUnit()));
}

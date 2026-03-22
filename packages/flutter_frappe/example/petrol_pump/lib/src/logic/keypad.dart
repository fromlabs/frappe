import 'package:frappe/frappe.dart';

import '../model.dart';

/// Manages numeric keypad input, producing an integer preset value.
class Keypad {
  final ValueState<int> valueState;
  final EventStream<Unit> beepStream;

  factory Keypad({
    required EventStream<NumericKey> keypadStream,
    required EventStream<Unit> clearStream,
    required ValueState<bool> activeState,
  }) {
    final valueStateRef = ValueStateLink<int>();

    final validKeyStream = keypadStream.gate(activeState);

    final updateValueStream = validKeyStream
        .snapshot<int, int?>(valueStateRef.state, (key, value) {
          if (key == NumericKey.clear) {
            return 0;
          }
          final value10 = value * 10;
          if (value10 > 1000) return null;
          // Map key to its numeric digit and add to accumulated value.
          return switch (key) {
            NumericKey.zero => value10,
            NumericKey.one => value10 + 1,
            NumericKey.two => value10 + 2,
            NumericKey.three => value10 + 3,
            NumericKey.four => value10 + 4,
            NumericKey.five => value10 + 5,
            NumericKey.six => value10 + 6,
            NumericKey.seven => value10 + 7,
            NumericKey.eight => value10 + 8,
            NumericKey.nine => value10 + 9,
            NumericKey.clear => throw StateError('Unreachable'),
          };
        })
        .mapWhereNotNull();

    valueStateRef
        .connect(updateValueStream.orElse(clearStream.mapTo(0)).toState(0));

    final beepStream = updateValueStream.mapToUnit();

    return Keypad._(
      valueState: valueStateRef.state,
      beepStream: beepStream,
    );
  }

  Keypad._({
    required this.valueState,
    required this.beepStream,
  });
}

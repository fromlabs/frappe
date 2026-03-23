import 'package:frappe/frappe.dart';

import '../model.dart';

/// Manages numeric keypad input, producing an integer preset value.
class Keypad {
  /// The current accumulated integer value entered on the keypad.
  final ValueState<int> valueState;

  /// Fires whenever a valid key press is accepted (used to trigger a beep).
  final EventStream<Unit> beepStream;

  factory Keypad({
    required EventStream<NumericKey> keypadStream,
    required EventStream<Unit> clearStream,
    required ValueState<bool> activeState,
  }) {
    // Keypad value resets on clearStream, updates on key press.
    // loopWith extracts beepStream built inside the cycle.
    final (valueState, beepStream) =
        ValueState.loopWith((ValueState<int> self) {
      // Gate blocks key events when the keypad is inactive (e.g., during slow delivery).
      final validKeyStream = keypadStream.gate(activeState);

      // Shift the current value left by one decimal place and append the new digit.
      // Returns null (filtered out below) if the result would exceed 1000.
      final updateValueStream = validKeyStream
          .snapshot<int, int?>(self, (key, value) {
            if (key == NumericKey.clear) {
              return 0;
            }
            final value10 = value * 10;
            // Cap at 1000 to prevent unreasonably large preset amounts.
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

      return (
        updateValueStream.orElse(clearStream.mapTo(0)).toState(0),
        updateValueStream.mapToUnit(),
      );
    });

    return Keypad._(
      valueState: valueState,
      beepStream: beepStream,
    );
  }

  /// References all reactive fields via [collector], keeping them alive
  /// until the collector is disposed. Returns `this` for chaining.
  Keypad hold(FrappeReferenceCollector collector) {
    collector
      ..add(valueState)
      ..add(beepStream);
    return this;
  }

  Keypad._({
    required this.valueState,
    required this.beepStream,
  });
}

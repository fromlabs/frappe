import 'package:meta/meta.dart';
import 'package:optional/optional.dart';
import 'package:frappe/frappe.dart';
import '../model.dart';
import '../petrol_pump.dart';

class Keypad extends BaseObserver {
  final ValueState<int> valueState;

  final EventStream<Unit> beepStream;

  factory Keypad({
    @required EventStream<NumericKey> keypadStream,
    @required EventStream<Unit> clearStream,
    @required ValueState<bool> activeState,
  }) {
    final valueStateRef = ValueStateLink();

    final validKeyStream = keypadStream.gate(activeState);

    final updateValueStream = validKeyStream
        .snapshot<int, Optional<int>>(valueStateRef.state, (key, value) {
          if (key == NumericKey.clear) {
            return Optional<int>.of(0);
          } else {
            final value10 = value * 10;
            if (value10 <= 1000) {
              switch (key) {
                case NumericKey.zero:
                  return Optional<int>.of(value10);
                case NumericKey.one:
                  return Optional<int>.of(value10 + 1);
                case NumericKey.two:
                  return Optional<int>.of(value10 + 2);
                case NumericKey.three:
                  return Optional<int>.of(value10 + 3);
                case NumericKey.four:
                  return Optional<int>.of(value10 + 4);
                case NumericKey.five:
                  return Optional<int>.of(value10 + 5);
                case NumericKey.six:
                  return Optional<int>.of(value10 + 6);
                case NumericKey.seven:
                  return Optional<int>.of(value10 + 7);
                case NumericKey.eight:
                  return Optional<int>.of(value10 + 8);
                case NumericKey.nine:
                  return Optional<int>.of(value10 + 9);
                case NumericKey.clear:
                  throw Error();
                default:
                  throw Error();
              }
            } else {
              return Optional<int>.empty();
            }
          }
        })
        .asOptional<int>()
        .mapWhereOptional();

    valueStateRef
        .connect(updateValueStream.orElse(clearStream.mapTo(0)).toState(0));

    final beepStream = updateValueStream.mapTo(unit);

    return Keypad._(
      valueState: valueStateRef.state,
      beepStream: beepStream,
    );
  }
  Keypad._({
    this.valueState,
    this.beepStream,
  });
}

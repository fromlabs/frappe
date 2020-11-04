import 'package:frappe/frappe.dart';

void main() {
  final disposableCollector = DisposableCollector();

  final keypadSink = EventStreamSink<NumericKey>();
  disposableCollector.add(keypadSink.toDisposable());

  runTransaction(() {
    final keypad = Keypad(keypadStream: keypadSink.stream);

    disposableCollector.add((keypad.valueState
            .listen(print)
            .append(keypad.beepStream.listen((_) => print('BEEP!'))))
        .toDisposable());
  });

  keypadSink.send(NumericKey.five);
  keypadSink.send(NumericKey.six);
  keypadSink.send(NumericKey.seven);
  keypadSink.send(NumericKey.eight);
  keypadSink.send(NumericKey.nine);
  keypadSink.send(NumericKey.zero);

  keypadSink.send(NumericKey.clear);

  disposableCollector.dispose();

  // assert that all listeners are canceled
  FrappeObject.assertCleanState();
}

// functional logic unit
class Keypad {
  late final ValueState<int> valueState;

  late final EventStream<Unit> beepStream;

  Keypad({
    required EventStream<NumericKey> keypadStream,
  }) {
    final valueStateLink = ValueStateLink<int>();

    valueState = valueStateLink.state;

    valueStateLink.connect(keypadStream
        .snapshot<int, int>(
            valueState,
            (key, total) => key != NumericKey.clear
                ? (total < 9999
                    ? (total * 10) + NumericKey.values.indexOf(key)
                    : total)
                : 0)
        .toState(0));

    beepStream = keypadStream
        .snapshot<int, bool>(valueState,
            (key, total) => key != NumericKey.clear ? (total >= 9999) : false)
        .where((value) => value == true)
        .mapTo(unit);
  }
}

enum NumericKey {
  zero,
  one,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  clear
}

import 'package:frappe/frappe.dart';

void main() {
  final disposableCollector = DisposableCollector();

  final keypadBloc = disposableCollector.add(KeypadBloc());

  disposableCollector.add((keypadBloc.valueState
          .listen(print)
          .append(keypadBloc.beepStream.listen((_) => print('BEEP!'))))
      .toDisposable());

  keypadBloc.five();
  keypadBloc.six();
  keypadBloc.seven();
  keypadBloc.eight();
  keypadBloc.nine();
  keypadBloc.zero();

  keypadBloc.clear();

  disposableCollector.dispose();

  // assert that all listeners are canceled
  FrappeObject.assertCleanState();
}

// business logic component
class KeypadBloc implements Disposable {
  final EventStreamSink<NumericKey> _keypadSink = EventStreamSink<NumericKey>();

  late final FrappeReference<ValueState<int>> _valueStateReference;

  late final FrappeReference<EventStream<Unit>> _beepStreamReference;

  final _disposableCollector = DisposableCollector();

  KeypadBloc() {
    _disposableCollector.add(_keypadSink.toDisposable());

    runTransaction(() {
      final _keypad = Keypad(keypadStream: _keypadSink.stream);

      _valueStateReference =
          _disposableCollector.add(_keypad.valueState.toReference());
      _beepStreamReference =
          _disposableCollector.add(_keypad.beepStream.toReference());
    });
  }

  @override
  void dispose() {
    _disposableCollector.dispose();
  }

  ValueState<int> get valueState => _valueStateReference.object;

  EventStream<Unit> get beepStream => _beepStreamReference.object;

  void zero() => _keypadSink.send(NumericKey.zero);

  void one() => _keypadSink.send(NumericKey.one);

  void two() => _keypadSink.send(NumericKey.two);

  void three() => _keypadSink.send(NumericKey.three);

  void four() => _keypadSink.send(NumericKey.four);

  void five() => _keypadSink.send(NumericKey.five);

  void six() => _keypadSink.send(NumericKey.six);

  void seven() => _keypadSink.send(NumericKey.seven);

  void eight() => _keypadSink.send(NumericKey.eight);

  void nine() => _keypadSink.send(NumericKey.nine);

  void clear() => _keypadSink.send(NumericKey.clear);
}

abstract class FrappeBloc implements Disposable {
  final _disposableCollector = DisposableCollector();

  @override
  void dispose() {
    _disposableCollector.dispose();
  }
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

// Keypad with BLoC pattern.
//
// Demonstrates: FrappeBloc base class, registerEventStream/registerValueState,
// separation of business logic (BLoC) from functional logic (Flut).
import 'package:frappe/frappe.dart';

void main() {
  final scope = ReactiveScope();

  scope.run(() {
    final keypadBloc = KeypadBloc();

    final sub = scope.runTransaction(() => keypadBloc.valueState
        .listen(print)
        .append(keypadBloc.beepStream.listen((_) => print('BEEP!'))));

    keypadBloc.five();
    keypadBloc.six();
    keypadBloc.seven();
    keypadBloc.eight();
    keypadBloc.nine();
    keypadBloc.zero();

    keypadBloc.clear();

    keypadBloc.eight();
    keypadBloc.nine();
    keypadBloc.zero();

    sub.cancel();
    keypadBloc.dispose();

    scope.assertCleanState();
  });

  scope.dispose();
}

// business logic component
class KeypadBloc extends FrappeBloc {
  late final EventStreamSink<NumericKey> _keypadSink;
  late final ValueState<int> _valueState;
  late final EventStream<Unit> _beepStream;

  @override
  void init() {
    _keypadSink = EventStreamSink<NumericKey>();

    final keypadFlut = KeypadFlut(keypadStream: _keypadSink.stream);

    _valueState = registerValueState(keypadFlut.valueState);
    _beepStream = registerEventStream(keypadFlut.beepStream);
  }

  ValueState<int> get valueState => _valueState;
  EventStream<Unit> get beepStream => _beepStream;

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

// functional logic unit
class KeypadFlut {
  late final ValueState<int> valueState;
  late final EventStream<Unit> beepStream;

  KeypadFlut({required EventStream<NumericKey> keypadStream}) {
    final valueStateLink = ValueStateLink<int>();
    valueState = valueStateLink.state;

    final updateValueStream =
        keypadStream.snapshot<int, int?>(valueState, (key, value) {
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

    beepStream = updateValueStream
        .where((value) => value == null)
        .mapToUnit()
        .orElse(keypadStream
            .where((value) => value == NumericKey.clear)
            .mapToUnit());
  }
}

enum NumericKey {
  zero, one, two, three, four, five, six, seven, eight, nine, clear
}

/// Reusable base class for BLoC pattern with Frappe.
abstract class FrappeBloc implements Disposable {
  final _references = <FrappeReference>[];

  FrappeBloc() {
    ReactiveScope.current.runTransaction(init);
  }

  void init();

  EventStream<E> registerEventStream<E>(EventStream<E> eventStream) {
    _references.add(eventStream.toReference());
    return eventStream;
  }

  ValueState<V> registerValueState<V>(ValueState<V> valueState) {
    _references.add(valueState.toReference());
    return valueState;
  }

  @override
  void dispose() {
    for (final ref in _references) {
      ref.dispose();
    }
  }
}

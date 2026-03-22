// ignore_for_file: avoid_print

// Error handling in listeners.
//
// Demonstrates that a throw inside a listener does not block
// the transaction - the error is caught and reported by the
// transaction's onError handler.
import 'package:frappe/frappe.dart';

void main() {
  final keypadBloc = KeypadBloc();

  final sub = runTransaction(() => keypadBloc.valueState
          .listen(print)
          .append(keypadBloc.beepStream.listen((_) {
        print('BEEP!');
        // This error is caught by the transaction's publish phase
        throw Error();
      })));

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
}

// (Same BLoC/Flut/enum/FrappeBloc as example3)
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
  void five() => _keypadSink.send(NumericKey.five);
  void six() => _keypadSink.send(NumericKey.six);
  void seven() => _keypadSink.send(NumericKey.seven);
  void eight() => _keypadSink.send(NumericKey.eight);
  void nine() => _keypadSink.send(NumericKey.nine);
  void clear() => _keypadSink.send(NumericKey.clear);
}

class KeypadFlut {
  late final ValueState<int> valueState;
  late final EventStream<Unit> beepStream;

  KeypadFlut({required EventStream<NumericKey> keypadStream}) {
    final valueStateLink = ValueStateLink<int>();
    valueState = valueStateLink.state;
    final updateValueStream =
        keypadStream.snapshot<int, int?>(valueState, (key, value) {
      if (key == NumericKey.clear) return 0;
      final value10 = value * 10;
      return value10 <= 100000
          ? value10 + NumericKey.values.indexOf(key)
          : null;
    });
    valueStateLink.connect(updateValueStream.whereType<int>().toState(0));
    beepStream = updateValueStream
        .where((value) => value == null)
        .mapToUnit()
        .orElse(keypadStream.where((v) => v == NumericKey.clear).mapToUnit());
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

abstract class FrappeBloc implements Disposable {
  final _references = <FrappeReference>[];
  FrappeBloc() {
    runTransaction(init);
  }
  void init();
  EventStream<E> registerEventStream<E>(EventStream<E> es) {
    _references.add(es.toReference());
    return es;
  }

  ValueState<V> registerValueState<V>(ValueState<V> vs) {
    _references.add(vs.toReference());
    return vs;
  }

  @override
  void dispose() {
    for (final ref in _references) {
      ref.dispose();
    }
  }
}

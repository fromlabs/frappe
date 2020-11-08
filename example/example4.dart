import 'package:frappe/frappe.dart';
import 'package:meta/meta.dart';

void main() {
  final disposableCollector = DisposableCollector();

  final keypadBloc = disposableCollector.add(KeypadBloc());

  disposableCollector.add((keypadBloc.valueState
      .listen(print)
      .append(keypadBloc.beepStream.listen((_) {
    print('BEEP!');

    throw Error();
  }))).toDisposable());

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

  disposableCollector.dispose();

  // assert that all references are disposed
  FrappeObject.assertCleanState();
}

// business logic component
class KeypadBloc extends FrappeBloc {
  late final EventStreamSink<NumericKey> _keypadSink;

  late final ValueState<int> _valueState;
  late final EventStream<Unit> _beepStream;

  @override
  void init() {
    _keypadSink = createEventStreamSink<NumericKey>();

    final _keypadFlut = KeypadFlut(keypadStream: _keypadSink.stream);

    _valueState = registerValueState(_keypadFlut.valueState);
    _beepStream = registerEventStream(_keypadFlut.beepStream);
  }

  // outputs
  ValueState<int> get valueState => _valueState;
  EventStream<Unit> get beepStream => _beepStream;

  // commands
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

  KeypadFlut({
    required EventStream<NumericKey> keypadStream,
  }) {
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
  final _disposableCollector = DisposableCollector();

  FrappeBloc() {
    runTransaction(init);
  }

  @protected
  void init();

  @protected
  EventStreamSink<E> createEventStreamSink<E>([Merger<E>? merger]) =>
      registerEventStreamSink(EventStreamSink<E>(merger));

  @protected
  ValueStateSink<V> createValueStateSink<V>(V initValue, [Merger<V>? merger]) =>
      registerValueStateSink(ValueStateSink<V>(initValue, merger));

  @protected
  EventStreamSink<E> registerEventStreamSink<E>(
      EventStreamSink<E> eventStreamSink) {
    _disposableCollector.add(eventStreamSink.toDisposable());

    return eventStreamSink;
  }

  @protected
  ValueStateSink<V> registerValueStateSink<V>(
      ValueStateSink<V> valueStateSink) {
    _disposableCollector.add(valueStateSink.toDisposable());

    return valueStateSink;
  }

  @protected
  EventStream<E> registerEventStream<E>(EventStream<E> eventStream) {
    _disposableCollector.add(eventStream.toReference());

    return eventStream;
  }

  @protected
  ValueState<V> registerValueState<V>(ValueState<V> valueState) {
    _disposableCollector.add(valueState.toReference());

    return valueState;
  }

  @override
  void dispose() {
    _disposableCollector.dispose();
  }
}

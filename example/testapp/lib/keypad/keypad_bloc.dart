import 'package:frappe/frappe.dart';
import 'package:testapp/core/frappe_bloc.dart';
import 'package:testapp/keypad/keypad_flut.dart';
import 'package:testapp/keypad/keypad_model.dart';

// business logic component
abstract class KeypadBloc implements Bloc {
  // outputs
  ValueState<int> get valueState;
  EventStream<Unit> get beepStream;

  // commands
  void digit(int keypadDigit);
  void clear();
}

class KeypadBlocImpl extends BaseBloc implements KeypadBloc {
  late final EventStreamSink<NumericKey> _keypadSink;

  late final ValueState<int> _valueState;
  late final EventStream<Unit> _beepStream;

  @override
  void create() {
    _keypadSink = EventStreamSink<NumericKey>();

    final _keypadFlutOutput = keypadFlut(keypadStream: _keypadSink.stream);

    _valueState = registerValueState(_keypadFlutOutput.valueState);
    _beepStream = registerEventStream(_keypadFlutOutput.beepStream);
  }

  // outputs
  @override
  ValueState<int> get valueState => _valueState;

  @override
  EventStream<Unit> get beepStream => _beepStream;

  // commands
  @override
  void digit(int keypadDigit) =>
      _keypadSink.send(NumericKey.values[keypadDigit]);

  @override
  void clear() => _keypadSink.send(NumericKey.clear);
}

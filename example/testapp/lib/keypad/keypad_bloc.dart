import 'package:frappe/frappe.dart';
import 'package:testapp/core/frappe_bloc.dart';
import 'package:testapp/keypad/keypad_flut.dart';
import 'package:testapp/keypad/keypad_model.dart';

// business logic component
abstract class KeypadBloc implements Bloc<int> {
  // streams
  EventStream<Unit> get beepStream;

  // commands
  void digit(int keypadDigit);
  void clear();
}

class KeypadBlocImpl extends BaseBloc<int> implements KeypadBloc {
  late final EventStreamSink<NumericKey> _keypadSink;

  late final EventStream<Unit> _beepStream;

  @override
  ValueState<int> init() {
    _keypadSink = EventStreamSink<NumericKey>();

    final _keypadFlutOutput = keypadFlut(keypadStream: _keypadSink.stream);

    _beepStream = registerEventStream(_keypadFlutOutput.beepStream);

    return _keypadFlutOutput.valueState;
  }

  // outputs
  @override
  EventStream<Unit> get beepStream => _beepStream;

  // commands
  @override
  void digit(int keypadDigit) =>
      _keypadSink.send(NumericKey.values[keypadDigit]);

  @override
  void clear() => _keypadSink.send(NumericKey.clear);
}

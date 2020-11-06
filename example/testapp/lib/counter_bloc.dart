import 'package:frappe/frappe.dart';
import 'package:testapp/frappe_bloc.dart';

class CounterBloc extends FrappeBloc {
  late final EventStreamSink<Unit> _incrementSink;

  late final ValueState<int> _valueState;

  @override
  void init() {
    _incrementSink = createEventStreamSink<Unit>();

    final stateLink = ValueStateLink<int>();

    stateLink.connect(_incrementSink.stream
        .snapshot<int, int>(stateLink.state, (_, value) => value + 1)
        .toState(0));

    _valueState = registerValueState(stateLink.state);
  }

  // queries
  ValueState<int> get valueState => _valueState;

  // commands
  void increment() => _incrementSink.sendUnit();
}

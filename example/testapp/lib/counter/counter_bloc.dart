import 'package:frappe/frappe.dart';
import 'package:testapp/core/frappe_bloc.dart';

class CounterBloc extends BaseBloc {
  late final EventStreamSink<Unit> _incrementSink;

  late final ValueState<int> _valueState;

  @override
  void create() {
    _incrementSink = EventStreamSink<Unit>();

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

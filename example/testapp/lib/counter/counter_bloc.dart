import 'package:frappe/frappe.dart';
import 'package:testapp/core/frappe_bloc.dart';

class CounterBloc extends BaseBloc<int> {
  late final EventStreamSink<Unit> _incrementSink;

  @override
  ValueState<int> create() {
    _incrementSink = EventStreamSink<Unit>();

    final stateLink = ValueStateLink<int>();

    stateLink.connect(_incrementSink.stream
        .snapshot<int, int>(stateLink.state, (_, value) => value + 1)
        .toState(0));

    return stateLink.state;
  }

  // commands
  void increment() => _incrementSink.sendUnit();
}

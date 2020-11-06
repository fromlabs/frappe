import 'package:frappe/src/event_stream.dart';
import 'package:frappe/src/unit.dart';
import 'package:frappe/src/value_state.dart';

extension BoolEventStream on EventStream<bool> {
  EventStream<bool> whereIsTrue() => where((value) => value == true);

  EventStream<bool> whereIsFalse() => where((value) => value == false);
}

extension NullableEventStream<E> on EventStream<E?> {
  EventStream<bool> mapIsNull() => map((event) => event == null);

  EventStream<bool> mapIsNotNull() => map((event) => event != null);

  EventStream<E?> whereNull() => where((event) => event == null);

  EventStream<E> mapWhereNotNull() => whereType<E>();
}

extension ExtendedEventStream<E> on EventStream<E> {
  EventStream<Unit> mapToUnit() => mapTo(unit);

  EventStream<E> whereValue(E value) => where((event) => event == value);
}

extension UnitEventStreamSink on EventStreamSink<Unit> {
  void sendUnit() => send(unit);
}

extension NullableEventStreamSink<E> on EventStreamSink<E?> {
  void sendNull() => send(null);
}

extension NullableValueState<V> on ValueState<V?> {
  ValueState<bool> mapIsNull() => map((value) => value == null);

  ValueState<bool> mapIsNotNull() => map((value) => value != null);
}

extension NullableValueStateSink<V> on ValueStateSink<V?> {
  void sendNull() => send(null);
}

import 'event_stream.dart';
import 'unit.dart';
import 'value_state.dart';

// --- EventStream<bool> extensions ---

extension BoolEventStreamExtension on EventStream<bool> {
  EventStream<bool> whereIsTrue() => where((v) => v);
  EventStream<bool> whereIsFalse() => where((v) => !v);
}

// --- EventStream<E?> extensions ---

extension NullableEventStreamExtension<E> on EventStream<E?> {
  EventStream<bool> mapIsNull() => map((v) => v == null);
  EventStream<bool> mapIsNotNull() => map((v) => v != null);
  EventStream<E?> whereNull() => where((v) => v == null);
  EventStream<E> mapWhereNotNull() =>
      where((v) => v != null).cast<E>();
}

// --- EventStream<E> extensions ---

extension EventStreamExtension<E> on EventStream<E> {
  EventStream<Unit> mapToUnit() => mapTo(unit);
  EventStream<E> whereValue(E value) => where((v) => v == value);
}

// --- EventStreamSink extensions ---

extension UnitEventStreamSinkExtension on EventStreamSink<Unit> {
  void sendUnit() => send(unit);
}

extension NullableEventStreamSinkExtension<E> on EventStreamSink<E?> {
  void sendNull() => send(null);
}

// --- ValueState<V?> extensions ---

extension NullableValueStateExtension<V> on ValueState<V?> {
  ValueState<bool> mapIsNull() => map((v) => v == null);
  ValueState<bool> mapIsNotNull() => map((v) => v != null);
}

// --- ValueStateSink<V?> extensions ---

extension NullableValueStateSinkExtension<V> on ValueStateSink<V?> {
  void sendNull() => send(null);
}

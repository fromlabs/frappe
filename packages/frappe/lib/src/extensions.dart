import 'event_stream.dart';
import 'unit.dart';
import 'value_state.dart';

/// Boolean filtering extensions on [EventStream<bool>].
extension BoolEventStreamExtension on EventStream<bool> {
  /// Passes through only `true` events.
  EventStream<bool> whereIsTrue() => where((v) => v);

  /// Passes through only `false` events.
  EventStream<bool> whereIsFalse() => where((v) => !v);
}

/// Nullable type extensions on [EventStream<E?>].
extension NullableEventStreamExtension<E> on EventStream<E?> {
  /// Maps each event to `true` if null, `false` otherwise.
  EventStream<bool> mapIsNull() => map((v) => v == null);

  /// Maps each event to `true` if non-null, `false` otherwise.
  EventStream<bool> mapIsNotNull() => map((v) => v != null);

  /// Passes through only null events.
  EventStream<E?> whereNull() => where((v) => v == null);

  /// Filters out null events and casts the result to non-nullable.
  EventStream<E> mapWhereNotNull() => where((v) => v != null).cast<E>();
}

/// General convenience extensions on [EventStream].
extension EventStreamExtension<E> on EventStream<E> {
  /// Maps all events to [unit].
  EventStream<Unit> mapToUnit() => mapTo(unit);

  /// Passes through only events equal to [value].
  EventStream<E> whereValue(E value) => where((v) => v == value);
}

/// Convenience extension on [EventStreamSink<Unit>].
extension UnitEventStreamSinkExtension on EventStreamSink<Unit> {
  /// Sends [unit] into the sink.
  void sendUnit() => send(unit);
}

/// Convenience extension on nullable [EventStreamSink].
extension NullableEventStreamSinkExtension<E> on EventStreamSink<E?> {
  /// Sends `null` into the sink.
  void sendNull() => send(null);
}

/// Nullable type extensions on [ValueState<V?>].
extension NullableValueStateExtension<V> on ValueState<V?> {
  /// Maps the value to `true` if null, `false` otherwise.
  ValueState<bool> mapIsNull() => map((v) => v == null);

  /// Maps the value to `true` if non-null, `false` otherwise.
  ValueState<bool> mapIsNotNull() => map((v) => v != null);
}

/// Convenience extension on nullable [ValueStateSink].
extension NullableValueStateSinkExtension<V> on ValueStateSink<V?> {
  /// Sends `null` into the sink.
  void sendNull() => send(null);
}

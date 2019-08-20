import 'dart:async';

import 'package:optional/optional.dart';

import 'broadcast_stream.dart';
import 'listen_subscription.dart';
import 'typedef.dart';
import 'value_state.dart';
import 'event_stream_reference.dart';
import 'value_state_reference.dart';

EventStream<E> createEventStreamFromBroadcastStream<E>(
        BroadcastStream<E> broadcastStream) =>
    EventStream._(broadcastStream);

OptionalEventStream<E> createOptionalEventStreamFromBroadcastStream<E>(
        BroadcastStream<Optional<E>> broadcastStream) =>
    OptionalEventStream._(broadcastStream);

OptionalEventStream<E> createOptionalEventStreamFromStream<E>(
        Stream<Optional<E>> stream) =>
    OptionalEventStream._fromStream(stream);

EventStream<E> createEventStreamFromStream<E>(Stream<E> stream) =>
    EventStream._fromStream(stream);

class EventStream<E> {
  final BroadcastStream<E> _legacyStream;

  EventStream.never() : this._(NeverBroadcastStream<E>());

  EventStream._fromStream(Stream<E> stream)
      : this._(FromBroadcastStream<E>(stream, keepLastData: false));

  EventStream._(this._legacyStream);

  Stream<E> get legacyStream => _legacyStream;

  OptionalEventStream<EE> asOptional<EE>() =>
      OptionalEventStream._(_legacyStream as BroadcastStream<Optional<EE>>);

  ValueState<E> toState(E initValue) =>
      createValueStateFromStream<E>(initValue, _legacyStream);

  EventStream<E> distinct([Equalizer<E> distinctEquals]) =>
      EventStream._(DistinctBroadcastStream<E>(_legacyStream,
          distinctEquals: distinctEquals, keepLastData: false));

  EventStream<ER> map<ER>(Mapper<E, ER> mapper) =>
      EventStream._fromStream(_legacyStream.map(mapper));

  EventStream<ER> mapTo<ER>(ER event) => map<ER>((_) => event);

  OptionalEventStream<EE> mapToOptionalEmpty<EE>() =>
      mapTo<Optional<EE>>(Optional<EE>.empty()).asOptional<EE>();

  OptionalEventStream<E> mapToOptionalOf() =>
      map<Optional<E>>((event) => Optional<E>.of(event)).asOptional<E>();

  EventStream<E> where(Filter<E> filter) =>
      EventStream._fromStream(_legacyStream.where(filter));

  ValueState<V> accumulate<V>(V initValue, Accumulator<E, V> accumulator) {
    final reference = ValueStateReference<V>(initValue);
    reference.link(snapshot(reference.state, accumulator).toState(initValue));
    return reference.state;
  }

  EventStream<ER> collect<ER, V>(V initValue, Collector<E, V, ER> collector) {
    final reference = EventStreamReference<V>();
    final stream = snapshot(reference.stream.toState(initValue), collector);
    reference.link(stream.map((tuple) => tuple.item2));
    return stream.map((tuple) => tuple.item1);
  }

  EventStream<E> gate(ValueState<bool> conditionState) => snapshot(
          conditionState,
          (event, condition) =>
              condition ? Optional<E>.of(event) : Optional<E>.empty())
      .asOptional<E>()
      .mapWhereOptional();

  EventStream<E> orElse(EventStream<E> stream) => merges<E>([this, stream]);

  EventStream<E> orElses(Iterable<EventStream<E>> streams) =>
      merges<E>([this, ...streams]);

  EventStream<ER> snapshot<V2, ER>(
          ValueState<V2> fromState, Combiner2<E, V2, ER> combiner) =>
      EventStream._(SnapshotBroadcastStream<E, V2, ER>(
          _legacyStream, fromState.legacyStream, combiner));

  ListenSubscription listen(
    OnDataHandler<E> onEvent, {
    OnErrorHandler onError,
    OnDoneHandler onDone,
  }) =>
      ListenSubscription(
          _legacyStream.listen(onEvent, onError: onError, onDone: onDone));

  static EventStream<E> merges<E>(Iterable<EventStream<E>> streams,
          [Merger<E> merger]) =>
      EventStream._(MergeBroadcastStream<E>(
          streams.map((stream) => stream._legacyStream), merger));
}

class OptionalEventStream<E> extends EventStream<Optional<E>> {
  OptionalEventStream.never() : super.never();

  OptionalEventStream._fromStream(Stream<Optional<E>> stream)
      : super._fromStream(stream);

  OptionalEventStream._(BroadcastStream<Optional<E>> stream) : super._(stream);

  @override
  Stream<Optional<E>> get legacyStream => _legacyStream;

  @override
  OptionalValueState<E> toState(Optional<E> initValue) =>
      super.toState(initValue).asOptional<E>();

  EventStream<bool> mapIsEmptyOptional() => map((event) => !event.isPresent);

  EventStream<bool> mapIsPresentOptional() => map((event) => event.isPresent);

  EventStream<E> mapWhereOptional() =>
      where((event) => event.isPresent).map((event) => event.value);
}

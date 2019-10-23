import 'package:frappe/src/transaction.dart';
import 'package:optional/optional.dart';

import 'listen_subscription.dart';
import 'typedef.dart';
import 'value_state.dart';

class EventStreamSink<E> {
  final EventStream<E> stream;

  factory EventStreamSink([Merger<E> merger]) =>
      EventStreamSink._(EventStream<E>._(merger));

  EventStreamSink._(this.stream);

  bool get isClosed => stream._isClosed;

  Future<void> close() => stream._close();

  void send(E event) => stream._send(event);
}

class OptionalEventStreamSink<E> extends EventStreamSink<Optional<E>> {
  factory OptionalEventStreamSink([Merger<Optional<E>> merger]) =>
      OptionalEventStreamSink._(OptionalEventStream<E>._(merger));

  OptionalEventStreamSink._(OptionalEventStream<E> stream) : super._(stream);

  @override
  OptionalEventStream<E> get stream => super.stream;

  void sendOptionalEmpty() => send(Optional<E>.empty());

  void sendOptionalOf(E event) => send(Optional<E>.of(event));
}

class EventStreamReference<E> {
  final EventStream<E> stream;

  factory EventStreamReference() => EventStreamReference._(EventStream<E>._());

  EventStreamReference._(this.stream);

  bool get isLinked => stream._isLinked;

  void link(EventStream<E> stream) => this.stream._link(stream);
}

class OptionalEventStreamReference<E>
    extends EventStreamReference<Optional<E>> {
  factory OptionalEventStreamReference() =>
      OptionalEventStreamReference._(OptionalEventStream<E>._());

  OptionalEventStreamReference._(OptionalEventStream<E> stream)
      : super._(stream);

  @override
  OptionalEventStream<E> get stream => super.stream;

  @override
  void link(covariant OptionalEventStream<E> stream) => super.link(stream);
}

class EventStream<E> {
  final Merger<E> _merger;

  EventStream.never() : _merger = null;

  EventStream._([this._merger]);

  // TODO implementare
  static EventStream<E> merges<E>(Iterable<EventStream<E>> streams,
          [Merger<E> merger]) =>
      throw UnimplementedError();

  // TODO implementare
  OptionalEventStream<EE> asOptional<EE>() => throw UnimplementedError();

  // TODO implementare
  ValueState<E> toState(E initValue) => throw UnimplementedError();

  // TODO implementare
  ValueState<E> toStateLazy(Lazy<E> lazyInitValue) =>
      throw UnimplementedError();

  // TODO implementare
  Stream<E> toLegacyStream() => throw UnimplementedError();

  // TODO implementare
  EventStream<E> once() => throw UnimplementedError();

  // TODO implementare
  EventStream<E> distinct([Equalizer<E> distinctEquals]) =>
      throw UnimplementedError();

  // TODO implementare
  EventStream<ER> map<ER>(Mapper<E, ER> mapper) => throw UnimplementedError();

  EventStream<ER> mapTo<ER>(ER event) => map<ER>((_) => event);

  OptionalEventStream<EE> mapToOptionalEmpty<EE>() => runTransaction(
      () => mapTo<Optional<EE>>(Optional<EE>.empty()).asOptional<EE>());

  OptionalEventStream<E> mapToOptionalOf() => runTransaction(
      () => map<Optional<E>>((event) => Optional<E>.of(event)).asOptional<E>());

  // TODO implementare
  EventStream<E> where(Filter<E> filter) => throw UnimplementedError();

  ValueState<V> accumulate<V>(V initValue, Accumulator<E, V> accumulator) =>
      runTransaction(() {
        final reference = ValueStateReference<V>();
        reference
            .link(snapshot(reference.state, accumulator).toState(initValue));
        return reference.state;
      });

  // TODO implementare
  ValueState<V> accumulateLazy<V>(
          Lazy<V> lazyInitValue, Accumulator<E, V> accumulator) =>
      throw UnimplementedError();

  EventStream<ER> collect<ER, V>(V initValue, Collector<E, V, ER> collector) =>
      runTransaction(() {
        final reference = EventStreamReference<V>();
        final stream = snapshot(reference.stream.toState(initValue), collector);
        reference.link(stream.map((tuple) => tuple.item2));
        return stream.map((tuple) => tuple.item1);
      });

  // TODO implementare
  EventStream<ER> collectLazy<ER, V>(
          Lazy<V> lazyInitValue, Collector<E, V, ER> collector) =>
      throw UnimplementedError();

  EventStream<E> gate(ValueState<bool> conditionState) =>
      runTransaction(() => snapshot(
              conditionState,
              (event, condition) =>
                  condition ? Optional<E>.of(event) : Optional<E>.empty())
          .asOptional<E>()
          .mapWhereOptional());

  EventStream<E> orElse(EventStream<E> stream) => merges<E>([this, stream]);

  EventStream<E> orElses(Iterable<EventStream<E>> streams) =>
      merges<E>([this, ...streams]);

  // TODO implementare
  EventStream<ER> snapshot<V2, ER>(
          ValueState<V2> fromState, Combiner2<E, V2, ER> combiner) =>
      throw UnimplementedError();

  // TODO implementare
  ListenSubscription listen(OnDataHandler<E> onEvent) =>
      throw UnimplementedError();

  ListenSubscription listenOnce(OnDataHandler<E> onEvent) {
    ListenSubscription listenSubscription;

    listenSubscription = listen((data) {
      listenSubscription.cancel();

      onEvent(data);
    });

    return listenSubscription;
  }

  // TODO implementare
  bool get _isClosed => throw UnimplementedError();

  // TODO implementare
  Future<void> _close() => throw UnimplementedError();

  // TODO implementare
  void _send(E event) => throw UnimplementedError();

  // TODO implementare
  bool get _isLinked => throw UnimplementedError();

  // TODO implementare
  void _link(EventStream<E> stream) => throw UnimplementedError();
}

class OptionalEventStream<E> extends EventStream<Optional<E>> {
  OptionalEventStream.never() : super.never();

  OptionalEventStream._([Merger<Optional<E>> merger]) : super._(merger);

  @override
  OptionalValueState<E> toState(Optional<E> initValue) =>
      runTransaction(() => super.toState(initValue).asOptional<E>());

  EventStream<bool> mapIsEmptyOptional() => map((event) => !event.isPresent);

  EventStream<bool> mapIsPresentOptional() => map((event) => event.isPresent);

  EventStream<E> mapWhereOptional() => runTransaction(
      () => where((event) => event.isPresent).map((event) => event.value));
}

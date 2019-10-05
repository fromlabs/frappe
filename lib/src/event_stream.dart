import 'package:optional/optional.dart';

import 'listen_subscription.dart';
import 'typedef.dart';
import 'value_state.dart';

class EventStreamSink<E> {
  final Merger<E> merger;

  final EventStream<E> stream;

  // TODO implementare
  EventStreamSink([this.merger]) : stream = throw UnimplementedError();

  // TODO implementare
  bool get isClosed => throw UnimplementedError();

  // TODO implementare
  Future<void> close() => throw UnimplementedError();

  // TODO implementare
  void send(E event) => throw UnimplementedError();
}

class OptionalEventStreamSink<E> extends EventStreamSink<Optional<E>> {
  OptionalEventStreamSink([Merger<Optional<E>> merger]) : super(merger) {
    // TODO implementare
    throw UnimplementedError();
  }

  @override
  OptionalEventStream<E> get stream => super.stream;

  void sendOptionalEmpty() => send(Optional<E>.empty());

  void sendOptionalOf(E event) => send(Optional<E>.of(event));
}

class EventStreamReference<E> {
  EventStreamReference() {
    // TODO implementare
    throw UnimplementedError();
  }

  // TODO implementare
  EventStream<E> get stream => throw UnimplementedError();

  // TODO implementare
  bool get isLinked => throw UnimplementedError();

  // TODO implementare
  void link(EventStream<E> stream) => throw UnimplementedError();
}

class OptionalEventStreamReference<E>
    extends EventStreamReference<Optional<E>> {
  OptionalEventStreamReference() {
    // TODO implementare
    throw UnimplementedError();
  }

  @override
  OptionalEventStream<E> get stream => super.stream;

  @override
  void link(covariant OptionalEventStream<E> stream) => super.link(stream);
}

class EventStream<E> {
  EventStream.never() {
    // TODO implementare
    throw UnimplementedError();
  }

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

  OptionalEventStream<EE> mapToOptionalEmpty<EE>() =>
      mapTo<Optional<EE>>(Optional<EE>.empty()).asOptional<EE>();

  OptionalEventStream<E> mapToOptionalOf() =>
      map<Optional<E>>((event) => Optional<E>.of(event)).asOptional<E>();

  // TODO implementare
  EventStream<E> where(Filter<E> filter) => throw UnimplementedError();

  // TODO implementare
  ValueState<V> accumulate<V>(V initValue, Accumulator<E, V> accumulator) {
    // TODO in transazione implicita
    final reference = ValueStateReference<V>();
    reference.link(snapshot(reference.state, accumulator).toState(initValue));
    return reference.state;
  }

  // TODO implementare
  ValueState<V> accumulateLazy<V>(
          Lazy<V> lazyInitValue, Accumulator<E, V> accumulator) =>
      throw UnimplementedError();

  // TODO implementare
  EventStream<ER> collect<ER, V>(V initValue, Collector<E, V, ER> collector) {
    // TODO in transazione implicita
    final reference = EventStreamReference<V>();
    final stream = snapshot(reference.stream.toState(initValue), collector);
    reference.link(stream.map((tuple) => tuple.item2));
    return stream.map((tuple) => tuple.item1);
  }

  // TODO implementare
  EventStream<ER> collectLazy<ER, V>(
          Lazy<V> lazyInitValue, Collector<E, V, ER> collector) =>
      throw UnimplementedError();

  // TODO implementare
  // TODO in transazione implicita
  EventStream<E> gate(ValueState<bool> conditionState) => snapshot(
          conditionState,
          (event, condition) =>
              condition ? Optional<E>.of(event) : Optional<E>.empty())
      .asOptional<E>()
      .mapWhereOptional();

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
  static EventStream<E> merges<E>(Iterable<EventStream<E>> streams,
          [Merger<E> merger]) =>
      throw UnimplementedError();
}

class OptionalEventStream<E> extends EventStream<Optional<E>> {
  OptionalEventStream.never() : super.never();

  @override
  OptionalValueState<E> toState(Optional<E> initValue) =>
      super.toState(initValue).asOptional<E>();

  EventStream<bool> mapIsEmptyOptional() => map((event) => !event.isPresent);

  EventStream<bool> mapIsPresentOptional() => map((event) => event.isPresent);

  // TODO in transazione unica
  EventStream<E> mapWhereOptional() =>
      where((event) => event.isPresent).map((event) => event.value);
}

import 'dart:async';

import 'package:optional/optional.dart';

import 'event_stream.dart';
import 'listen_subscription.dart';
import 'typedef.dart';

class Lazy<V> {
  Lazy() {
    // TODO implementare
    throw UnimplementedError();
  }

  // TODO implementare get, map, lift
}

class ValueStateSink<V> {
  final ValueState<V> state;

  final EventStreamSink<V> _eventStreamSink;

  factory ValueStateSink(V initValue, [Merger<V> merger]) =>
      ValueStateSink<V>._(initValue, EventStreamSink<V>(merger));

  ValueStateSink._(V initValue, this._eventStreamSink)
      : this.state = ValueState._(initValue, _eventStreamSink.stream);

  bool get isClosed => _eventStreamSink.isClosed;

  Future<void> close() => _eventStreamSink.close();

  void send(V value) => _eventStreamSink.send(value);
}

class OptionalValueStateSink<V> extends ValueStateSink<Optional<V>> {
  factory OptionalValueStateSink(Optional<V> initValue,
          [Merger<Optional<V>> merger]) =>
      OptionalValueStateSink<V>._(
          initValue, OptionalEventStreamSink<V>(merger));

  factory OptionalValueStateSink.empty() =>
      OptionalValueStateSink(Optional.empty());

  factory OptionalValueStateSink.of(V initValue) =>
      OptionalValueStateSink(Optional.of(initValue));

  OptionalValueStateSink._(
      Optional<V> initValue, OptionalEventStreamSink<V> eventStreamSink)
      : super._(initValue, eventStreamSink);

  @override
  OptionalValueState<V> get state => super.state;

  void sendOptionalEmpty() => send(Optional<V>.empty());

  void sendOptionalOf(V value) => send(Optional<V>.of(value));
}

class ValueStateReference<V> {
  ValueStateReference() {
    // TODO implementare
    throw UnimplementedError();
  }

  // TODO implementare
  ValueState<V> get state => throw UnimplementedError();

  // TODO implementare
  bool get isLinked => throw UnimplementedError();

  // TODO implementare
  void link(ValueState<V> state) => throw UnimplementedError();
}

class OptionalValueStateReference<V> extends ValueStateReference<Optional<V>> {
  OptionalValueStateReference() {
    // TODO implementare
    throw UnimplementedError();
  }

  @override
  OptionalValueState<V> get state => super.state;

  @override
  void link(covariant OptionalValueState<V> state) => super.link(state);
}

class ValueState<V> {
  final EventStream<V> _stream;

  ValueState.constant(V initValue) : this._(initValue, EventStream<V>.never());

  ValueState._(V initValue, this._stream) {
    // TODO implementare
    throw UnimplementedError();
  }

  // TODO implementare
  V current() => throw UnimplementedError();

  // TODO implementare
  Lazy<V> currentLazy() => throw UnimplementedError();

  // TODO implementare
  OptionalValueState<VV> asOptional<VV>() => throw UnimplementedError();

  // TODO implementare
  EventStream<V> toValues() => throw UnimplementedError();

  // TODO implementare
  EventStream<V> toUpdates() => throw UnimplementedError();

  // TODO implementare
  Stream<V> toLegacyStream() => throw UnimplementedError();

  // TODO implementare
  ValueState<V> distinct([Equalizer<V> distinctEquals]) =>
      throw UnimplementedError();

  // TODO implementare
  ValueState<VR> map<VR>(Mapper<V, VR> mapper) => throw UnimplementedError();

  OptionalValueState<V> mapToOptionalOf() =>
      map<Optional<V>>((value) => Optional<V>.of(value)).asOptional<V>();

  ValueState<VR> combine<V2, VR>(
          ValueState<V2> state2, Combiner2<V, V2, VR> combiner) =>
      combines<VR>([this, state2], (values) {
        final iterator = values.iterator;

        return combiner(
          (iterator..moveNext()).current,
          (iterator..moveNext()).current,
        );
      });

  ValueState<VR> combine2<V2, V3, VR>(ValueState<V2> state2,
          ValueState<V3> state3, Combiner3<V, V2, V3, VR> combiner) =>
      combines<VR>([this, state2, state3], (values) {
        final iterator = values.iterator;

        return combiner(
          (iterator..moveNext()).current,
          (iterator..moveNext()).current,
          (iterator..moveNext()).current,
        );
      });

  ValueState<VR> combine3<V2, V3, V4, VR>(
          ValueState<V2> state2,
          ValueState<V3> state3,
          ValueState<V4> state4,
          Combiner4<V, V2, V3, V4, VR> combiner) =>
      combines<VR>([this, state2, state3, state4], (values) {
        final iterator = values.iterator;

        return combiner(
          (iterator..moveNext()).current,
          (iterator..moveNext()).current,
          (iterator..moveNext()).current,
          (iterator..moveNext()).current,
        );
      });

  ValueState<VR> combine4<V2, V3, V4, V5, VR>(
          ValueState<V2> state2,
          ValueState<V3> state3,
          ValueState<V4> state4,
          ValueState<V5> state5,
          Combiner5<V, V2, V3, V4, V5, VR> combiner) =>
      combines<VR>([this, state2, state3, state4, state5], (values) {
        final iterator = values.iterator;

        return combiner(
            (iterator..moveNext()).current,
            (iterator..moveNext()).current,
            (iterator..moveNext()).current,
            (iterator..moveNext()).current,
            (iterator..moveNext()).current);
      });

  // TODO implementare
  ListenSubscription listen(OnDataHandler<V> onEvent) =>
      throw UnimplementedError();

  ValueState<VR> switchMapState<VR>(ValueState<VR> Function(V value) mapper) =>
      ValueState.switchState<VR>(map<ValueState<VR>>(mapper));

  EventStream<ER> switchMapStream<ER>(
          EventStream<ER> Function(V value) mapper) =>
      ValueState.switchStream<ER>(map<EventStream<ER>>(mapper));

  // TODO implementare
  static ValueState<VR> combines<VR>(
          Iterable<ValueState> states, Combiners<VR> combiner) =>
      throw UnimplementedError();

  // TODO implementare
  static ValueState<V> switchState<V>(ValueState<ValueState<V>> statesState) =>
      throw UnimplementedError();

  // TODO implementare
  static EventStream<E> switchStream<E>(
          ValueState<EventStream<E>> streamsState) =>
      throw UnimplementedError();
/*
  // TODO utilizzato dai lift di sodium
  static ValueState<B> stateApply<A, B>(
          ValueState<Mapper<A, B>> mapperState, ValueState<A> state) =>
      throw UnimplementedError();
*/
}

class OptionalValueState<V> extends ValueState<Optional<V>> {
  OptionalValueState.constant(Optional<V> initValue)
      : super.constant(initValue);

  OptionalValueState.constantEmpty() : super.constant(Optional<V>.empty());

  OptionalValueState.constantOf(V initValue)
      : super.constant(Optional<V>.of(initValue));

  @override
  OptionalEventStream<V> toValues() => super.toValues().asOptional<V>();

  @override
  OptionalEventStream<V> toUpdates() => super.toUpdates().asOptional<V>();

  ValueState<bool> mapIsEmptyOptional() => map((value) => !value.isPresent);

  ValueState<bool> mapIsPresentOptional() => map((value) => value.isPresent);
}

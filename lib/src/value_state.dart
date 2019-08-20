import 'dart:async';

import 'package:optional/optional.dart';

import 'broadcast_stream.dart';
import 'event_stream.dart';
import 'listen_subscription.dart';
import 'typedef.dart';

ValueState<V> createValueStateFromBroadcastStream<V>(
        BroadcastStream<V> broadcastStream) =>
    ValueState._(broadcastStream);

OptionalValueState<V> createOptionalValueStateFromBroadcastStream<V>(
        BroadcastStream<Optional<V>> broadcastStream) =>
    OptionalValueState._(broadcastStream);

ValueState<V> createValueStateFromStream<V>(V initValue, Stream<V> stream) =>
    ValueState._fromStream(initValue, stream);

OptionalValueState<V> createOptionalValueStateFromStream<V>(
        Optional<V> initValue, Stream<Optional<V>> stream) =>
    OptionalValueState.fromStream(initValue, stream);

class ValueState<V> {
  final BroadcastStream<V> _legacyStream;

  ValueState.constant(V initValue)
      : this._(ConstantBroadcastStream<V>(initValue));

  ValueState._fromStream(V initValue, Stream<V> stream)
      : this._(FromBroadcastStream<V>(stream,
            keepLastData: true, initData: initValue));

  ValueState._(this._legacyStream);

  Stream<V> get legacyStream => _legacyStream;

  V get current => _legacyStream.lastData;

  OptionalValueState<VV> asOptional<VV>() =>
      OptionalValueState._(_legacyStream as BroadcastStream<Optional<VV>>);

  EventStream<V> toValues() => createEventStreamFromBroadcastStream(
      BroadcastFactoryStream<V>(() => StartWithBroadcastStream(_legacyStream,
          startData: _legacyStream.lastData)));

  EventStream<V> toUpdates() =>
      createEventStreamFromBroadcastStream(_legacyStream);

  ValueState<V> distinct([Equalizer<V> distinctEquals]) =>
      ValueState._(DistinctBroadcastStream<V>(_legacyStream,
          distinctEquals: distinctEquals, keepLastData: true));

  ValueState<VR> map<VR>(Mapper<V, VR> mapper) =>
      ValueState._fromStream(mapper(current), _legacyStream.map(mapper));

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

  ListenSubscription listen(
    OnDataHandler<V> onEvent, {
    OnErrorHandler onError,
    OnDoneHandler onDone,
  }) =>
      ListenSubscription(
          _legacyStream.listen(onEvent, onError: onError, onDone: onDone));

  ValueState<VR> switchMapState<VR>(ValueState<VR> Function(V value) mapper) =>
      ValueState.switchState<VR>(map<ValueState<VR>>(mapper));

  EventStream<ER> switchMapStream<ER>(
          EventStream<ER> Function(V value) mapper) =>
      ValueState.switchStream<ER>(map<EventStream<ER>>(mapper));

  static ValueState<VR> combines<VR>(
          Iterable<ValueState> states, Combiners<VR> combiner) =>
      ValueState._(CombineBroadcastStream<VR>(
          states.map<BroadcastStream>((state) => state._legacyStream),
          combiner));

  static ValueState<V> switchState<V>(ValueState<ValueState<V>> statesState) =>
      ValueState<V>._fromStream(
          statesState.current.current,
          SwitchBroadcastStream<ValueState<V>, V>(
              statesState._legacyStream, (state) => state._legacyStream,
              keepLastData: true));

  static EventStream<E> switchStream<E>(
          ValueState<EventStream<E>> streamsState) =>
      createEventStreamFromStream<E>(SwitchBroadcastStream<EventStream<E>, E>(
          streamsState._legacyStream, (stream) => stream.legacyStream,
          keepLastData: false));
}

class OptionalValueState<V> extends ValueState<Optional<V>> {
  OptionalValueState.constant(Optional<V> initValue)
      : super.constant(initValue);

  OptionalValueState.constantEmpty() : super.constant(Optional<V>.empty());

  OptionalValueState.constantOf(V initValue)
      : super.constant(Optional<V>.of(initValue));

  OptionalValueState.fromStream(
      Optional<V> initValue, Stream<Optional<V>> stream)
      : super._fromStream(initValue, stream);

  OptionalValueState._(BroadcastStream<Optional<V>> stream) : super._(stream);

  @override
  Stream<Optional<V>> get legacyStream => _legacyStream;

  @override
  OptionalEventStream<V> toValues() => super.toValues().asOptional<V>();

  @override
  OptionalEventStream<V> toUpdates() => super.toUpdates().asOptional<V>();

  ValueState<bool> mapIsEmptyOptional() => map((value) => !value.isPresent);

  ValueState<bool> mapIsPresentOptional() => map((value) => value.isPresent);
}

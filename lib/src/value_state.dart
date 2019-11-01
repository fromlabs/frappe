import 'package:frappe/src/node.dart';
import 'package:frappe/src/transaction.dart';
import 'package:optional/optional.dart';

import 'event_stream.dart';
import 'listen_subscription.dart';
import 'typedef.dart';

NodeEvaluation<V> _defaultEvaluateHandler<V>(
        Map<dynamic, NodeEvaluation> inputs) =>
    inputs[0];

ValueState<V> createValueState<V>(
        LazyValue<V> initLazyValue, EventStream<V> stream) =>
    ValueState._(initLazyValue, stream);

class LazyValue<V> {
  final ValueProvider<V> _provider;
  bool hasValue = false;
  V _value;

  LazyValue(V value)
      : _provider = null,
        hasValue = true,
        _value = value;

  LazyValue.undefined()
      : _provider = (() => throw StateError('Lazy value undefined'));

  LazyValue.provide(this._provider);

  OptionalLazyValue<VV> asOptional<VV>() => OptionalLazyValue.provide(() {
        final value = get();
        if (value is Optional<VV>) {
          return value;
        } else {
          throw ArgumentError('Value is not optional');
        }
      });

  V get() => Transaction.runRequired((_) {
        if (hasValue) {
          return _value;
        } else {
          _value = _provider();
          hasValue = true;
          return _value;
        }
      });

  LazyValue<VR> map<VR>(Mapper<V, VR> mapper) =>
      LazyValue.provide(() => mapper(get()));
}

class OptionalLazyValue<V> extends LazyValue<Optional<V>> {
  OptionalLazyValue(Optional<V> value) : super(value);

  OptionalLazyValue.undefined() : super.undefined();

  OptionalLazyValue.of(V value) : super(Optional.of(value));

  OptionalLazyValue.empty() : super(Optional.empty());

  OptionalLazyValue.provide(ValueProvider<Optional<V>> provider)
      : super.provide(provider);
}

class ValueStateSink<V> {
  final ValueState<V> state;

  final EventStreamSink<V> _eventStreamSink;

  factory ValueStateSink(V initValue, [Merger<V> merger]) =>
      ValueStateSink.lazy(LazyValue(initValue), merger);

  factory ValueStateSink.lazy(LazyValue<V> initLazyValue, [Merger<V> merger]) =>
      ValueStateSink<V>._(initLazyValue, EventStreamSink<V>(merger));

  ValueStateSink._(LazyValue<V> initLazyValue, this._eventStreamSink)
      : this.state = ValueState._(initLazyValue, _eventStreamSink.stream);

  bool get isClosed => _eventStreamSink.isClosed;

  void close() => _eventStreamSink.close();

  void send(V value) => _eventStreamSink.send(value);
}

class OptionalValueStateSink<V> extends ValueStateSink<Optional<V>> {
  factory OptionalValueStateSink(Optional<V> initValue,
          [Merger<Optional<V>> merger]) =>
      OptionalValueStateSink.lazy(OptionalLazyValue(initValue), merger);

  factory OptionalValueStateSink.lazy(OptionalLazyValue<V> initLazyValue,
          [Merger<Optional<V>> merger]) =>
      OptionalValueStateSink<V>._(
          initLazyValue, OptionalEventStreamSink<V>(merger));

  factory OptionalValueStateSink.empty([Merger<Optional<V>> merger]) =>
      OptionalValueStateSink(Optional.empty(), merger);

  factory OptionalValueStateSink.of(V initValue,
          [Merger<Optional<V>> merger]) =>
      OptionalValueStateSink(Optional.of(initValue), merger);

  OptionalValueStateSink._(OptionalLazyValue<V> initLazyValue,
      OptionalEventStreamSink<V> eventStreamSink)
      : super._(initLazyValue, eventStreamSink);

  @override
  OptionalValueState<V> get state => super.state;

  void sendOptionalEmpty() => send(Optional<V>.empty());

  void sendOptionalOf(V value) => send(Optional<V>.of(value));
}

class ValueStateReference<V> {
  final ValueState<V> state;

  factory ValueStateReference() => ValueStateReference._(ValueState<V>._(
      LazyValue<V>.undefined(),
      createEventStream<V>(
          IndexedNode<V>(evaluateHandler: _defaultEvaluateHandler))));

  ValueStateReference._(this.state);

  bool get isLinked => _node.isLinked(0);

  void link(ValueState<V> state) {
    if (isLinked) {
      throw StateError("Reference already linked");
    }

    _node.link(state._node);
  }

  IndexedNode<V> get _node => state._node;
}

class OptionalValueStateReference<V> extends ValueStateReference<Optional<V>> {
  factory OptionalValueStateReference() =>
      OptionalValueStateReference._(OptionalValueState<V>._(
          OptionalLazyValue<V>.undefined(),
          createOptionalEventStream(IndexedNode<Optional<V>>(
              evaluateHandler: _defaultEvaluateHandler))));

  OptionalValueStateReference._(OptionalValueState<V> state) : super._(state);

  @override
  OptionalValueState<V> get state => super.state;

  @override
  void link(covariant OptionalValueState<V> state) => super.link(state);
}

class ValueState<V> {
  LazyValue<V> _currentLazyValue;

  final EventStream<V> _stream;

  ValueState.constant(V initValue)
      : this._(LazyValue(initValue), EventStream<V>.never());

  ValueState._(this._currentLazyValue, this._stream) {
    final _superCommitHandler = _node.commitHandler;

    _node.commitHandler = (value) {
      _superCommitHandler(value);

      _currentLazyValue = LazyValue(value);
    };
  }

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

  V current() => Transaction.run((transaction) => currentLazy().get());

  LazyValue<V> currentLazy() => _currentLazyValue;

  OptionalValueState<VV> asOptional<VV>() =>
      Transaction.runRequired((_) => OptionalValueState._(
          currentLazy().asOptional<VV>(), _stream.asOptional()));

  EventStream<V> toValues() => Transaction.runRequired((transaction) {
        final targetNode = transaction.node(IndexedNode<V>(
            evaluationType: EvaluationType.FIRST_EVALUATION,
            evaluateHandler: (inputs) =>
                inputs[0].isEvaluated ? inputs[0] : NodeEvaluation(current())));

        targetNode.link(_node);

        return createEventStream(targetNode);
      });

  EventStream<V> toUpdates() => _stream;

  ValueState<V> distinct([Equalizer<V> distinctEquals]) =>
      Transaction.runRequired((_) =>
          ValueState._(_currentLazyValue, _stream.distinct(distinctEquals)));

  ValueState<VR> map<VR>(Mapper<V, VR> mapper) => Transaction.runRequired(
      (_) => ValueState._(_currentLazyValue.map(mapper), _stream.map(mapper)));

  OptionalValueState<V> mapToOptionalOf() => runTransaction(
      () => map<Optional<V>>((value) => Optional<V>.of(value)).asOptional<V>());

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

  ListenSubscription listen(ValueHandler<V> onValue) =>
      Transaction.run((transaction) => toValues().listen(onValue));

  ValueState<VR> switchMapState<VR>(Mapper<V, ValueState<VR>> mapper) =>
      ValueState.switchState<VR>(map<ValueState<VR>>(mapper));

  EventStream<ER> switchMapStream<ER>(Mapper<V, EventStream<ER>> mapper) =>
      ValueState.switchStream<ER>(map<EventStream<ER>>(mapper));

  Node<V> get _node => getEventStreamNode(_stream);
}

class OptionalValueState<V> extends ValueState<Optional<V>> {
  OptionalValueState.constant(Optional<V> initValue)
      : super.constant(initValue);

  OptionalValueState.constantEmpty() : super.constant(Optional<V>.empty());

  OptionalValueState.constantOf(V initValue)
      : super.constant(Optional<V>.of(initValue));

  OptionalValueState._(
      LazyValue<Optional<V>> initLazyValue, OptionalEventStream<V> stream)
      : super._(initLazyValue, stream);

  @override
  OptionalEventStream<V> toValues() =>
      runTransaction(() => super.toValues().asOptional<V>());

  @override
  OptionalEventStream<V> toUpdates() =>
      runTransaction(() => super.toUpdates().asOptional<V>());

  @override
  OptionalLazyValue<V> currentLazy() => super.currentLazy();

  ValueState<bool> mapIsEmptyOptional() => map((value) => !value.isPresent);

  ValueState<bool> mapIsPresentOptional() => map((value) => value.isPresent);
}

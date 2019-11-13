import 'package:frappe/frappe.dart';
import 'package:optional/optional.dart';

import 'reference.dart';
import 'node.dart';
import 'transaction.dart';
import 'event_stream.dart';
import 'listen_subscription.dart';
import 'typedef.dart';

Node<V> getValueStateNode<V>(ValueState<V> state) =>
    getEventStreamNode(state._stream);

ValueState<V> createValueState<V>(
        LazyValue<V> lazyInitValue, EventStream<V> stream) =>
    ValueState._(lazyInitValue, stream);

NodeEvaluation<E> _defaultEvaluateHandler<E>(NodeEvaluationMap inputs) =>
    inputs.evaluation;

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

  static LazyValue<VR> combines<VR>(
          Iterable<LazyValue> lazyValues, Combiners<VR> combiner) =>
      LazyValue.provide(
          () => combiner(lazyValues.map((lazyValue) => lazyValue.get())));

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
      Transaction.runRequired((_) => LazyValue.provide(() => mapper(get())));

  LazyValue<Optional<VV>> _castOptional<VV>() =>
      this as LazyValue<Optional<VV>>;
}

class ValueStateReference<VS extends ValueState> {
  final VS state;

  final Reference<Node> _reference;

  ValueStateReference(this.state)
      : _reference = Reference(getValueStateNode(state));

  bool get isDisposed => _reference.isDisposed;

  void dispose() => _reference.dispose();
}

class ValueStateSink<V> {
  final ValueState<V> state;

  final EventStreamSink<V> _eventStreamSink;

  factory ValueStateSink(V initValue, [Merger<V> merger]) =>
      ValueStateSink.lazy(LazyValue(initValue), merger);

  factory ValueStateSink.lazy(LazyValue<V> lazyInitValue, [Merger<V> merger]) =>
      Transaction.run((transaction) {
        final eventStreamSink = EventStreamSink<V>(merger);

        return ValueStateSink<V>._(
            ValueState._(lazyInitValue, eventStreamSink.stream),
            eventStreamSink);
      });

  ValueStateSink._(this.state, this._eventStreamSink);

  bool get isClosed => _eventStreamSink.isClosed;

  void close() => _eventStreamSink.close();

  void send(V value) => _eventStreamSink.send(value);
}

class OptionalValueStateSink<V> extends ValueStateSink<Optional<V>> {
  factory OptionalValueStateSink(Optional<V> initValue,
          [Merger<Optional<V>> merger]) =>
      OptionalValueStateSink.lazy(LazyValue(initValue), merger);

  factory OptionalValueStateSink.empty([Merger<Optional<V>> merger]) =>
      OptionalValueStateSink(Optional.empty(), merger);

  factory OptionalValueStateSink.of(V initValue,
          [Merger<Optional<V>> merger]) =>
      OptionalValueStateSink(Optional.of(initValue), merger);

  factory OptionalValueStateSink.lazy(LazyValue<Optional<V>> lazyInitValue,
          [Merger<Optional<V>> merger]) =>
      Transaction.run((_) {
        final eventStreamSink = OptionalEventStreamSink<V>(merger);

        return OptionalValueStateSink<V>._(
            OptionalValueState._(lazyInitValue, eventStreamSink.stream),
            eventStreamSink);
      });

  OptionalValueStateSink._(
      OptionalValueState<V> state, OptionalEventStreamSink<V> eventStreamSink)
      : super._(state, eventStreamSink);

  @override
  OptionalValueState<V> get state => super.state;

  void sendOptionalEmpty() => send(Optional<V>.empty());

  void sendOptionalOf(V value) => send(Optional<V>.of(value));
}

class ValueStateLink<V> {
  final ValueState<V> state;
  ValueState<V> _linkedState;

  factory ValueStateLink() => Transaction.runRequired((transaction) {
        ValueStateLink<V> link;

        link = ValueStateLink._(ValueState<V>._(
            LazyValue<V>.provide(() => link.isLinked
                ? link._linkedState.current()
                : throw StateError('Link is not connected')),
            createEventStream<V>(
                KeyNode<V>(evaluateHandler: _defaultEvaluateHandler))));

        return link;
      });

  ValueStateLink._(this.state);

  bool get isLinked => _linkedState != null;

  void connect(ValueState<V> state) => Transaction.runRequired((_) {
        if (isLinked) {
          throw StateError("Reference already linked");
        }

        _linkedState = state;
        _node.link(state._node);
      });

  KeyNode<V> get _node => state._node;
}

class OptionalValueStateLink<V> extends ValueStateLink<Optional<V>> {
  factory OptionalValueStateLink() {
    OptionalValueStateLink<V> link;

    link = Transaction.runRequired((transaction) => OptionalValueStateLink._(
        OptionalValueState<V>._(
            LazyValue<Optional<V>>.provide(() => link.isLinked
                ? link._linkedState.current()
                : throw StateError('Link is not connected')),
            createOptionalEventStream(KeyNode<Optional<V>>(
                evaluateHandler: _defaultEvaluateHandler)))));

    return link;
  }

  OptionalValueStateLink._(OptionalValueState<V> state) : super._(state);

  @override
  OptionalValueState<V> get state => super.state;

  @override
  void connect(covariant OptionalValueState<V> state) => super.connect(state);
}

class ValueState<V> {
  LazyValue<V> _currentLazyValue;

  Reference _currentValueReference;

  final EventStream<V> _stream;

  ValueState.constant(V initValue)
      : this._(LazyValue(initValue), EventStream<V>.never());

  ValueState._(LazyValue<V> lazyInitValue, this._stream)
      : _currentLazyValue = lazyInitValue {
    if (lazyInitValue.hasValue) {
      _updateCurrentValueReference(lazyInitValue.get());
    }

    final superCommitHandler = _node.commitHandler;

    _node.commitHandler = (V value) {
      superCommitHandler(value);

      if (!_currentLazyValue.hasValue ||
          !identical(value, _currentLazyValue.get())) {
        _currentLazyValue = LazyValue(value);
        _updateCurrentValueReference(value);
      }
    };
  }

  static ValueState<VR> combines<VR>(
          Iterable<ValueState> states, Combiners<VR> combiner) =>
      Transaction.runRequired((transaction) {
        final targetNode = IndexNode<VR>(
            evaluationType: EvaluationType.almostOneInput,
            evaluateHandler: (inputs) => NodeEvaluation(
                  combiner(Map.fromIterables(states, inputs.evaluations)
                      .entries
                      .map((entry) => entry.value.isEvaluated
                          ? entry.value.value
                          : entry.key.current())),
                ));

        targetNode
            .link(states.map((state) => getEventStreamNode(state._stream)));

        return ValueState._(
            LazyValue.combines(
                states.map((state) => state.currentLazy()), combiner),
            createEventStream(targetNode));
      });

  static ValueState<V> switchState<V>(ValueState<ValueState<V>> statesState) =>
      Transaction.runRequired((transaction) {
        KeyNode<V> targetNode;

        targetNode = KeyNode<V>(evaluateHandler: _defaultEvaluateHandler);

        Transaction.addClosingTransactionHandler(targetNode, (transaction) {
          if (transaction.hasValue(getValueStateNode(statesState))) {
            targetNode.unlink();
            targetNode.link(getValueStateNode(statesState.current()));
          }
        });

        targetNode.link(getValueStateNode(statesState.current()));
        targetNode.reference(getValueStateNode(statesState));

        return ValueState._(
            LazyValue.provide(() => statesState.current().current()),
            createEventStream(targetNode));
      });

  static EventStream<E> switchStream<E>(
          ValueState<EventStream<E>> streamsState) =>
      Transaction.runRequired((transaction) {
        KeyNode<E> targetNode;

        targetNode = KeyNode<E>(evaluateHandler: _defaultEvaluateHandler);

        Transaction.addClosingTransactionHandler(targetNode, (transaction) {
          if (transaction.hasValue(getValueStateNode(streamsState))) {
            targetNode.unlink();
            targetNode.link(getEventStreamNode(streamsState.current()));
          }
        });

        targetNode.link(getEventStreamNode(streamsState.current()));
        targetNode.reference(getValueStateNode(streamsState));

        return createEventStream(targetNode);
      });

  V current() => Transaction.run((transaction) => currentLazy().get());

  LazyValue<V> currentLazy() => _currentLazyValue;

  OptionalValueState<VV> asOptional<VV>() =>
      Transaction.runRequired((_) => OptionalValueState._(
          currentLazy()._castOptional<VV>(), _stream.asOptional()));

  ValueStateReference<ValueState<V>> toReference() => ValueStateReference(this);

  EventStream<V> toValues() => Transaction.runRequired((transaction) {
        final targetNode = KeyNode<V>(
            evaluationType: EvaluationType.always,
            evaluateHandler: (inputs) => inputs.evaluation.isEvaluated
                ? inputs.evaluation
                : NodeEvaluation(current()));

        Transaction.addClosingTransactionHandler(targetNode, (transaction) {
          targetNode.evaluationType = EvaluationType.allInputs;

          Transaction.removeClosingTransactionHandler(targetNode);
        });

        targetNode.link(_node);

        return createEventStream(targetNode);
      });

  EventStream<V> toUpdates() =>
      Transaction.runRequired((transaction) => _stream);

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

  void _updateCurrentValueReference(V value) {
    _currentValueReference?.dispose();

    if (value is EventStream) {
      _currentValueReference = _node.reference(getEventStreamNode(value));
    } else if (value is ValueState) {
      _currentValueReference = _node.reference(value._node);
    } else if (value is Referenceable) {
      _currentValueReference = _node.reference(value);
    } else {
      _currentValueReference = null;
    }
  }
}

class OptionalValueState<V> extends ValueState<Optional<V>> {
  OptionalValueState.constant(Optional<V> initValue)
      : super.constant(initValue);

  OptionalValueState.constantEmpty() : super.constant(Optional<V>.empty());

  OptionalValueState.constantOf(V initValue)
      : super.constant(Optional<V>.of(initValue));

  OptionalValueState._(
      LazyValue<Optional<V>> lazyInitValue, OptionalEventStream<V> stream)
      : super._(lazyInitValue, stream);

  @override
  OptionalValueState<VV> asOptional<VV>() =>
      throw StateError('Already optional');

  @override
  OptionalEventStream<V> toValues() =>
      Transaction.runRequired((_) => super.toValues().asOptional<V>());

  @override
  OptionalEventStream<V> toUpdates() =>
      Transaction.runRequired((_) => super.toUpdates().asOptional<V>());

  @override
  ValueStateReference<OptionalValueState<V>> toReference() =>
      ValueStateReference(this);

  ValueState<bool> mapIsEmptyOptional() => map((value) => !value.isPresent);

  ValueState<bool> mapIsPresentOptional() => map((value) => value.isPresent);
}

import 'event_stream.dart';
import 'lazy_value.dart';
import 'listen_subscription.dart';
import 'node.dart';
import 'node_evaluation.dart';
import 'reference.dart';
import 'transaction.dart';
import 'typedefs.dart';

/// Provides access to the internal node of a [ValueState].
extension ValueStateNode<V> on ValueState<V> {
  Node<V> get node => _node;
}

/// Creates a [ValueState] from a lazy initial value and an event stream.
ValueState<V> createValueState<V>(
        LazyValue<V> lazyInitValue, EventStream<V> stream) =>
    ValueState._(lazyInitValue, stream);

NodeEvaluation<V> _defaultEvaluateHandler<V>(NodeEvaluationMap inputs) =>
    inputs.get<V>();

/// An input sink for sending values into a [ValueState].
class ValueStateSink<V> {
  final ValueState<V> state;
  final EventStreamSink<V> _eventStreamSink;

  /// Creates a sink with the given initial value.
  factory ValueStateSink(V initValue, [Merger<V>? merger]) =>
      ValueStateSink.lazy(LazyValue.value(initValue), merger);

  /// Creates a sink with a lazy initial value.
  factory ValueStateSink.lazy(LazyValue<V> lazyInitValue,
          [Merger<V>? merger]) =>
      Transaction.runRequired((_) {
        final eventStreamSink = EventStreamSink<V>(merger);
        return ValueStateSink._(
            ValueState._(lazyInitValue, eventStreamSink.stream),
            eventStreamSink);
      });

  ValueStateSink._(this.state, this._eventStreamSink);

  bool get isClosed => _eventStreamSink.isClosed;

  void send(V value) => _eventStreamSink.send(value);
}

/// A forward-declared [ValueState] that can be connected later.
///
/// Useful for creating cyclic dependencies within a transaction.
class ValueStateLink<V> {
  final ValueState<V> state;
  late final LazyValue<V> _connectedLazyValue;

  factory ValueStateLink() => Transaction.runRequired((_) {
        late final ValueStateLink<V> link;
        link = ValueStateLink._(ValueState<V>._(
          LazyValue<V>.provide(() => link.isConnected
              ? link._connectedLazyValue.get()
              : throw StateError('ValueStateLink is not connected')),
          createEventStream<V>(
              KeyNode<V>(evaluateHandler: _defaultEvaluateHandler)),
        ));
        return link;
      });

  ValueStateLink._(this.state);

  bool get isConnected => _node.isLinked;
  bool get isNotConnected => !isConnected;

  /// Connects this link to [state]. Can only be called once.
  void connect(ValueState<V> state) => Transaction.runRequired((_) {
        if (isConnected) {
          throw StateError('Link already connected');
        }
        _connectedLazyValue = state.getLazyValue();
        _node.link(state._node);
      });

  KeyNode<V> get _node => state._node as KeyNode<V>;
}

/// A continuous value that changes over time.
///
/// Unlike [EventStream], a [ValueState] always has a current value
/// accessible via [getValue]. Listeners receive the current value
/// immediately upon subscription.
class ValueState<V> {
  final EventStream<V> _stream;
  late LazyValue<V> _currentLazyValue;
  Reference? _currentValueReference;

  /// Creates an immutable state with a constant value.
  ValueState.constant(V initValue)
      : this._(LazyValue.value(initValue), EventStream<V>.never());

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
        _currentLazyValue = LazyValue.value(value);
        _updateCurrentValueReference(value);
      }
    };
  }

  /// Combines multiple states using a combiner function.
  static ValueState<VR> combines<VR>(
          Iterable<ValueState> states, Combiners<VR> combiner) =>
      Transaction.runRequired((_) {
        final targetNode = IndexNode<VR>(
          evaluationType: EvaluationType.almostOneInput,
          evaluateHandler: (inputs) => NodeEvaluation(
            combiner(Map.fromIterables(states, inputs.evaluations)
                .entries
                .map((entry) => (entry.value?.isEvaluated ?? false)
                    ? entry.value!.value
                    : entry.key.getValue())),
          ),
        );
        targetNode.link(states.map((state) => state._stream.node));
        return ValueState._(
          LazyValue.combines(
              states.map((state) => state.getLazyValue()), combiner),
          createEventStream(targetNode),
        );
      });

  /// Unwraps a state-of-states into a flat state.
  static ValueState<V> switchState<V>(
          ValueState<ValueState<V>> statesState) =>
      Transaction.runRequired((_) {
        final targetNode =
            KeyNode<V>(evaluateHandler: _defaultEvaluateHandler);

        Transaction.addClosingTransactionHandler(targetNode, (tx) {
          if (tx.hasValue(statesState._node)) {
            targetNode.unlink();
            final newInnerState = statesState.getValue();
            targetNode.link(newInnerState._node);
            Transaction.runNew((newTx) {
              newTx.setValue(targetNode, newInnerState.getValue());
            });
          }
        });

        targetNode.link(statesState.getValue()._node);
        targetNode.reference(statesState._node);

        return ValueState._(
          LazyValue.provide(() => statesState.getValue().getValue()),
          createEventStream(targetNode),
        );
      });

  /// Unwraps a state-of-streams into a flat stream.
  static EventStream<E> switchStream<E>(
          ValueState<EventStream<E>> streamsState) =>
      Transaction.runRequired((_) {
        final targetNode =
            KeyNode<E>(evaluateHandler: _defaultEvaluateHandler);

        Transaction.addClosingTransactionHandler(targetNode, (tx) {
          if (tx.hasValue(streamsState._node)) {
            targetNode.unlink();
            targetNode.link(streamsState.getValue().node);
          }
        });

        targetNode.link(streamsState.getValue().node);
        targetNode.reference(streamsState._node);

        return createEventStream(targetNode);
      });

  /// Whether this state has any active references.
  bool get isReferenced => _node.isReferenced;

  /// Gets the current value.
  V getValue() => Transaction.run((_) => getLazyValue().get());

  /// Gets the lazy value container.
  LazyValue<V> getLazyValue() => _currentLazyValue;

  /// Creates an event stream that emits the current value immediately
  /// and all subsequent changes.
  EventStream<V> toValues() => Transaction.runRequired((_) {
        final targetNode = KeyNode<V>(
          evaluationType: EvaluationType.always,
          evaluateHandler: (inputs) => inputs.get<V>().isEvaluated
              ? inputs.get<V>()
              : NodeEvaluation(getValue()),
        );

        Transaction.addClosingTransactionHandler(targetNode, (tx) {
          targetNode.evaluationType = EvaluationType.allInputs;
          Transaction.removeClosingTransactionHandler(targetNode);
        });

        targetNode.link(_node);
        return createEventStream(targetNode);
      });

  /// Creates an event stream that emits only subsequent changes
  /// (not the current value).
  EventStream<V> toUpdates() =>
      Transaction.runRequired((_) => _stream);

  /// Filters out consecutive duplicate values.
  ///
  /// Unlike [EventStream.distinct], this initializes the previous value
  /// to the current state value, so the first update is correctly filtered
  /// against the initial value already delivered via [listen]/[toValues].
  ValueState<V> distinct([Equalizer<V>? distinctEquals]) =>
      Transaction.runRequired((_) {
        final equals = distinctEquals ?? (V a, V b) => a == b;
        var previous = NodeEvaluation<V>(getValue());
        final targetNode = KeyNode<V>(
          evaluateHandler: (inputs) =>
              previous.isNotEvaluated ||
                      !equals(inputs.get<V>().value, previous.value)
                  ? inputs.get<V>()
                  : NodeEvaluation<V>.not(),
          commitHandler: (value) => previous = NodeEvaluation(value),
        );
        targetNode.link(_stream.node);
        return ValueState._(_currentLazyValue, createEventStream(targetNode));
      });

  /// Transforms the value using [mapper].
  ValueState<VR> map<VR>(Mapper<V, VR> mapper) => Transaction.runRequired(
      (_) => ValueState._(_currentLazyValue.map(mapper), _stream.map(mapper)));

  /// Combines this state with another using a combiner function.
  ValueState<VR> combine<V2, VR>(
          ValueState<V2> state2, Combiner2<V, V2, VR> combiner) =>
      combines<VR>([this, state2], (values) {
        final it = values.iterator;
        return combiner(
          (it..moveNext()).current,
          (it..moveNext()).current,
        );
      });

  /// Combines with two other states.
  ValueState<VR> combine2<V2, V3, VR>(ValueState<V2> state2,
          ValueState<V3> state3, Combiner3<V, V2, V3, VR> combiner) =>
      combines<VR>([this, state2, state3], (values) {
        final it = values.iterator;
        return combiner(
          (it..moveNext()).current,
          (it..moveNext()).current,
          (it..moveNext()).current,
        );
      });

  /// Combines with three other states.
  ValueState<VR> combine3<V2, V3, V4, VR>(
          ValueState<V2> state2,
          ValueState<V3> state3,
          ValueState<V4> state4,
          Combiner4<V, V2, V3, V4, VR> combiner) =>
      combines<VR>([this, state2, state3, state4], (values) {
        final it = values.iterator;
        return combiner(
          (it..moveNext()).current,
          (it..moveNext()).current,
          (it..moveNext()).current,
          (it..moveNext()).current,
        );
      });

  /// Combines with four other states.
  ValueState<VR> combine4<V2, V3, V4, V5, VR>(
          ValueState<V2> state2,
          ValueState<V3> state3,
          ValueState<V4> state4,
          ValueState<V5> state5,
          Combiner5<V, V2, V3, V4, V5, VR> combiner) =>
      combines<VR>([this, state2, state3, state4, state5], (values) {
        final it = values.iterator;
        return combiner(
          (it..moveNext()).current,
          (it..moveNext()).current,
          (it..moveNext()).current,
          (it..moveNext()).current,
          (it..moveNext()).current,
        );
      });

  /// Ties a subscription's lifetime to this state's reference count.
  ValueState<V> addReferencedSubscription(ListenSubscription subscription) =>
      Transaction.runRequired((_) => ValueState._(_currentLazyValue,
          _stream.addListenSubscriptionCleaner(subscription)));

  /// Listens to value changes. Delivers the current value immediately.
  ListenSubscription listen(ValueHandler<V> onValue) =>
      Transaction.run((_) => toValues().listen(onValue));

  /// Maps and switches to inner states.
  ValueState<VR> switchMapState<VR>(Mapper<V, ValueState<VR>> mapper) =>
      ValueState.switchState<VR>(map<ValueState<VR>>(mapper));

  /// Maps and switches to inner streams.
  EventStream<ER> switchMapStream<ER>(Mapper<V, EventStream<ER>> mapper) =>
      ValueState.switchStream<ER>(map<EventStream<ER>>(mapper));

  Node<V> get _node => _stream.node;

  void _updateCurrentValueReference(V value) {
    _currentValueReference?.dispose();
    if (value is EventStream) {
      _currentValueReference = _node.reference(value.node);
    } else if (value is ValueState) {
      _currentValueReference = _node.reference(value._node);
    } else if (value is Referenceable) {
      _currentValueReference = _node.reference(value);
    } else {
      _currentValueReference = null;
    }
  }
}

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

  /// Creates a self-referential state for cyclic dependencies.
  ///
  /// The [builder] receives a forward-declared state (`self`) that can be
  /// used in expressions before its definition is known. The builder must
  /// return the actual [ValueState] that `self` will resolve to.
  ///
  /// ```dart
  /// final counter = ValueState.loop<int>((self) =>
  ///     incrementStream.snapshot(self, (_, n) => n + 1).toState(0));
  /// ```
  static ValueState<V> loop<V>(
          ValueState<V> Function(ValueState<V> self) builder) =>
      Transaction.runRequired((_) {
        final link = ValueStateLink<V>();
        link.connect(builder(link.state));
        return link.state;
      });

  /// Like [loop], but the builder returns a record `(ValueState<V>, R)`.
  ///
  /// The first element closes the cycle (connected to `self`);
  /// the second element is returned alongside the looped state,
  /// allowing extraction of intermediate signals without `late` variables.
  ///
  /// ```dart
  /// final (counter, resetStream) = ValueState.loopWith((ValueState<int> self) {
  ///   final reset = someStream.snapshot(self, (_, n) => n > 10);
  ///   return (incrementStream.snapshot(self, (_, n) => n + 1).toState(0), reset);
  /// });
  /// ```
  static (ValueState<V>, R) loopWith<V, R>(
          (ValueState<V>, R) Function(ValueState<V> self) builder) =>
      Transaction.runRequired((_) {
        final link = ValueStateLink<V>();
        final (state, extra) = builder(link.state);
        link.connect(state);
        return (link.state, extra);
      });

  ValueState._(LazyValue<V> lazyInitValue, this._stream)
      : _currentLazyValue = lazyInitValue {
    if (lazyInitValue.hasValue) {
      _updateCurrentValueReference(lazyInitValue.get());
    }

    // Override the node's commit handler to keep _currentLazyValue in sync
    // with committed values and maintain reference-counted ownership of the
    // current value (if it is Referenceable), preventing premature disposal.
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
          evaluationType: EvaluationType.atLeastOneInput,
          evaluateHandler: (inputs) => NodeEvaluation(
            combiner(Map.fromIterables(states, inputs.evaluations).entries.map(
                (entry) => (entry.value?.isEvaluated ?? false)
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
  static ValueState<V> switchState<V>(ValueState<ValueState<V>> statesState) =>
      Transaction.runRequired((_) {
        final targetNode = KeyNode<V>(evaluateHandler: _defaultEvaluateHandler);

        // Relinking must happen in the closing phase (after publish) because
        // unlinking during evaluation/commit would corrupt the in-flight
        // transaction's node graph. A new transaction is needed to propagate
        // the switched-to state's current value through the freshly linked node.
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
        // Keep a reference to the outer state's node so it stays alive as long
        // as this switchState node is alive.
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
        final targetNode = KeyNode<E>(evaluateHandler: _defaultEvaluateHandler);

        // Relinking in the closing phase (after publish) avoids mutating
        // the DAG while the current transaction is still evaluating or
        // delivering values. No runNew is needed here (unlike switchState)
        // because streams have no "current value" to propagate immediately.
        Transaction.addClosingTransactionHandler(targetNode, (tx) {
          if (tx.hasValue(streamsState._node)) {
            targetNode.unlink();
            targetNode.link(streamsState.getValue().node);
          }
        });

        targetNode.link(streamsState.getValue().node);
        // Keep a reference to the outer state's node so it stays alive as long
        // as this switchStream node is alive.
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
  EventStream<V> toUpdates() => Transaction.runRequired((_) => _stream);

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
          evaluateHandler: (inputs) => previous.isNotEvaluated ||
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

  // Manages a single reference from this node to its current value's
  // underlying Referenceable (if any). The old reference is always disposed
  // first to release the previous value. A new reference is created only
  // when the value is reference-counted (EventStream, ValueState, or raw
  // Referenceable), keeping it alive for as long as this state holds it.
  // Plain values need no reference — they are not reference-counted.
  // Acquires the new reference before disposing the old one to prevent
  // inconsistent state if reference() throws (spec §7: ref management
  // must not leave dangling pointers).
  void _updateCurrentValueReference(V value) {
    final oldRef = _currentValueReference;
    if (value is EventStream) {
      _currentValueReference = _node.reference(value.node);
    } else if (value is ValueState) {
      _currentValueReference = _node.reference(value._node);
    } else if (value is Referenceable) {
      _currentValueReference = _node.reference(value);
    } else {
      _currentValueReference = null;
    }
    oldRef?.dispose();
  }
}

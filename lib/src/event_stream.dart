import 'lazy_value.dart';
import 'listen_subscription.dart';
import 'node.dart';
import 'node_evaluation.dart';
import 'reference.dart';
import 'transaction.dart';
import 'typedefs.dart';
import 'value_state.dart';

/// Provides access to the internal node of an [EventStream].
extension EventStreamNode<E> on EventStream<E> {
  Node<E> get node => _node;
}

/// Creates an [EventStream] wrapping the given [node].
EventStream<E> createEventStream<E>(Node<E> node) => EventStream._(node);

Merger<E> _defaultSinkMerger<E>() => (E newValue, E oldValue) =>
    throw UnsupportedError(
        "Can't send multiple times in the same transaction without a merger");

Merger<E> _defaultMerger<E>() => (E value1, E value2) => value1;

NodeEvaluation<E> _defaultEvaluateHandler<E>(NodeEvaluationMap inputs) =>
    inputs.get<E>();

/// An input sink for sending events into an [EventStream].
///
/// Created within a transaction, the sink's lifetime is tied to the
/// stream's reference count. Sending after the stream is unreferenced
/// throws [StateError].
class EventStreamSink<E> {
  final EventStream<E> stream;
  final Merger<E> _sinkMerger;

  /// Creates a new sink. Optionally provide a [sinkMerger] to allow
  /// multiple sends in the same transaction.
  factory EventStreamSink([Merger<E>? sinkMerger]) =>
      Transaction.runRequired((_) => EventStreamSink._(
          EventStream<E>._(KeyNode<E>(evaluationType: EvaluationType.never)),
          sinkMerger));

  EventStreamSink._(this.stream, Merger<E>? sinkMerger)
      : _sinkMerger = sinkMerger ?? _defaultSinkMerger<E>();

  /// Whether the underlying stream has been unreferenced.
  bool get isClosed => !stream.isReferenced;

  /// Sends an [event] into the stream.
  ///
  /// Throws [StateError] if the sink is closed.
  /// Throws [UnsupportedError] if called multiple times in the same
  /// transaction without a merger function.
  void send(E event) {
    if (isClosed) {
      throw StateError('Sink is closed');
    }
    stream._sendValue(event, _sinkMerger);
  }
}

/// A forward-declared [EventStream] that can be connected later.
///
/// Useful for creating cyclic dependencies within a transaction.
class EventStreamLink<E> {
  final EventStream<E> stream;

  factory EventStreamLink() => Transaction.runRequired((_) =>
      EventStreamLink._(EventStream<E>._(
          KeyNode<E>(evaluateHandler: _defaultEvaluateHandler))));

  EventStreamLink._(this.stream);

  bool get isConnected => _node.isLinked;
  bool get isNotConnected => !isConnected;

  /// Connects this link to [stream]. Can only be called once.
  void connect(EventStream<E> stream) => Transaction.runRequired((_) {
        if (isConnected) {
          throw StateError('Link already connected');
        }
        _node.link(stream._node);
      });

  KeyNode<E> get _node => stream._node as KeyNode<E>;
}

/// A discrete stream of events over time.
///
/// Events are only delivered to listeners that are active at the time
/// the event is sent. There is no event history or replay.
class EventStream<E> {
  final Node<E> _node;

  /// Creates an event stream that never emits any events.
  EventStream.never()
      : _node = KeyNode<E>(evaluationType: EvaluationType.never);

  EventStream._(this._node);

  /// Merges multiple [streams] into one.
  ///
  /// When events arrive simultaneously, [merger] resolves conflicts
  /// (defaults to keeping the first value).
  static EventStream<E> merges<E>(Iterable<EventStream<E>> streams,
          [Merger<E>? merger]) =>
      Transaction.runRequired((tx) {
        final list = streams.toList();
        return _merges(tx, list, 0, list.length, merger ?? _defaultMerger<E>());
      });

  static EventStream<E> _merges<E>(Transaction tx,
      List<EventStream<E>> streams, int start, int end, Merger<E> merger) {
    switch (end - start) {
      case 0:
        return EventStream<E>.never();
      case 1:
        return streams[start];
      case 2:
        return _merges2(tx, streams[start], streams[start + 1], merger);
      default:
        final mid = (start + end) ~/ 2;
        return _merges2(
          tx,
          _merges(tx, streams, start, mid, merger),
          _merges(tx, streams, mid, end, merger),
          merger,
        );
    }
  }

  static EventStream<E> _merges2<E>(Transaction tx, EventStream<E> stream1,
      EventStream<E> stream2, Merger<E> merger) {
    const input1 = 'input1';
    const input2 = 'input2';

    final targetNode = KeyNode<E>(
      evaluationType: EvaluationType.almostOneInput,
      evaluateHandler: (inputs) {
        if (inputs.get<E>(input1).isNotEvaluated) {
          return inputs.get<E>(input2);
        } else if (inputs.get<E>(input2).isEvaluated) {
          return NodeEvaluation<E>(
              merger(inputs.get<E>(input1).value, inputs.get<E>(input2).value));
        } else {
          return inputs.get<E>(input1);
        }
      },
    );
    targetNode
      ..link(stream1._node, key: input1)
      ..link(stream2._node, key: input2);

    return EventStream._(targetNode);
  }

  /// Whether this stream has any active references.
  bool get isReferenced => _node.isReferenced;

  /// Converts this event stream to a [ValueState] with [initValue].
  ValueState<E> toState(E initValue) => toStateLazy(LazyValue.value(initValue));

  /// Converts this event stream to a [ValueState] with a lazy initial value.
  ValueState<E> toStateLazy(LazyValue<E> lazyInitValue) =>
      Transaction.runRequired((_) => createValueState(lazyInitValue, this));

  /// Emits only the first event, then stops.
  EventStream<E> once() => Transaction.runRequired((tx) {
        late final KeyNode<E> targetNode;
        targetNode = KeyNode<E>(
          evaluateHandler: _defaultEvaluateHandler,
          commitHandler: (_) =>
              targetNode.evaluationType = EvaluationType.never,
        );
        targetNode.link(_node);
        return EventStream._(targetNode);
      });

  /// Filters out consecutive duplicate values.
  EventStream<E> distinct([Equalizer<E>? distinctEquals]) {
    final equals = distinctEquals ?? (E a, E b) => a == b;
    return Transaction.runRequired((_) {
      var previous = NodeEvaluation<E>.not();
      final targetNode = KeyNode<E>(
        evaluateHandler: (inputs) =>
            previous.isNotEvaluated || !equals(inputs.get<E>().value, previous.value)
                ? inputs.get<E>()
                : NodeEvaluation<E>.not(),
        commitHandler: (value) => previous = NodeEvaluation(value),
      );
      targetNode.link(_node);
      return EventStream._(targetNode);
    });
  }

  /// Transforms each event using [mapper].
  EventStream<ER> map<ER>(Mapper<E, ER> mapper) =>
      Transaction.runRequired((_) {
        final targetNode = KeyNode<ER>(
          evaluateHandler: (inputs) =>
              NodeEvaluation<ER>(mapper(inputs.get<E>().value)),
        );
        targetNode.link(_node);
        return EventStream._(targetNode);
      });

  /// Maps every event to a constant [event].
  EventStream<ER> mapTo<ER>(ER event) => map<ER>((_) => event);

  /// Maps every event to null.
  EventStream<E?> mapToNull() => map<E?>((event) => null);

  /// Casts this stream to a different type.
  EventStream<ER> cast<ER>() => this is EventStream<ER>
      ? this as EventStream<ER>
      : map<ER>((event) => event as ER);

  /// Casts to a nullable version of the same type.
  EventStream<E?> castToNullable() => cast<E?>();

  /// Filters events based on [filter] predicate.
  EventStream<E> where(Filter<E> filter) => Transaction.runRequired((_) {
        final targetNode = KeyNode<E>(
          evaluateHandler: (inputs) => filter(inputs.get<E>().value)
              ? inputs.get<E>()
              : NodeEvaluation<E>.not(),
        );
        targetNode.link(_node);
        return EventStream._(targetNode);
      });

  /// Filters events to only those matching type [ER].
  EventStream<ER> whereType<ER>() =>
      Transaction.runRequired((_) => where((event) => event is ER).cast<ER>());

  /// Filters out null values from a nullable event stream.
  EventStream<E> mapWhereNotNull() => where((e) => e != null);

  /// Accumulates a state over events.
  ValueState<V> accumulate<V>(V initValue, Accumulator<E, V> accumulator) =>
      Transaction.runRequired((_) {
        final link = ValueStateLink<V>();
        link.connect(snapshot(link.state, accumulator).toState(initValue));
        return link.state;
      });

  /// Accumulates a state with lazy initial value.
  ValueState<V> accumulateLazy<V>(
          LazyValue<V> lazyInitValue, Accumulator<E, V> accumulator) =>
      Transaction.runRequired((_) {
        final link = ValueStateLink<V>();
        link.connect(
            snapshot(link.state, accumulator).toStateLazy(lazyInitValue));
        return link.state;
      });

  /// Collects events with stateful transformation.
  EventStream<ER> collect<ER, V>(V initValue, Collector<E, V, ER> collector) =>
      Transaction.runRequired((_) {
        final link = EventStreamLink<V>();
        final stream = snapshot(link.stream.toState(initValue), collector);
        link.connect(stream.map((tuple) => tuple.item2));
        return stream.map((tuple) => tuple.item1);
      });

  /// Collects events with lazy initial state.
  EventStream<ER> collectLazy<ER, V>(
          LazyValue<V> lazyInitValue, Collector<E, V, ER> collector) =>
      Transaction.runRequired((_) {
        final link = EventStreamLink<V>();
        final stream =
            snapshot(link.stream.toStateLazy(lazyInitValue), collector);
        link.connect(stream.map((tuple) => tuple.item2));
        return stream.map((tuple) => tuple.item1);
      });

  /// Gates this stream by a boolean condition state.
  ///
  /// Events pass through only when [conditionState] is true.
  EventStream<E> gate(ValueState<bool> conditionState) =>
      Transaction.runRequired((_) => snapshot<bool, E?>(
              conditionState, (event, condition) => condition ? event : null)
          .where((e) => e != null)
          .cast<E>());

  /// Merges this stream with [stream], preferring this stream's events.
  EventStream<E> orElse(EventStream<E> stream) => merges<E>([this, stream]);

  /// Merges this stream with multiple [streams].
  EventStream<E> orElses(Iterable<EventStream<E>> streams) =>
      merges<E>([this, ...streams]);

  /// Combines each event with the current value of [fromState].
  EventStream<ER> snapshot<V2, ER>(
          ValueState<V2> fromState, Combiner2<E, V2, ER> combiner) =>
      Transaction.runRequired((_) {
        final stream = map((event) => combiner(event, fromState.getValue()));
        stream._node.reference(fromState.node);
        return stream;
      });

  /// Listens to events. Returns a subscription that must be cancelled.
  ///
  /// If the subscription is garbage collected without being cancelled,
  /// it will be cleaned up automatically via [Finalizer].
  ListenSubscription listen(ValueHandler<E> onEvent) =>
      Transaction.run((_) {
        final listenNode = KeyNode<E>(
          evaluateHandler: _defaultEvaluateHandler,
          publishHandler: onEvent,
        );
        listenNode.link(_node);
        return _ReferenceListenSubscription(Reference(listenNode));
      });

  /// Listens to the first event only, then auto-cancels.
  ListenSubscription listenOnce(ValueHandler<E> onEvent) {
    late final ListenSubscription sub;
    sub = listen((data) {
      sub.cancel();
      onEvent(data);
    });
    return sub;
  }

  /// Ties a subscription's lifetime to this stream's reference count.
  EventStream<E> addListenSubscriptionCleaner(
          ListenSubscription subscription) =>
      Transaction.runRequired((_) {
        final targetNode = KeyNode<E>(
          evaluateHandler: _defaultEvaluateHandler,
          unreferencedHandler: subscription.cancel,
        );
        targetNode.link(_node);
        return EventStream._(targetNode);
      });

  void _sendValue(E event, Merger<E> sinkMerger) {
    Transaction.run((tx) {
      if (tx.phase != TransactionPhase.opened) {
        throw UnsupportedError("Can't send value during evaluation/commit/publish");
      }
      if (tx.hasValue(_node)) {
        tx.setValue(_node, sinkMerger(event, tx.getValue(_node)));
      } else {
        tx.setValue(_node, event);
      }
    });
  }
}

/// A listen subscription backed by a [Reference].
///
/// Supports automatic cleanup via [Finalizer] if not explicitly cancelled.
class _ReferenceListenSubscription extends ListenSubscription {
  static final _finalizer = Finalizer<Reference>((ref) {
    if (!ref.isDisposed) {
      try {
        ref.dispose();
      } catch (_) {
        // Scope may already be disposed during GC
      }
    }
  });

  final Reference _reference;

  _ReferenceListenSubscription(this._reference) {
    _finalizer.attach(this, _reference, detach: this);
  }

  @override
  void cancel() {
    if (!_reference.isDisposed) {
      _finalizer.detach(this);
      _reference.dispose();
    }
  }
}

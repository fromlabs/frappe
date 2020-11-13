import 'package:frappe/src/frappe_object.dart';
import 'package:frappe/src/lazy_value.dart';
import 'package:frappe/src/listen_subscription.dart';
import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';
import 'package:frappe/src/typedef.dart';
import 'package:frappe/src/value_state.dart';

extension ExtendedEventStream<E> on EventStream<E> {
  Node<E> get node => _node;
}

extension _NullableEventStream<E> on EventStream<E?> {
  EventStream<E> mapWhereNotNull() => whereType<E>();
}

EventStream<E> createEventStream<E>(Node<E> node) => EventStream._(node);

Merger<E> _defaultSinkMergerFactory<E>() =>
    (E newValue, E oldValue) => throw UnsupportedError(
        '''Can't send more times in the same transaction with the default merger''');

Merger<E> _defaultMergerFactory<E>() => (E value1, E value2) => value1;

// FIXME roby: verificare chi lo utilizza
NodeEvaluation<E> _defaultEvaluateHandler<E>(NodeEvaluationMap inputs) =>
    inputs.get<E>();

class EventStreamSink<E> {
  final EventStream<E> stream;
  final Merger<E> _sinkMerger;

  factory EventStreamSink([Merger<E>? sinkMerger]) =>
      Transaction.runRequired((_) => EventStreamSink._(
          EventStream<E>._(KeyNode<E>(evaluationType: EvaluationType.never)),
          sinkMerger));

  EventStreamSink._(this.stream, Merger<E>? sinkMerger)
      : _sinkMerger = sinkMerger ?? _defaultSinkMergerFactory<E>();

  bool get isClosed => !stream.isReferenced;

  void send(E event) {
    if (isClosed) {
      throw StateError('Sink is closed');
    }

    stream._sendValue(event, _sinkMerger);
  }
}

class EventStreamLink<E> {
  final EventStream<E> stream;

  factory EventStreamLink() => Transaction.runRequired((transaction) =>
      EventStreamLink._(EventStream<E>._(
          KeyNode<E>(evaluateHandler: _defaultEvaluateHandler))));

  EventStreamLink._(this.stream);

  bool get isConnected => _node.isLinked;

  bool get isNotConnected => !isConnected;

  void connect(EventStream<E> stream) => Transaction.runRequired((_) {
        if (isConnected) {
          throw StateError('Link already connected');
        }

        _node.link(stream._node);
      });

  KeyNode<E> get _node => stream._node as KeyNode<E>;
}

class EventStream<E> extends FrappeObject<E> {
  final Node<E> _node;

  EventStream.never()
      : _node = KeyNode<E>(evaluationType: EvaluationType.never);

  EventStream._(this._node);

  static EventStream<E> merges<E>(Iterable<EventStream<E>> streams,
          [Merger<E>? merger]) =>
      Transaction.runRequired((transaction) {
        final streamList = streams.toList();
        return _merges(transaction, streamList, 0, streamList.length,
            merger ?? _defaultMergerFactory<E>());
      });

  static EventStream<E> _merges<E>(Transaction transaction,
      List<EventStream<E>> streams, int start, int end, Merger<E> merger) {
    switch (end - start) {
      case 0:
        return EventStream<E>.never();
      case 1:
        return streams[start];
      case 2:
        return _merges2(
            transaction, streams[start], streams[start + 1], merger);
      default:
        final mid = (start + end) ~/ 2;
        return _merges2(
            transaction,
            _merges<E>(transaction, streams, start, mid, merger),
            _merges<E>(transaction, streams, mid, end, merger),
            merger);
    }
  }

  static EventStream<E> _merges2<E>(Transaction transaction,
      EventStream<E> stream1, EventStream<E> stream2, Merger<E> merger) {
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

  bool get isReferenced => _node.isReferenced;

  ValueState<E> toState(E initValue) => toStateLazy(LazyValue.value(initValue));

  ValueState<E> toStateLazy(LazyValue<E> lazyInitValue) =>
      Transaction.runRequired((_) => createValueState(lazyInitValue, this));

  EventStream<E> once() => Transaction.runRequired((transaction) {
        late final KeyNode<E> targetNode;

        targetNode = KeyNode<E>(
          evaluateHandler: _defaultEvaluateHandler,
          commitHandler: (_) =>
              targetNode.evaluationType = EvaluationType.never,
        );

        targetNode.link(_node);

        return EventStream._(targetNode);
      });

  EventStream<E> distinct([Equalizer<E>? distinctEquals]) {
    final equals = distinctEquals ??
        (E value1, E value2) {
          return value1 == value2;
        };

    return Transaction.runRequired((transaction) {
      var previousEvaluation = NodeEvaluation<E>.not();
      final targetNode = KeyNode<E>(
        evaluateHandler: (inputs) => previousEvaluation.isNotEvaluated ||
                !equals(inputs.get<E>().value, previousEvaluation.value)
            ? inputs.get<E>()
            : NodeEvaluation<E>.not(),
        commitHandler: (value) => previousEvaluation = NodeEvaluation(value),
      );

      targetNode.link(_node);

      return EventStream._(targetNode);
    });
  }

  EventStream<ER> map<ER>(Mapper<E, ER> mapper) =>
      Transaction.runRequired((transaction) {
        final targetNode = KeyNode<ER>(
            evaluateHandler: (inputs) =>
                NodeEvaluation<ER>(mapper.call(inputs.get<E>().value)));

        targetNode.link(_node);

        return EventStream._(targetNode);
      });

  EventStream<ER> mapTo<ER>(ER event) => map<ER>((_) => event);

  EventStream<E?> mapToNull() => map<E?>((event) => null);

  EventStream<ER> cast<ER>() => this is EventStream<ER>
      ? this as EventStream<ER>
      : map<ER>((event) => event as ER);

  EventStream<E?> castToNullable() => cast<E?>();

  EventStream<E> where(Filter<E> filter) =>
      Transaction.runRequired((transaction) {
        final targetNode = KeyNode<E>(
          evaluateHandler: (inputs) => filter(inputs.get<E>().value)
              ? inputs.get<E>()
              : NodeEvaluation<E>.not(),
        );

        targetNode.link(_node);

        return EventStream._(targetNode);
      });

  EventStream<ER> whereType<ER>() => Transaction.runRequired(
      (transaction) => where((event) => event is ER).cast<ER>());

  ValueState<V> accumulate<V>(V initValue, Accumulator<E, V> accumulator) =>
      Transaction.runRequired((transaction) {
        final reference = ValueStateLink<V>();
        reference
            .connect(snapshot(reference.state, accumulator).toState(initValue));
        return reference.state;
      });

  ValueState<V> accumulateLazy<V>(
          LazyValue<V> lazyInitValue, Accumulator<E, V> accumulator) =>
      Transaction.runRequired((transaction) {
        final reference = ValueStateLink<V>();
        reference.connect(
            snapshot(reference.state, accumulator).toStateLazy(lazyInitValue));
        return reference.state;
      });

  EventStream<ER> collect<ER, V>(V initValue, Collector<E, V, ER> collector) =>
      Transaction.runRequired((transaction) {
        final reference = EventStreamLink<V>();
        final stream = snapshot(reference.stream.toState(initValue), collector);
        reference.connect(stream.map((tuple) => tuple.item2));
        return stream.map((tuple) => tuple.item1);
      });

  EventStream<ER> collectLazy<ER, V>(
          LazyValue<V> lazyInitValue, Collector<E, V, ER> collector) =>
      Transaction.runRequired((transaction) {
        final reference = EventStreamLink<V>();
        final stream =
            snapshot(reference.stream.toStateLazy(lazyInitValue), collector);
        reference.connect(stream.map((tuple) => tuple.item2));
        return stream.map((tuple) => tuple.item1);
      });

  EventStream<E> gate(ValueState<bool> conditionState) =>
      Transaction.runRequired((transaction) => snapshot<bool, E?>(
              conditionState, (event, condition) => condition ? event : null)
          .mapWhereNotNull());

  EventStream<E> orElse(EventStream<E> stream) => merges<E>([this, stream]);

  EventStream<E> orElses(Iterable<EventStream<E>> streams) =>
      merges<E>([this, ...streams]);

  EventStream<ER> snapshot<V2, ER>(
          ValueState<V2> fromState, Combiner2<E, V2, ER> combiner) =>
      Transaction.runRequired((transaction) {
        final stream = map((event) => combiner(event, fromState.getValue()));

        stream._node.reference(fromState.node);

        return stream;
      });

  ListenSubscription listen(ValueHandler<E> onEvent) =>
      Transaction.run((transaction) {
        final listenNode = KeyNode<E>(
          evaluateHandler: _defaultEvaluateHandler,
          publishHandler: onEvent,
        );

        listenNode.link(_node);

        return _ReferenceListenSubscription(Reference(listenNode));
      });

  ListenSubscription listenOnce(ValueHandler<E> onEvent) {
    late final ListenSubscription listenSubscription;

    listenSubscription = listen((data) {
      listenSubscription.cancel();

      onEvent(data);
    });

    return listenSubscription;
  }

  EventStream<E> addListenSubscriptionCleaner(
          ListenSubscription subscription) =>
      Transaction.runRequired((transaction) {
        final targetNode = KeyNode<E>(
            evaluateHandler: _defaultEvaluateHandler,
            unreferencedHandler: subscription.cancel);

        targetNode.link(_node);

        return EventStream._(targetNode);
      });

  void _sendValue(E event, Merger<E> sinkMerger) {
    Transaction.run((transaction) {
      if (transaction.phase != TransactionPhase.opened) {
        throw UnsupportedError('''Can't send value in callbacks''');
      }

      if (transaction.hasValue(_node)) {
        transaction.setValue(
            _node, sinkMerger(event, transaction.getValue(_node)));
      } else {
        transaction.setValue(_node, event);
      }
    });
  }
}

class _ReferenceListenSubscription extends ListenSubscription {
  final Reference _reference;

  _ReferenceListenSubscription(this._reference);

  @override
  void cancel() => _reference.dispose();
}

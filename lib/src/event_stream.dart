import 'package:optional/optional.dart';

import 'reference.dart';
import 'node.dart';
import 'listen_subscription.dart';
import 'typedef.dart';
import 'value_state.dart';

Node<E> getEventStreamNode<E>(EventStream<E> stream) => stream._node;

EventStream<E> createEventStream<E>(Node<E> node) => EventStream._(node);

OptionalEventStream<E> createOptionalEventStream<E>(Node<Optional<E>> node) =>
    OptionalEventStream._(node);

Merger<E> _defaultSinkMergerFactory<E>() =>
    (E newValue, E oldValue) => throw UnsupportedError(
        '''Can't send more times in the same transaction with the default merger''');

Merger<E> _defaultMergerFactory<E>() => (E value1, E value2) => value1;

NodeEvaluation<E> _defaultEvaluateHandler<E>(NodeEvaluationMap inputs) =>
    inputs.evaluation;

class EventStreamSink<E> {
  final EventStream<E> stream;
  final Reference<Node<E>> _nodeReference;
  final Merger<E> _sinkMerger;

  factory EventStreamSink([Merger<E> sinkMerger]) =>
      Transaction.run((_) => EventStreamSink._(
          EventStream<E>._(KeyNode<E>(evaluationType: EvaluationType.never)),
          sinkMerger));

  EventStreamSink._(this.stream, Merger<E> sinkMerger)
      : _nodeReference = Reference(stream._node),
        _sinkMerger = sinkMerger ?? _defaultSinkMergerFactory<E>();

  bool get isClosed => _nodeReference.isDisposed;

  void close() => _nodeReference.dispose();

  void send(E event) {
    if (isClosed) {
      throw StateError('Sink is closed');
    }

    stream._sendValue(event, _sinkMerger);
  }
}

class OptionalEventStreamSink<E> extends EventStreamSink<Optional<E>> {
  factory OptionalEventStreamSink([Merger<Optional<E>> sinkMerger]) =>
      Transaction.run((_) => OptionalEventStreamSink._(
          OptionalEventStream<E>._(
              KeyNode<Optional<E>>(evaluationType: EvaluationType.never)),
          sinkMerger));

  OptionalEventStreamSink._(
      OptionalEventStream<E> stream, Merger<Optional<E>> sinkMerger)
      : super._(stream, sinkMerger);

  @override
  OptionalEventStream<E> get stream => super.stream;

  void sendOptionalEmpty() => send(Optional<E>.empty());

  void sendOptionalOf(E event) => send(Optional<E>.of(event));
}

class EventStreamLink<E> {
  final EventStream<E> stream;

  factory EventStreamLink() => Transaction.runRequired((transaction) =>
      EventStreamLink._(EventStream<E>._(
          KeyNode<E>(evaluateHandler: _defaultEvaluateHandler))));

  EventStreamLink._(this.stream);

  bool get isLinked => _node.isLinked;

  void connect(EventStream<E> stream) => Transaction.runRequired((_) {
        if (isLinked) {
          throw StateError("Reference already linked");
        }

        _node.link(stream._node);
      });

  KeyNode<E> get _node => stream._node;
}

class OptionalEventStreamLink<E> extends EventStreamLink<Optional<E>> {
  factory OptionalEventStreamLink() => Transaction.runRequired((transaction) =>
      OptionalEventStreamLink._(OptionalEventStream<E>._(
          KeyNode<Optional<E>>(evaluateHandler: _defaultEvaluateHandler))));

  OptionalEventStreamLink._(OptionalEventStream<E> stream) : super._(stream);

  @override
  OptionalEventStream<E> get stream => super.stream;

  @override
  void connect(covariant OptionalEventStream<E> stream) =>
      super.connect(stream);
}

class EventStream<E> {
  final Node<E> _node;

  EventStream.never()
      : _node = KeyNode<E>(evaluationType: EvaluationType.never);

  EventStream._(this._node, [Merger<E> sinkMerger]);

  static EventStream<E> merges<E>(Iterable<EventStream<E>> streams,
          [Merger<E> merger]) =>
      Transaction.runRequired((transaction) {
        final streamList = streams.toList();
        return _merges(transaction, streamList, 0, streamList.length,
            merger ?? _defaultMergerFactory<E>());
      });

  static EventStream<E> _merges<E>(
      Transaction transaction, List<EventStream<E>> streams, int start, int end,
      [Merger<E> merger]) {
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

  static EventStream<E> _merges2<E>(
      Transaction transaction, EventStream<E> stream1, EventStream<E> stream2,
      [Merger<E> merger]) {
    const input1 = 'input1';
    const input2 = 'input2';

    final targetNode = KeyNode<E>(
      evaluationType: EvaluationType.almostOneInput,
      evaluateHandler: (inputs) {
        if (inputs[input1].isNotEvaluated) {
          return inputs[input2];
        } else if (inputs[input2].isEvaluated) {
          return NodeEvaluation<E>(
              merger(inputs[input1].value, inputs[input2].value));
        } else {
          return inputs[input1];
        }
      },
    );

    targetNode
      ..link(stream1._node, key: input1)
      ..link(stream2._node, key: input2);

    return EventStream._(targetNode);
  }

  OptionalEventStream<EE> asOptional<EE>() =>
      Transaction.runRequired((transaction) {
        final targetNode =
            KeyNode<Optional<EE>>(evaluateHandler: _defaultEvaluateHandler);
        targetNode.link(_node);
        return OptionalEventStream._(targetNode);
      });

  ValueState<E> toState(E initValue) => toStateLazy(LazyValue(initValue));

  ValueState<E> toStateLazy(LazyValue<E> lazyInitValue) =>
      Transaction.runRequired((_) => createValueState(lazyInitValue, this));

  EventStream<E> once() => Transaction.runRequired((transaction) {
        var neverEvaluated = true;
        final targetNode = KeyNode<E>(
          evaluateHandler: (inputs) =>
              neverEvaluated ? inputs.evaluation : NodeEvaluation.not(),
          commitHandler: (_) => neverEvaluated = false,
        );

        targetNode.link(_node);

        return EventStream._(targetNode);
      });

  EventStream<E> distinct([Equalizer<E> distinctEquals]) =>
      Transaction.runRequired((transaction) {
        var previousEvaluation = NodeEvaluation<E>.not();
        final targetNode = KeyNode<E>(
          evaluateHandler: (inputs) => previousEvaluation.isNotEvaluated ||
                  inputs.evaluation.value != previousEvaluation.value
              ? inputs.evaluation
              : NodeEvaluation.not(),
          commitHandler: (value) => previousEvaluation = NodeEvaluation(value),
        );

        targetNode.link(_node);

        return EventStream._(targetNode);
      });

  EventStream<ER> map<ER>(Mapper<E, ER> mapper) =>
      Transaction.runRequired((transaction) {
        final targetNode = KeyNode<ER>(
            evaluateHandler: (inputs) =>
                NodeEvaluation<ER>(mapper.call(inputs.evaluation.value)));

        targetNode.link(_node);

        return EventStream._(targetNode);
      });

  EventStream<ER> mapTo<ER>(ER event) => map<ER>((_) => event);

  OptionalEventStream<EE> mapToOptionalEmpty<EE>() =>
      Transaction.runRequired((transaction) =>
          mapTo<Optional<EE>>(Optional<EE>.empty()).asOptional<EE>());

  OptionalEventStream<E> mapToOptionalOf() =>
      Transaction.runRequired((transaction) =>
          map<Optional<E>>((event) => Optional<E>.of(event)).asOptional<E>());

  EventStream<E> where(Filter<E> filter) =>
      Transaction.runRequired((transaction) {
        final targetNode = KeyNode<E>(
          evaluateHandler: (inputs) => filter(inputs.evaluation.value)
              ? inputs.evaluation
              : NodeEvaluation.not(),
        );

        targetNode.link(_node);

        return EventStream._(targetNode);
      });

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
      Transaction.runRequired((transaction) => snapshot(
              conditionState,
              (event, condition) =>
                  condition ? Optional<E>.of(event) : Optional<E>.empty())
          .asOptional<E>()
          .mapWhereOptional());

  EventStream<E> orElse(EventStream<E> stream) => merges<E>([this, stream]);

  EventStream<E> orElses(Iterable<EventStream<E>> streams) =>
      merges<E>([this, ...streams]);

  // TODO creare cmq un riferimento a fromState legato a questo nodo
  EventStream<ER> snapshot<V2, ER>(
          ValueState<V2> fromState, Combiner2<E, V2, ER> combiner) =>
      Transaction.runRequired((transaction) {
        final stream = map((event) => combiner(event, fromState.current()));

        stream._node.reference(getValueStateNode(fromState));

        return stream;
      });

  ListenSubscription listen(ValueHandler<E> onEvent) =>
      Transaction.run((transaction) {
        final listenNode = KeyNode<E>(
          evaluateHandler: _defaultEvaluateHandler,
          publishHandler: onEvent,
        );

        final reference = Reference(listenNode);

        listenNode.link(_node);

        return _ReferenceListenSubscription(reference);
      });

  ListenSubscription listenOnce(ValueHandler<E> onEvent) {
    ListenSubscription listenSubscription;

    listenSubscription = listen((data) {
      listenSubscription.cancel();

      onEvent(data);
    });

    return listenSubscription;
  }

  void _sendValue(E event, Merger<E> sinkMerger) {
    Transaction.run((transaction) {
      if (transaction.phase != TransactionPhase.OPENED) {
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

class OptionalEventStream<E> extends EventStream<Optional<E>> {
  OptionalEventStream.never() : super.never();

  OptionalEventStream._(Node<Optional<E>> node) : super._(node);

  @override
  OptionalValueState<E> toState(Optional<E> initValue) =>
      super.toState(initValue).asOptional<E>();

  @override
  OptionalEventStream<EE> asOptional<EE>() =>
      throw StateError('Already optional');

  EventStream<bool> mapIsEmptyOptional() => map((event) => !event.isPresent);

  EventStream<bool> mapIsPresentOptional() => map((event) => event.isPresent);

  EventStream<E> mapWhereOptional() =>
      where((event) => event.isPresent).map((event) => event.value);
}

class _ReferenceListenSubscription extends ListenSubscription {
  Reference _reference;

  _ReferenceListenSubscription(this._reference);

  @override
  void cancel() => _reference.dispose();
}

import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';
import 'package:optional/optional.dart';

import 'listen_subscription.dart';
import 'typedef.dart';
import 'value_state.dart';

Node<E> getEventStreamNode<E>(EventStream<E> stream) => stream._node;

EventStream<E> createEventStream<E>(Node<E> node, [Merger<E> merger]) =>
    EventStream._(node, merger);

OptionalEventStream<E> createOptionalEventStream<E>(Node<Optional<E>> node,
        [Merger<Optional<E>> merger]) =>
    OptionalEventStream._(node, merger);

Merger<E> _defaultMergerFactory<E>() =>
    (E newValue, E oldValue) => throw UnsupportedError(
        '''Can't send more times in the same transaction with the default merger''');

NodeEvaluation<E> _defaultEvaluateHandler<E>(
        Map<dynamic, NodeEvaluation> inputs) =>
    inputs[0];

class EventStreamSink<E> {
  final EventStream<E> stream;
  final Reference<Node<E>> _nodeReference;

  factory EventStreamSink([Merger<E> merger]) =>
      EventStreamSink._(EventStream<E>._(NamedNode<E>(), merger));

  EventStreamSink._(this.stream) : _nodeReference = Reference(stream._node);

  bool get isClosed => _nodeReference.isDisposed;

  void close() => _nodeReference.dispose();

  void send(E event) {
    if (isClosed) {
      throw StateError('Sink is closed');
    }

    stream._setValue(event);
  }
}

class OptionalEventStreamSink<E> extends EventStreamSink<Optional<E>> {
  factory OptionalEventStreamSink([Merger<Optional<E>> merger]) =>
      OptionalEventStreamSink._(
          OptionalEventStream<E>._(NamedNode<Optional<E>>(), merger));

  OptionalEventStreamSink._(OptionalEventStream<E> stream) : super._(stream);

  @override
  OptionalEventStream<E> get stream => super.stream;

  void sendOptionalEmpty() => send(Optional<E>.empty());

  void sendOptionalOf(E event) => send(Optional<E>.of(event));
}

class EventStreamLink<E> {
  final EventStream<E> stream;

  factory EventStreamLink() => Transaction.runRequired((transaction) =>
      EventStreamLink._(EventStream<E>._(transaction
          .node(IndexedNode<E>(evaluateHandler: _defaultEvaluateHandler)))));

  EventStreamLink._(this.stream);

  bool get isLinked => _node.isLinked(0);

  void connect(EventStream<E> stream) => Transaction.runRequired((_) {
        if (isLinked) {
          throw StateError("Reference already linked");
        }

        _node.link(stream._node);
      });

  IndexedNode<E> get _node => stream._node;
}

class OptionalEventStreamLink<E> extends EventStreamLink<Optional<E>> {
  factory OptionalEventStreamLink() =>
      Transaction.runRequired((transaction) => OptionalEventStreamLink._(
          OptionalEventStream<E>._(transaction.node(IndexedNode<Optional<E>>(
              evaluateHandler: _defaultEvaluateHandler)))));

  OptionalEventStreamLink._(OptionalEventStream<E> stream) : super._(stream);

  @override
  OptionalEventStream<E> get stream => super.stream;

  @override
  void connect(covariant OptionalEventStream<E> stream) =>
      super.connect(stream);
}

class EventStream<E> {
  final Node<E> _node;

  final Merger<E> _merger;

  EventStream.never()
      : _node = NamedNode<E>(),
        _merger = null;

  EventStream._(this._node, [Merger<E> merger])
      : _merger = merger ?? _defaultMergerFactory<E>();

  // TODO implementare merges
  static EventStream<E> merges<E>(Iterable<EventStream<E>> streams,
          [Merger<E> merger]) =>
      throw UnimplementedError();

  OptionalEventStream<EE> asOptional<EE>() =>
      Transaction.runRequired((transaction) {
        final targetNode = transaction.node(IndexedNode<Optional<EE>>(
            evaluateHandler: _defaultEvaluateHandler));

        targetNode.link(_node);

        return OptionalEventStream._(targetNode);
      });

  ValueState<E> toState(E initValue) => toStateLazy(LazyValue(initValue));

  ValueState<E> toStateLazy(LazyValue<E> lazyInitValue) =>
      Transaction.runRequired((_) => createValueState(lazyInitValue, this));

  // TODO implementare once
  EventStream<E> once() => throw UnimplementedError();

  EventStream<E> distinct([Equalizer<E> distinctEquals]) =>
      Transaction.runRequired((transaction) {
        var previousEvaluation = NodeEvaluation.not();
        final targetNode = transaction.node(IndexedNode<E>(
          evaluateHandler: (inputs) => previousEvaluation.isNotEvaluated ||
                  inputs[0].value != previousEvaluation.value
              ? inputs[0]
              : NodeEvaluation.not(),
          commitHandler: (value) => previousEvaluation = NodeEvaluation(value),
        ));

        targetNode.link(_node);

        return EventStream._(targetNode);
      });

  EventStream<ER> map<ER>(Mapper<E, ER> mapper) =>
      Transaction.runRequired((transaction) {
        final targetNode = transaction.node(IndexedNode<ER>(
            evaluateHandler: (inputs) =>
                NodeEvaluation<ER>(mapper.call(inputs[0].value))));

        targetNode.link(_node);

        return EventStream._(targetNode);
      });

  EventStream<ER> mapTo<ER>(ER event) => map<ER>((_) => event);

  OptionalEventStream<EE> mapToOptionalEmpty<EE>() =>
      mapTo<Optional<EE>>(Optional<EE>.empty()).asOptional<EE>();

  OptionalEventStream<E> mapToOptionalOf() =>
      map<Optional<E>>((event) => Optional<E>.of(event)).asOptional<E>();

  EventStream<E> where(Filter<E> filter) =>
      Transaction.runRequired((transaction) {
        final targetNode = transaction.node(IndexedNode<E>(
          evaluateHandler: (inputs) =>
              filter(inputs[0].value) ? inputs[0] : NodeEvaluation.not(),
        ));

        targetNode.link(_node);

        return EventStream._(targetNode);
      });

  ValueState<V> accumulate<V>(V initValue, Accumulator<E, V> accumulator) {
    final reference = ValueStateLink<V>();
    reference
        .connect(snapshot(reference.state, accumulator).toState(initValue));
    return reference.state;
  }

  ValueState<V> accumulateLazy<V>(
      LazyValue<V> lazyInitValue, Accumulator<E, V> accumulator) {
    final reference = ValueStateLink<V>();
    reference.connect(
        snapshot(reference.state, accumulator).toStateLazy(lazyInitValue));
    return reference.state;
  }

  EventStream<ER> collect<ER, V>(V initValue, Collector<E, V, ER> collector) {
    final reference = EventStreamLink<V>();
    final stream = snapshot(reference.stream.toState(initValue), collector);
    reference.connect(stream.map((tuple) => tuple.item2));
    return stream.map((tuple) => tuple.item1);
  }

  EventStream<ER> collectLazy<ER, V>(
      LazyValue<V> lazyInitValue, Collector<E, V, ER> collector) {
    final reference = EventStreamLink<V>();
    final stream =
        snapshot(reference.stream.toStateLazy(lazyInitValue), collector);
    reference.connect(stream.map((tuple) => tuple.item2));
    return stream.map((tuple) => tuple.item1);
  }

  EventStream<E> gate(ValueState<bool> conditionState) => snapshot(
          conditionState,
          (event, condition) =>
              condition ? Optional<E>.of(event) : Optional<E>.empty())
      .asOptional<E>()
      .mapWhereOptional();

  EventStream<E> orElse(EventStream<E> stream) => merges<E>([this, stream]);

  EventStream<E> orElses(Iterable<EventStream<E>> streams) =>
      merges<E>([this, ...streams]);

  EventStream<ER> snapshot<V2, ER>(
          ValueState<V2> fromState, Combiner2<E, V2, ER> combiner) =>
      map((event) => combiner(event, fromState.current()));

  ListenSubscription listen(ValueHandler<E> onEvent) =>
      Transaction.run((transaction) {
        final listenNode = IndexedNode<E>(
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

  void _setValue(E event) {
    Transaction.run((transaction) {
      if (transaction.phase != TransactionPhase.OPENED) {
        throw UnsupportedError('''Can't send value in callbacks''');
      }

      if (transaction.hasValue(_node)) {
        transaction.setValue(
            _node, _merger(event, transaction.getValue(_node)));
      } else {
        transaction.setValue(_node, event);
      }
    });
  }
}

class OptionalEventStream<E> extends EventStream<Optional<E>> {
  OptionalEventStream.never() : super.never();

  OptionalEventStream._(Node<Optional<E>> node, [Merger<Optional<E>> merger])
      : super._(node, merger);

  @override
  OptionalValueState<E> toState(Optional<E> initValue) =>
      super.toState(initValue).asOptional<E>();

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

import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';
import 'package:optional/optional.dart';

import 'listen_subscription.dart';
import 'typedef.dart';
import 'value_state.dart';

Merger<E> _defaultMergerFactory<E>() =>
    (E newValue, E oldValue) => throw UnsupportedError(
        '''Can't send more times in the same transaction with the default merger''');

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

// TODO verificare nome reference/link
class EventStreamReference<E> {
  final EventStream<E> stream;

  factory EventStreamReference() =>
      EventStreamReference._(EventStream<E>._(null)); // TODO implementare

  EventStreamReference._(this.stream);

  bool get isLinked => stream._isLinked;

  void link(EventStream<E> stream) => this.stream._link(stream);
}

class OptionalEventStreamReference<E>
    extends EventStreamReference<Optional<E>> {
  factory OptionalEventStreamReference() => OptionalEventStreamReference._(
      OptionalEventStream<E>._(null)); // TODO implementare

  OptionalEventStreamReference._(OptionalEventStream<E> stream)
      : super._(stream);

  @override
  OptionalEventStream<E> get stream => super.stream;

  @override
  void link(covariant OptionalEventStream<E> stream) => super.link(stream);
}

class EventStream<E> {
  final Node<E> _node;

  final Merger<E> _merger;

  EventStream.never()
      : _node = NamedNode<E>(),
        _merger = null;

  EventStream._(this._node, [Merger<E> merger])
      : _merger = merger ?? _defaultMergerFactory<E>();

  // TODO implementare
  static EventStream<E> merges<E>(Iterable<EventStream<E>> streams,
          [Merger<E> merger]) =>
      throw UnimplementedError();

  // TODO implementare
  OptionalEventStream<EE> asOptional<EE>() => throw UnimplementedError();

  // TODO implementare
  ValueState<E> toState(E initValue) => throw UnimplementedError();

  // TODO implementare
  ValueState<E> toStateLazy(Lazy<E> lazyInitValue) =>
      throw UnimplementedError();

  // TODO implementare
  EventStream<E> once() => throw UnimplementedError();

  // TODO implementare
  EventStream<E> distinct([Equalizer<E> distinctEquals]) =>
      throw UnimplementedError();

  EventStream<ER> map<ER>(Mapper<E, ER> mapper) {
    final transaction = Transaction.requiredTransaction;

    final targetNode = transaction.node(IndexedNode<ER>(
        evaluateHandler: (inputs) => NodeEvaluation(mapper.call(inputs[0]))));

    targetNode.link(_node);

    return EventStream._(targetNode);
  }

  EventStream<ER> mapTo<ER>(ER event) => map<ER>((_) => event);

  OptionalEventStream<EE> mapToOptionalEmpty<EE>() =>
      mapTo<Optional<EE>>(Optional<EE>.empty()).asOptional<EE>();

  OptionalEventStream<E> mapToOptionalOf() =>
      map<Optional<E>>((event) => Optional<E>.of(event)).asOptional<E>();

  // TODO implementare
  EventStream<E> where(Filter<E> filter) => throw UnimplementedError();

  ValueState<V> accumulate<V>(V initValue, Accumulator<E, V> accumulator) {
    final reference = ValueStateReference<V>();
    reference.link(snapshot(reference.state, accumulator).toState(initValue));
    return reference.state;
  }

  // TODO implementare
  ValueState<V> accumulateLazy<V>(
          Lazy<V> lazyInitValue, Accumulator<E, V> accumulator) =>
      throw UnimplementedError();

  EventStream<ER> collect<ER, V>(V initValue, Collector<E, V, ER> collector) {
    final reference = EventStreamReference<V>();
    final stream = snapshot(reference.stream.toState(initValue), collector);
    reference.link(stream.map((tuple) => tuple.item2));
    return stream.map((tuple) => tuple.item1);
  }

  // TODO implementare
  EventStream<ER> collectLazy<ER, V>(
          Lazy<V> lazyInitValue, Collector<E, V, ER> collector) =>
      throw UnimplementedError();

  EventStream<E> gate(ValueState<bool> conditionState) => snapshot(
          conditionState,
          (event, condition) =>
              condition ? Optional<E>.of(event) : Optional<E>.empty())
      .asOptional<E>()
      .mapWhereOptional();

  EventStream<E> orElse(EventStream<E> stream) => merges<E>([this, stream]);

  EventStream<E> orElses(Iterable<EventStream<E>> streams) =>
      merges<E>([this, ...streams]);

  // TODO implementare
  EventStream<ER> snapshot<V2, ER>(
          ValueState<V2> fromState, Combiner2<E, V2, ER> combiner) =>
      throw UnimplementedError();

  ListenSubscription listen(OnDataHandler<E> onEvent) =>
      Transaction.run((transaction) {
        final listenNode = IndexedNode<E>(
          evaluateHandler: (inputs) => NodeEvaluation(inputs[0]),
          publishHandler: onEvent,
        );

        final reference = Reference(listenNode);

        listenNode.link(_node);

        return _ReferenceListenSubscription(reference);
      });

  ListenSubscription listenOnce(OnDataHandler<E> onEvent) {
    ListenSubscription listenSubscription;

    listenSubscription = listen((data) {
      listenSubscription.cancel();

      onEvent(data);
    });

    return listenSubscription;
  }

  // TODO implementare
  bool get _isLinked => throw UnimplementedError();

  // TODO implementare
  void _link(EventStream<E> stream) => throw UnimplementedError();

  void _setValue(event) {
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

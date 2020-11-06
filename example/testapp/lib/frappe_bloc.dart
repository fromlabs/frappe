import 'package:frappe/frappe.dart';
import 'package:meta/meta.dart';

abstract class FrappeBloc implements Disposable {
  final _disposableCollector = DisposableCollector();

  FrappeBloc() {
    runTransaction(init);
  }

  @protected
  void init();

  @protected
  EventStreamSink<E> createEventStreamSink<E>([Merger<E>? merger]) =>
      registerEventStreamSink(EventStreamSink<E>(merger));

  @protected
  ValueStateSink<V> createValueStateSink<V>(V initValue, [Merger<V>? merger]) =>
      registerValueStateSink(ValueStateSink<V>(initValue, merger));

  @protected
  EventStreamSink<E> registerEventStreamSink<E>(
      EventStreamSink<E> eventStreamSink) {
    _disposableCollector.add(eventStreamSink.toDisposable());

    return eventStreamSink;
  }

  @protected
  ValueStateSink<V> registerValueStateSink<V>(
      ValueStateSink<V> valueStateSink) {
    _disposableCollector.add(valueStateSink.toDisposable());

    return valueStateSink;
  }

  @protected
  EventStream<E> registerEventStream<E>(EventStream<E> eventStream) {
    _disposableCollector.add(eventStream.toReference());

    return eventStream;
  }

  @protected
  ValueState<V> registerValueState<V>(ValueState<V> valueState) {
    _disposableCollector.add(valueState.toReference());

    return valueState;
  }

  @override
  void dispose() {
    _disposableCollector.dispose();
  }
}

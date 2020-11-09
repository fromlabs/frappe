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

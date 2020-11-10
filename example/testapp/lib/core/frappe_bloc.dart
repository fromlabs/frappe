import 'package:frappe/frappe.dart';
import 'package:meta/meta.dart';

abstract class Bloc {}

abstract class BaseBloc implements Bloc, Disposable {
  final _disposableCollector = DisposableCollector();

  BaseBloc() {
    runTransaction(create);
  }

  @protected
  void create();

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

  @mustCallSuper
  @override
  void dispose() {
    _disposableCollector.dispose();
  }
}

import 'package:frappe/frappe.dart';
import 'package:meta/meta.dart';

abstract class Bloc<S> {
  ValueState<S> get state;
}

abstract class BaseBloc<S> implements Bloc<S>, Disposable {
  late final ValueState<S> _state;

  final _disposableCollector = DisposableCollector();

  BaseBloc() {
    runTransaction(() {
      _state = _registerValueState<S>(create());
    });
  }

  @protected
  ValueState<S> create();

  @protected
  EventStream<E> registerEventStream<E>(EventStream<E> eventStream) {
    _disposableCollector.add(eventStream.toReference());

    return eventStream;
  }

  @mustCallSuper
  @override
  void dispose() {
    _disposableCollector.dispose();
  }

  ValueState<S> get state => _state;

  ValueState<V> _registerValueState<V>(ValueState<V> valueState) {
    _disposableCollector.add(valueState.toReference());

    return valueState;
  }
}

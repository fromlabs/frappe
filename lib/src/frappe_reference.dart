import 'package:frappe/src/disposable.dart';
import 'package:frappe/src/event_stream.dart';
import 'package:frappe/src/frappe_object.dart';
import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';
import 'package:frappe/src/value_state.dart';

extension EventStreamReferenceSupport<E> on EventStream<E> {
  FrappeReference<EventStream<E>> toReference() =>
      FrappeReference._(this, ExtendedEventStream(this).node);
}

extension ValueStateReferenceSupport<V> on ValueState<V> {
  FrappeReference<ValueState<V>> toReference() =>
      FrappeReference._(this, ExtendedValueState(this).node);
}

class FrappeReferenceCollector implements Disposable {
  final _references = <FrappeReference>[];

  FO add<FO extends FrappeObject>(FO frappeObject) {
    if (frappeObject is EventStream) {
      _references.add(frappeObject.toReference());
    } else if (frappeObject is ValueState) {
      _references.add(frappeObject.toReference());
    } else {
      throw UnsupportedError('Frappe object of ${frappeObject.runtimeType}');
    }

    return frappeObject;
  }

  @override
  void dispose() {
    for (final reference in _references.reversed) {
      reference.dispose();
    }
  }
}

class FrappeReference<FO extends FrappeObject> implements Disposable {
  final FO object;

  final Reference<Node> _reference;

  FrappeReference._(this.object, Node node) : _reference = Reference(node);

  bool get isDisposed => _reference.isDisposed;

  @override
  void dispose() => _reference.dispose();
}

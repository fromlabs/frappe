import 'package:frappe/src/disposable.dart';
import 'package:frappe/src/frappe_object.dart';
import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';

class FrappeReferenceCollector implements Disposable {
  final _references = <FrappeReference>[];

  FO add<FO extends FrappeObject>(FO frappeObject) {
    _references.add(frappeObject.toReference());
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

  FrappeReference(this.object) : _reference = Reference(object.node);

  bool get isDisposed => _reference.isDisposed;

  @override
  void dispose() => _reference.dispose();
}

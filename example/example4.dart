import 'package:frappe/frappe.dart';

void main() {
  final disposableCollector = DisposableCollector();

  //

  disposableCollector.dispose();

  // assert that all listeners are canceled
  FrappeObject.assertCleanState();
}

// business logic component
class Bloc implements Disposable {
  final _disposableCollector = DisposableCollector();

  Bloc() {
    runTransaction(() {
      //
    });
  }

  @override
  void dispose() {
    _disposableCollector.dispose();
  }
}

// functional logic unit
class Flut {}

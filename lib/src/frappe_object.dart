import 'package:frappe/src/event_stream.dart';
import 'package:frappe/src/frappe_reference.dart';
import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';
import 'package:frappe/src/value_state.dart';

extension ExtendedFrappeObject<T> on FrappeObject<T> {
  Node<T> get node {
    final frappeObject = this;

    if (frappeObject is EventStream<T>) {
      return ExtendedEventStream(frappeObject).node;
    } else if (frappeObject is ValueState<T>) {
      return ExtendedValueState(frappeObject).node;
    } else {
      throw UnsupportedError('Frappe object of ${frappeObject.runtimeType}');
    }
  }
}

abstract class FrappeObject<T> {
  static void cleanState() {
    Transaction.cleanState();
    Node.cleanState();
    Reference.cleanState();
  }

  static void assertCleanState() {
    Transaction.assertCleanState();
    Node.assertCleanState();
    Reference.assertCleanState();
  }

  FrappeReference<FrappeObject<T>> toReference();
}

import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';

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
}

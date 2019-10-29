import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';

void assertCleanup() {
  assertAllNodesUnlinked();

  assertAllUnreferenced();
}

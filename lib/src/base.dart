import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';

void cleanUp() {
  cleanAllNodesUnlinked();

  cleanAllUnreferenced();
}

void assertCleanup() {
  assertAllNodesUnlinked();

  assertAllUnreferenced();
}

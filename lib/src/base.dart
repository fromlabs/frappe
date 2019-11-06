import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';

void cleanUp() {
  cleanAllNodesUnlinked();
  cleanAllListenNodes();
  cleanAllUnreferenced();
}

void assertCleanup() {
  assertAllNodesUnlinked();
  assertAllListenNodes();
  assertAllUnreferenced();
}

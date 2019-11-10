import 'node.dart';
import 'reference.dart';

void cleanUp() {
  Node.cleanAllNodesUnlinked();
  cleanAllListenNodes();
  cleanAllUnreferenced();
}

void assertCleanup() {
  Node.assertAllNodesUnlinked();
  assertAllListenNodes();
  assertAllUnreferenced();
}

import 'node.dart';
import 'reference.dart';

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

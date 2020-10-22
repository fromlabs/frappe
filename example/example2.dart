import 'package:frappe/frappe.dart';
import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';

void main() {
  late final Reference<KeyNode<int>> node1Ref;
  late final Reference<KeyNode<int>> node2Ref;

  Transaction.run((tx) {
    final node1 = KeyNode<int>(debugLabel: 'INPUT');
    final node2 = KeyNode<int>(
        debugLabel: 'DUPLIFY',
        evaluateHandler: (inputs) =>
            NodeEvaluation(2 * inputs.evaluation.value as int));

    node2.link(node1);

    node1Ref = Reference(node1);
    node2Ref = Reference(node2);
  });

  Transaction.run((tx) {
    tx.setValue(node1Ref.value, 1);
  });

  node1Ref.dispose();
  node2Ref.dispose();

  // assert that all listeners are canceled
  FrappeObject.assertCleanState();
}

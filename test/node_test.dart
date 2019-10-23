import 'package:frappe/src/node.dart';
import 'package:test/test.dart';

void main() {
  test('Node dependencies OK', () {
    Transaction.run((tx) {
      final node1 = IndexedNode<int>(tx);
      final node2 = IndexedNode<int>(tx);
      final node3 = IndexedNode<int>(tx);

      node3.link(
          node1, tx); // TODO errore se node3 non referenziato in qualche modo
      node3.link(
          node2, tx); // TODO errore se node3 non referenziato in qualche modo

      // final node3Ref = NodeReference(node3);

      // node3Ref.unset();
    });
  });

  test('Node dependencies KO', () {
    Transaction.run((tx) {
      final node1 = IndexedNode<int>(tx);
      final node2 = IndexedNode<int>(tx);
      final node3 = IndexedNode<int>(tx);

      node1.link(node2, tx);
      node2.link(node3, tx);
      node3.link(node1, tx);
    });
  });

  test('Node reference OK', () {
    Transaction.run((tx) {
      final node1 = IndexedNode<int>(tx);
      final node2 = IndexedNode<int>(tx);

      node2.link(
          node1, tx); // TODO errore se node2 non referenziato in qualche modo
    });
  });

  test('Node reference KO', () {
    Transaction.run((tx) {
      final node1 = IndexedNode<int>(tx);
      final node2 = IndexedNode<int>(tx);
      final node3 = IndexedNode<int>(tx);

      // final node3Ref = NodeReference(node3);

      node3.link(node1, tx);
      node3.link(node2, tx);

      // node3Ref.unset();
    });
  });
}

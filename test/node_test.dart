import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    assertAllUnreferenced();
    assertAllNodesUnlinked();
  });

  test('Node test 1', () {
    IndexedNode<int> node1;
    IndexedNode<int> node2;

    Transaction.run((tx) {
      node1 = tx.node(IndexedNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexedNode<int>(debugLabel: 'N2'));

      expect(node1.isReferenced, true);
      expect(node2.isReferenced, true);
    });

    expect(node1.isReferenced, false);
    expect(node2.isReferenced, false);

    Transaction.run((tx) {
      expect(node1.isReferenced, false);
      expect(node2.isReferenced, false);

      expect(() => node1.link(node2), throwsArgumentError);
    });
  });

  test('Node test 2', () {
    IndexedNode<int> node1;
    IndexedNode<int> node2;
    IndexedNode<int> node3;

    Transaction.run((tx) {
      node1 = tx.node(IndexedNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexedNode<int>(debugLabel: 'N2'));
      node3 = tx.node(IndexedNode<int>(debugLabel: 'N3'));

      node3.link(node1);
      node3.link(node2);
    });
  });

  test('Node test 3', () {
    IndexedNode<int> node1;
    IndexedNode<int> node2;
    IndexedNode<int> node3;

    Transaction.run((tx) {
      node1 = tx.node(IndexedNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexedNode<int>(debugLabel: 'N2'));
      node3 = tx.node(IndexedNode<int>(debugLabel: 'N3'));

      node1.link(node2);
      node2.link(node3);

      expect(() => node3.link(node1), throwsArgumentError);
    });
  });

  test('Node test 4', () {
    IndexedNode<int> node1;
    IndexedNode<int> node2;

    Transaction.run((tx) {
      node1 = tx.node(IndexedNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexedNode<int>(debugLabel: 'N2'));

      node2.link(node1);
    });
  });

  test('Node test 5', () {
    IndexedNode<int> node1;
    IndexedNode<int> node2;
    IndexedNode<int> node3;
    Reference<IndexedNode<int>> node3Ref;

    Transaction.run((tx) {
      node1 = tx.node(IndexedNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexedNode<int>(debugLabel: 'N2'));
      node3 = tx.node(IndexedNode<int>(debugLabel: 'N3'));

      expect(node1.isReferenced, true);
      expect(node2.isReferenced, true);
      expect(node3.isReferenced, true);

      node3.link(node1);
      node3.link(node2);

      expect(node1.isReferenced, true);
      expect(node2.isReferenced, true);
      expect(node3.isReferenced, true);

      node3Ref = Reference(node3);
    });

    expect(node1.isReferenced, true);
    expect(node2.isReferenced, true);
    expect(node3.isReferenced, true);

    node3Ref.dispose();

    expect(node1.isReferenced, false);
    expect(node2.isReferenced, false);
    expect(node3.isReferenced, false);
  });

  test('Node test 6', () {
    IndexedNode<int> node1;
    IndexedNode<int> node2;
    Reference<IndexedNode<int>> node2Ref;

    Transaction.run((tx) {
      node1 = tx.node(IndexedNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexedNode<int>(debugLabel: 'N2'));
      node2Ref = Reference(node2);
    });

    node2.link(node1);

    node2Ref.dispose();
  });

  test('Node test 7', () {
    IndexedNode<int> node1;
    IndexedNode<int> node2;
    Reference<IndexedNode<int>> node2Ref;

    Transaction.run((tx) {
      node1 = tx.node(IndexedNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexedNode<int>(debugLabel: 'N2'));
      node2Ref = Reference(node2);
    });

    node2Ref.dispose();

    expect(() => node2.link(node1), throwsArgumentError);
  });

  test('Node test 8', () {
    Reference<IndexedNode<int>> node1Ref;
    Reference<IndexedNode<int>> node2Ref;

    // TODO possibilità di registrare un handler evaluate sul nodo
    // TODO possibilità di registrare un handler onTransactionBegin sul nodo

    Transaction.run((tx) {
      final node1 = tx.node(IndexedNode<int>(debugLabel: 'INPUT'));
      final node2 = tx.node(IndexedNode<int>(
          debugLabel: 'DUPLIFY', evaluate: (inputs) => 2 * inputs[0]));

      node2.link(node1);

      node1Ref = Reference(node1);
      node2Ref = Reference(node2);
    });

    Transaction.run((tx) {
      tx.setEvaluation(node1Ref.value, 1);
    });

    node1Ref.dispose();
    node2Ref.dispose();
  });

  test('Node test 9', () {
    IndexedNode<int> node1;
    IndexedNode<int> node2;
    Reference<IndexedNode<int>> node2Ref;

    Transaction.run((tx) {
      node1 = tx.node(IndexedNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexedNode<int>(debugLabel: 'N2'));

      expect(node1.isReferenced, true);
      expect(node2.isReferenced, true);

      node2.link(node1);

      node2Ref = Reference(node2);
    });

    expect(node1.isReferenced, true);
    expect(node2.isReferenced, true);

    Reference<IndexedNode<int>> node2bRef;
    Transaction.run((tx) {
      expect(node1.isReferenced, true);
      expect(node2.isReferenced, true);

      tx.node(node2);
      node2Ref.dispose();
      node2bRef = Reference(node2);
    });

    expect(node1.isReferenced, true);
    expect(node2.isReferenced, true);

    node2bRef.dispose();
  });
}

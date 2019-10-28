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

    Transaction.run((tx) {
      expect(node1.isReferenced, true);
      expect(node2.isReferenced, true);

      node2bRef.dispose();

      tx.node(node2);

      expect(node1.isReferenced, false);
      expect(node2.isReferenced, true);

      expect(() => node2.link(node1), throwsStateError);
    });

    expect(node1.isReferenced, false);
    expect(node2.isReferenced, false);
  });

  test('Node evaluation test 1', () {
    Reference<IndexedNode<int>> node1Ref;
    Reference<IndexedNode<int>> node2Ref;

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

  test('Node evaluation test 2', () {
    Reference<IndexedNode<int>> input1Ref;
    Reference<IndexedNode<int>> input2Ref;
    Reference<IndexedNode<int>> input3Ref;
    Reference<IndexedNode<int>> merge1Ref;

    Transaction.run((tx) {
      final input1 = tx.node(IndexedNode<int>(debugLabel: 'INPUT1'));
      final input2 = tx.node(IndexedNode<int>(debugLabel: 'INPUT2'));
      final input3 = tx.node(IndexedNode<int>(debugLabel: 'INPUT3'));

      final node21 = tx.node(IndexedNode<int>(
          debugLabel: 'DUPLIFY1', evaluate: (inputs) => 2 * inputs[0]))
        ..link(input1);

      final node22 = tx.node(IndexedNode<int>(
          debugLabel: 'TRIPLIFY2', evaluate: (inputs) => 3 * inputs[0]))
        ..link(input2);

      final merge2 = tx.node(IndexedNode<int>(
          debugLabel: 'MERGE2',
          canEvaluatePartially: true,
          evaluate: (inputs) => inputs.containsKey(0)
              ? inputs[0]
              : (inputs.containsKey(1)
                  ? inputs[1]
                  : throw StateError('Node not evaluated'))))
        ..link(input3)
        ..link(node22);

      final node32 = tx.node(IndexedNode<int>(
          debugLabel: 'TRIPLIFY3', evaluate: (inputs) => 3 * inputs[0]))
        ..link(merge2);

      final merge1 = tx.node(IndexedNode<int>(
          debugLabel: 'MERGE1',
          canEvaluatePartially: true,
          evaluate: (inputs) => inputs.containsKey(0)
              ? inputs[0]
              : (inputs.containsKey(1)
                  ? inputs[1]
                  : throw StateError('Node not evaluated'))))
        ..link(node32)
        ..link(node21);

      final listen1 = tx.node(IndexedNode<int>(
          debugLabel: 'LISTEN1',
          evaluate: (inputs) => inputs.containsKey(0)
              ? inputs[0]
              : (inputs.containsKey(1)
                  ? inputs[1]
                  : throw StateError('Node not evaluated'))))
        ..link(merge1);

      input1Ref = Reference(input1);
      input2Ref = Reference(input2);
      input3Ref = Reference(input3);
      merge1Ref = Reference(merge1);
    });

    Transaction.run((tx) {
      tx.setEvaluation(input1Ref.value, 1);
      tx.setEvaluation(input2Ref.value, 1);
    });

    input1Ref.dispose();
    input2Ref.dispose();
    input3Ref.dispose();
    merge1Ref.dispose();
  });
}

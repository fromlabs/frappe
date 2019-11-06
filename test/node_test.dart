import 'dart:collection';

import 'package:frappe/frappe.dart';
import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';
import 'package:frappe/src/node/node_evaluation.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    cleanUp();
  });

  tearDown(() {
    assertCleanup();
  });

  test('Node test 1', () {
    IndexNode<int> node1;
    IndexNode<int> node2;

    Transaction.run((tx) {
      node1 = tx.node(IndexNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexNode<int>(debugLabel: 'N2'));

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
    IndexNode<int> node1;
    IndexNode<int> node2;
    IndexNode<int> node3;

    Transaction.run((tx) {
      node1 = tx.node(IndexNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexNode<int>(debugLabel: 'N2'));
      node3 = tx.node(IndexNode<int>(debugLabel: 'N3'));

      node3.link(node1);
      node3.link(node2);
    });
  });

  test('Node test 3', () {
    IndexNode<int> node1;
    IndexNode<int> node2;
    IndexNode<int> node3;

    Transaction.run((tx) {
      node1 = tx.node(IndexNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexNode<int>(debugLabel: 'N2'));
      node3 = tx.node(IndexNode<int>(debugLabel: 'N3'));

      node1.link(node2);
      node2.link(node3);

      expect(() => node3.link(node1), throwsArgumentError);
    });
  });

  test('Node test 4', () {
    IndexNode<int> node1;
    IndexNode<int> node2;

    Transaction.run((tx) {
      node1 = tx.node(IndexNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexNode<int>(debugLabel: 'N2'));

      node2.link(node1);
    });
  });

  test('Node test 4b', () {
    IndexNode<int> node1 = IndexNode<int>(debugLabel: 'N1');
    IndexNode<int> node2;

    Transaction.run((tx) {
      node2 = tx.node(IndexNode<int>(debugLabel: 'N2'));

      node2.link(node1);
    });
  });

  test('Node test 4c', () {
    IndexNode<int> node1;
    IndexNode<int> node2 = IndexNode<int>(debugLabel: 'N2');

    Transaction.run((tx) {
      node1 = tx.node(IndexNode<int>(debugLabel: 'N1'));

      expect(() => node2.link(node1), throwsArgumentError);
    });
  });

  test('Node test 5', () {
    IndexNode<int> node1;
    IndexNode<int> node2;
    IndexNode<int> node3;
    Reference<IndexNode<int>> node3Ref;

    Transaction.run((tx) {
      node1 = tx.node(IndexNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexNode<int>(debugLabel: 'N2'));
      node3 = tx.node(IndexNode<int>(debugLabel: 'N3'));

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
    IndexNode<int> node1;
    IndexNode<int> node2;
    Reference<IndexNode<int>> node2Ref;

    Transaction.run((tx) {
      node1 = tx.node(IndexNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexNode<int>(debugLabel: 'N2'));
      node2Ref = Reference(node2);
    });

    node2.link(node1);

    node2Ref.dispose();
  });

  test('Node test 7', () {
    IndexNode<int> node1;
    IndexNode<int> node2;
    Reference<IndexNode<int>> node2Ref;

    Transaction.run((tx) {
      node1 = tx.node(IndexNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexNode<int>(debugLabel: 'N2'));
      node2Ref = Reference(node2);
    });

    node2Ref.dispose();

    expect(() => node2.link(node1), throwsArgumentError);
  });

  test('Node test 8', () {
    IndexNode<int> node1;
    IndexNode<int> node2;
    Reference<IndexNode<int>> node2Ref;

    Transaction.run((tx) {
      node1 = tx.node(IndexNode<int>(debugLabel: 'N1'));
      node2 = tx.node(IndexNode<int>(debugLabel: 'N2'));

      expect(node1.isReferenced, true);
      expect(node2.isReferenced, true);

      node2.link(node1);

      node2Ref = Reference(node2);
    });

    expect(node1.isReferenced, true);
    expect(node2.isReferenced, true);

    Reference<IndexNode<int>> node2bRef;
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
    Reference<IndexNode<int>> node1Ref;
    Reference<IndexNode<int>> node2Ref;

    Transaction.run((tx) {
      final node1 = tx.node(IndexNode<int>(debugLabel: 'INPUT'));
      final node2 = tx.node(IndexNode<int>(
          debugLabel: 'DUPLIFY',
          evaluateHandler: (inputs) => NodeEvaluation(2 * inputs[0].value)));

      node2.link(node1);

      node1Ref = Reference(node1);
      node2Ref = Reference(node2);
    });

    Transaction.run((tx) {
      tx.setValue(node1Ref.value, 1);
    });

    node1Ref.dispose();
    node2Ref.dispose();
  });

  test('Node evaluation test 2', () {
    Reference<IndexNode<int>> input1Ref;
    Reference<IndexNode<int>> input2Ref;
    Reference<IndexNode<int>> input3Ref;
    Reference<IndexNode<int>> merge1Ref;
    Reference<IndexNode<int>> listenRef;

    final commits = Queue<int>();
    final publishs = Queue<int>();

    Transaction.run((tx) {
      final input1 = tx.node(IndexNode<int>(debugLabel: 'INPUT1'));
      final input2 = tx.node(IndexNode<int>(debugLabel: 'INPUT2'));
      final input3 = tx.node(IndexNode<int>(debugLabel: 'INPUT3'));

      final node21 = tx.node(IndexNode<int>(
          debugLabel: 'DUPLIFY1',
          evaluateHandler: (inputs) => NodeEvaluation(2 * inputs[0].value)))
        ..link(input1);

      final node22 = tx.node(IndexNode<int>(
          debugLabel: 'TRIPLIFY2',
          evaluateHandler: (inputs) => NodeEvaluation(3 * inputs[0].value)))
        ..link(input2);

      final merge2 = tx.node(IndexNode<int>(
        debugLabel: 'MERGE2',
        evaluationType: EvaluationType.ALMOST_ONE_INPUT,
        evaluateHandler: (inputs) =>
            inputs[0].isEvaluated ? inputs[0] : inputs[1],
      ))
        ..link(input3)
        ..link(node22);

      final node32 = tx.node(IndexNode<int>(
          debugLabel: 'TRIPLIFY3',
          evaluateHandler: (inputs) => NodeEvaluation(3 * inputs[0].value)))
        ..link(merge2);

      // ignore: unused_local_variable
      int merge1Value = 1;
      final merge1 = tx.node(IndexNode<int>(
        debugLabel: 'MERGE1',
        evaluationType: EvaluationType.ALMOST_ONE_INPUT,
        evaluateHandler: (inputs) =>
            inputs[0].isEvaluated ? inputs[0] : inputs[1],
        commitHandler: (value) => merge1Value = value,
      ))
        ..link(node32)
        ..link(node21);

      var previousEvaluation = NodeEvaluation.not();
      final distinct = tx.node(IndexNode<int>(
        debugLabel: 'DISTINCT',
        evaluateHandler: (inputs) => previousEvaluation.isNotEvaluated ||
                inputs[0].value != previousEvaluation.value
            ? inputs[0]
            : NodeEvaluation.not(),
        commitHandler: (value) => previousEvaluation = NodeEvaluation(value),
      ))
        ..link(merge1);

      final listen = tx.node(IndexNode<int>(
        debugLabel: 'LISTEN',
        evaluateHandler: (inputs) => inputs[0],
        commitHandler: commits.add,
        publishHandler: publishs.add,
      ))
        ..link(distinct);

      input1Ref = Reference(input1);
      input2Ref = Reference(input2);
      input3Ref = Reference(input3);
      merge1Ref = Reference(merge1);
      listenRef = Reference(listen);
    });

    expect(commits, isEmpty);
    expect(publishs, isEmpty);

    Transaction.run((tx) {
      tx.setValue(input1Ref.value, 1);
      tx.setValue(input2Ref.value, 1);
    });

    expect(commits, isNotEmpty);
    expect(commits.removeLast(), equals(9));
    expect(commits, isEmpty);
    expect(publishs, isNotEmpty);
    expect(publishs.removeLast(), equals(9));
    expect(publishs, isEmpty);

    Transaction.run((tx) {
      tx.setValue(input1Ref.value, 1);
      tx.setValue(input2Ref.value, 2);
    });

    expect(commits, isNotEmpty);
    expect(commits.removeLast(), equals(18));
    expect(commits, isEmpty);
    expect(publishs, isNotEmpty);
    expect(publishs.removeLast(), equals(18));
    expect(publishs, isEmpty);

    Transaction.run((tx) {
      tx.setValue(input1Ref.value, 1);
      tx.setValue(input2Ref.value, 2);
    });

    expect(commits, isEmpty);
    expect(publishs, isEmpty);

    expect(
        () => Transaction.run((tx) {
              tx.setValue(input1Ref.value, 1);
              if (!tx.hasValue(input1Ref.value)) {
                tx.setValue(input1Ref.value, 2);
              } else {
                throw UnsupportedError('Node already with a value');
              }
            }),
        throwsUnsupportedError);

    input1Ref.dispose();
    input2Ref.dispose();
    input3Ref.dispose();
    merge1Ref.dispose();
    listenRef.dispose();
  });
}

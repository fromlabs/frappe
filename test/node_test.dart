import 'dart:collection';

import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    Transaction.cleanState();
    Node.cleanState();
    Reference.cleanState();
  });

  tearDown(() {
    Transaction.assertCleanState();
    Node.assertCleanState();
    Reference.assertCleanState();
  });

  test('Node test 1', () {
    late final KeyNode<int> node1;
    late final KeyNode<int> node2;

    Transaction.run((tx) {
      node1 = KeyNode<int>(debugLabel: 'N1');
      node2 = KeyNode<int>(debugLabel: 'N2');

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
    late final KeyNode<int> node1;
    late final KeyNode<int> node2;
    late final KeyNode<int> node3;

    Transaction.run((tx) {
      node1 = KeyNode<int>(debugLabel: 'N1');
      node2 = KeyNode<int>(debugLabel: 'N2');
      node3 = KeyNode<int>(debugLabel: 'N3');

      node3.link(node1, key: 0);
      node3.link(node2, key: 1);
    });
  });

  test('Node test 3', () {
    late final KeyNode<int> node1;
    late final KeyNode<int> node2;
    late final KeyNode<int> node3;

    Transaction.run((tx) {
      node1 = KeyNode<int>(debugLabel: 'N1');
      node2 = KeyNode<int>(debugLabel: 'N2');
      node3 = KeyNode<int>(debugLabel: 'N3');

      node1.link(node2, key: 0);
      node2.link(node3, key: 1);

      expect(() => node3.link(node1, key: 2), throwsArgumentError);
    });
  });

  test('Node test 4', () {
    late final KeyNode<int> node1;
    late final KeyNode<int> node2;

    Transaction.run((tx) {
      node1 = KeyNode<int>(debugLabel: 'N1');
      node2 = KeyNode<int>(debugLabel: 'N2');

      node2.link(node1);
    });
  });

  test('Node test 4b', () {
    final node1 = Transaction.run((_) => KeyNode<int>(debugLabel: 'N1'));

    late final KeyNode<int> node2;

    Transaction.run((tx) {
      node2 = KeyNode<int>(debugLabel: 'N2');

      expect(() => node2.link(node1), throwsArgumentError);
    });
  });

  test('Node test 4c', () {
    late final KeyNode<int> node1;

    final node2 = Transaction.run((_) => KeyNode<int>(debugLabel: 'N2'));

    Transaction.run((tx) {
      node1 = KeyNode<int>(debugLabel: 'N1');

      expect(() => node2.link(node1), throwsArgumentError);
    });
  });

  test('Node test 5', () {
    late final KeyNode<int> node1;
    late final KeyNode<int> node2;
    late final KeyNode<int> node3;
    late final Reference<KeyNode<int>> node3Ref;

    Transaction.run((tx) {
      node1 = KeyNode<int>(debugLabel: 'N1');
      node2 = KeyNode<int>(debugLabel: 'N2');
      node3 = KeyNode<int>(debugLabel: 'N3');

      expect(node1.isReferenced, true);
      expect(node2.isReferenced, true);
      expect(node3.isReferenced, true);

      node3.link(node1, key: 0);
      node3.link(node2, key: 1);

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
    late final KeyNode<int> node1;
    late final KeyNode<int> node2;
    late final Reference<KeyNode<int>> node2Ref;

    Transaction.run((tx) {
      node1 = KeyNode<int>(debugLabel: 'N1');
      node2 = KeyNode<int>(debugLabel: 'N2');
      node2Ref = Reference(node2);
    });

    expect(() => node2.link(node1), throwsArgumentError);

    node2Ref.dispose();
  });

  test('Node test 7', () {
    late final KeyNode<int> node1;
    late final KeyNode<int> node2;
    late final Reference<KeyNode<int>> node2Ref;

    Transaction.run((tx) {
      node1 = KeyNode<int>(debugLabel: 'N1');
      node2 = KeyNode<int>(debugLabel: 'N2');
      node2Ref = Reference(node2);
    });

    node2Ref.dispose();

    expect(() => node2.link(node1), throwsArgumentError);
  });

  test('Node test 8', () {
    late final KeyNode<int> node1;
    late final KeyNode<int> node2;
    late final Reference<KeyNode<int>> node2Ref;

    Transaction.run((tx) {
      node1 = KeyNode<int>(debugLabel: 'N1');
      node2 = KeyNode<int>(debugLabel: 'N2');

      expect(node1.isReferenced, true);
      expect(node2.isReferenced, true);

      node2.link(node1);

      node2Ref = Reference(node2);
    });

    expect(node1.isReferenced, true);
    expect(node2.isReferenced, true);

    late final Reference<KeyNode<int>> node2bRef;
    Transaction.run((tx) {
      expect(node1.isReferenced, true);
      expect(node2.isReferenced, true);

      node2bRef = Reference(node2);

      node2Ref.dispose();
    });

    expect(node1.isReferenced, true);
    expect(node2.isReferenced, true);

    Transaction.run((tx) {
      expect(node1.isReferenced, true);
      expect(node2.isReferenced, true);

      node2bRef.dispose();

      expect(node1.isReferenced, true);
      expect(node2.isReferenced, true);
    });

    expect(node1.isReferenced, false);
    expect(node2.isReferenced, false);
  });

  test('Node test 9', () {
    late final KeyNode<int> node1;
    late final KeyNode<int> node2;
    late final KeyNode<int> node3;
    late final Reference<KeyNode<int>> node3Ref;

    Transaction.run((tx) {
      node1 = KeyNode<int>(debugLabel: 'N1');
      node2 = KeyNode<int>(debugLabel: 'N2');
      node3 = KeyNode<int>(debugLabel: 'N3');

      node2.link(node1);
      node3.link(node2);

      node3Ref = Reference(node3);
    });

    Transaction.run((tx) {
      final oldRef = node3Ref;

      node3Ref = Reference(node3);

      oldRef.dispose();
    });

    Transaction.run((tx) {
      final oldRef = node3Ref;

      oldRef.dispose();

      node3Ref = Reference(node3);
    });

    Transaction.run((tx) {
      final oldRef = node3Ref;

      oldRef.dispose();

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

  test('Node evaluation test 1', () {
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
  });

  test('Node evaluation test 2', () {
    late final Reference<KeyNode<int>> input1Ref;
    late final Reference<KeyNode<int>> input2Ref;
    late final Reference<KeyNode<int>> input3Ref;
    late final Reference<KeyNode<int>> merge1Ref;
    late final Reference<KeyNode<int>> listenRef;

    final commits = Queue<int>();
    final publishs = Queue<int>();

    Transaction.run((tx) {
      final input1 = KeyNode<int>(debugLabel: 'INPUT1');
      final input2 = KeyNode<int>(debugLabel: 'INPUT2');
      final input3 = KeyNode<int>(debugLabel: 'INPUT3');

      final node21 = KeyNode<int>(
          debugLabel: 'DUPLIFY1',
          evaluateHandler: (inputs) =>
              NodeEvaluation(2 * inputs.evaluation.value as int))
        ..link(input1);

      final node22 = KeyNode<int>(
          debugLabel: 'TRIPLIFY2',
          evaluateHandler: (inputs) =>
              NodeEvaluation(3 * inputs.evaluation.value as int))
        ..link(input2);

      final merge2 = KeyNode<int>(
        debugLabel: 'MERGE2',
        evaluationType: EvaluationType.almostOneInput,
        evaluateHandler: (inputs) => (inputs[0].isEvaluated
            ? inputs[0]
            : inputs[1]) as NodeEvaluation<int>,
      )
        ..link(input3, key: 0)
        ..link(node22, key: 1);

      final node32 = KeyNode<int>(
          debugLabel: 'TRIPLIFY3',
          evaluateHandler: (inputs) =>
              NodeEvaluation(3 * inputs.evaluation.value as int))
        ..link(merge2);

      // ignore: unused_local_variable
      var merge1Value = 1;
      final merge1 = KeyNode<int>(
        debugLabel: 'MERGE1',
        evaluationType: EvaluationType.almostOneInput,
        evaluateHandler: (inputs) => (inputs[0].isEvaluated
            ? inputs[0]
            : inputs[1]) as NodeEvaluation<int>,
        commitHandler: (value) => merge1Value = value,
      )
        ..link(node32, key: 0)
        ..link(node21, key: 1);

      var previousEvaluation = NodeEvaluation.not();
      final distinct = KeyNode<int>(
        debugLabel: 'DISTINCT',
        evaluateHandler: (inputs) => (previousEvaluation.isNotEvaluated ||
                inputs.evaluation.value != previousEvaluation.value
            ? inputs.evaluation
            : NodeEvaluation.not()) as NodeEvaluation<int>,
        commitHandler: (value) => previousEvaluation = NodeEvaluation(value),
      )..link(merge1);

      final listen = KeyNode<int>(
        debugLabel: 'LISTEN',
        evaluateHandler: (inputs) => inputs.evaluation as NodeEvaluation<int>,
        commitHandler: commits.add,
        publishHandler: publishs.add,
      )..link(distinct);

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

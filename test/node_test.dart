import 'package:frappe/frappe.dart';
import 'package:frappe/src/node.dart';
import 'package:frappe/src/node_evaluation.dart';
import 'package:frappe/src/reference.dart';
import 'package:frappe/src/transaction.dart' show Transaction;
import 'package:test/test.dart';

void main() {
  late ReactiveScope scope;

  setUp(() {
    scope = ReactiveScope();
  });

  tearDown(() {
    scope.run(() => scope.assertCleanState());
    scope.dispose();
  });

  group('Node lifecycle', () {
    test('node is referenced during transaction', () {
      scope.run(() {
        scope.runTransaction(() {
          final node = KeyNode<int>(evaluationType: EvaluationType.never);
          expect(node.isReferenced, isTrue);
        });
      });
    });

    test('node becomes unreferenced after transaction without external ref', () {
      scope.run(() {
        late KeyNode<int> node;

        scope.runTransaction(() {
          node = KeyNode<int>(evaluationType: EvaluationType.never);
        });

        expect(node.isReferenced, isFalse);
      });
    });

    test('node stays referenced with external reference', () {
      scope.run(() {
        late KeyNode<int> node;
        late Reference<KeyNode<int>> ref;

        scope.runTransaction(() {
          node = KeyNode<int>(evaluationType: EvaluationType.never);
          ref = Reference(node);
        });

        expect(node.isReferenced, isTrue);

        ref.dispose();
        expect(node.isReferenced, isFalse);
      });
    });
  });

  group('Node linking', () {
    test('link two nodes', () {
      scope.run(() {
        scope.runTransaction(() {
          final source = KeyNode<int>(evaluationType: EvaluationType.never);
          final target = KeyNode<int>(evaluateHandler: (inputs) => inputs.get<int>());

          target.link(source);

          expect(target.isLinked, isTrue);
        });
      });
    });

    test('link unreferenced target throws', () {
      scope.run(() {
        late KeyNode<int> target;
        late KeyNode<int> source;
        late Reference<KeyNode<int>> sourceRef;

        scope.runTransaction(() {
          target = KeyNode<int>(evaluationType: EvaluationType.never);
        });

        // target is now unreferenced
        scope.runTransaction(() {
          source = KeyNode<int>(evaluationType: EvaluationType.never);
          sourceRef = Reference(source);
        });

        expect(() {
          scope.runTransaction(() {
            target.link(source);
          });
        }, throwsArgumentError);

        sourceRef.dispose();
      });
    });

    test('link unreferenced source throws', () {
      scope.run(() {
        late KeyNode<int> source;

        scope.runTransaction(() {
          source = KeyNode<int>(evaluationType: EvaluationType.never);
        });

        // source is now unreferenced
        scope.runTransaction(() {
          final target = KeyNode<int>(evaluateHandler: (inputs) => inputs.get<int>());
          final ref = Reference(target);

          expect(() => target.link(source), throwsArgumentError);

          ref.dispose();
        });
      });
    });

    test('cycle detection throws', () {
      scope.run(() {
        expect(() {
          scope.runTransaction(() {
            final n1 = KeyNode<int>(evaluateHandler: (inputs) => inputs.get<int>());
            final n2 = KeyNode<int>(evaluateHandler: (inputs) => inputs.get<int>());
            final n3 = KeyNode<int>(evaluateHandler: (inputs) => inputs.get<int>());

            n2.link(n1);
            n3.link(n2);
            n1.link(n3); // Cycle!
          });
        }, throwsArgumentError);
      });
    });

    test('multiple inputs via key', () {
      scope.run(() {
        scope.runTransaction(() {
          final source1 = KeyNode<int>(evaluationType: EvaluationType.never);
          final source2 = KeyNode<int>(evaluationType: EvaluationType.never);
          final target = KeyNode<int>(
            evaluationType: EvaluationType.allInputs,
            evaluateHandler: (inputs) {
              final v1 = inputs.get<int>('a');
              final v2 = inputs.get<int>('b');
              if (v1.isEvaluated && v2.isEvaluated) {
                return NodeEvaluation(v1.value + v2.value);
              }
              return NodeEvaluation.not();
            },
          );

          target.link(source1, key: 'a');
          target.link(source2, key: 'b');

          expect(target.isLinked, isTrue);
          expect(target.isLinkedKey(key: 'a'), isTrue);
          expect(target.isLinkedKey(key: 'b'), isTrue);
        });
      });
    });
  });

  group('Node evaluation', () {
    test('basic evaluation through graph', () {
      scope.run(() {
        late KeyNode<int> inputNode;
        late Reference<KeyNode<int>> inputRef;
        int? publishedValue;

        scope.runTransaction(() {
          inputNode = KeyNode<int>(evaluationType: EvaluationType.never);
          inputRef = Reference(inputNode);

          final doubler = KeyNode<int>(
            evaluateHandler: (inputs) =>
                NodeEvaluation(inputs.get<int>().value * 2),
            publishHandler: (value) => publishedValue = value,
          );

          doubler.link(inputNode);
          Reference(doubler);
        });

        // Send value through graph
        scope.runTransaction(() {
          final tx = Transaction.requiredTransaction;
          tx.setValue(inputNode, 5);
        });

        expect(publishedValue, 10); // 5 * 2

        inputRef.dispose();
      });
    });

    test('evaluation order follows priority', () {
      scope.run(() {
        final order = <String>[];

        scope.runTransaction(() {
          final source = KeyNode<int>(evaluationType: EvaluationType.never);
          final ref = Reference(source);

          final mid = KeyNode<int>(
            evaluateHandler: (inputs) {
              order.add('mid');
              return NodeEvaluation(inputs.get<int>().value + 1);
            },
          );
          mid.link(source);

          final end = KeyNode<int>(
            evaluateHandler: (inputs) {
              order.add('end');
              return inputs.get<int>();
            },
            publishHandler: (_) {},
          );
          end.link(mid);
          Reference(end);

          // Trigger evaluation
          final tx = Transaction.requiredTransaction;
          tx.setValue(source, 1);

          ref.dispose();
        });

        expect(order, ['mid', 'end']); // Mid evaluates before end
      });
    });

    test('distinct node filters consecutive duplicates', () {
      scope.run(() {
        late KeyNode<int> inputNode;
        late Reference<KeyNode<int>> inputRef;
        final published = <int>[];

        scope.runTransaction(() {
          inputNode = KeyNode<int>(evaluationType: EvaluationType.never);
          inputRef = Reference(inputNode);

          var previous = NodeEvaluation<int>.not();
          final distinctNode = KeyNode<int>(
            evaluateHandler: (inputs) {
              final current = inputs.get<int>();
              if (previous.isNotEvaluated || current.value != previous.value) {
                return current;
              }
              return NodeEvaluation<int>.not();
            },
            commitHandler: (value) => previous = NodeEvaluation(value),
            publishHandler: (value) => published.add(value),
          );
          distinctNode.link(inputNode);
          Reference(distinctNode);
        });

        scope.runTransaction(() {
          Transaction.requiredTransaction.setValue(inputNode, 1);
        });
        scope.runTransaction(() {
          Transaction.requiredTransaction.setValue(inputNode, 1);
        });
        scope.runTransaction(() {
          Transaction.requiredTransaction.setValue(inputNode, 2);
        });

        expect(published, [1, 2]); // Duplicate 1 filtered

        inputRef.dispose();
      });
    });
  });

  group('IndexNode', () {
    test('link multiple sources by index', () {
      scope.run(() {
        scope.runTransaction(() {
          final s1 = KeyNode<int>(evaluationType: EvaluationType.never);
          final s2 = KeyNode<int>(evaluationType: EvaluationType.never);

          final target = IndexNode<int>(
            evaluationType: EvaluationType.allInputs,
            evaluateHandler: (inputs) {
              final values = inputs.evaluations
                  .where((e) => e != null && e.isEvaluated)
                  .map((e) => e!.value as int);
              return NodeEvaluation(values.fold(0, (a, b) => a + b));
            },
          );

          target.link([s1, s2]);
          expect(target.isLinked, isTrue);
        });
      });
    });
  });

  group('NodeEvaluation', () {
    test('Evaluated contains value', () {
      final eval = NodeEvaluation<int>(42);
      expect(eval.isEvaluated, isTrue);
      expect(eval.isNotEvaluated, isFalse);
      expect(eval.value, 42);
    });

    test('NotEvaluated throws on value access', () {
      final eval = NodeEvaluation<int>.not();
      expect(eval.isEvaluated, isFalse);
      expect(eval.isNotEvaluated, isTrue);
      expect(() => eval.value, throwsStateError);
    });

    test('Evaluated equality', () {
      expect(NodeEvaluation(42), equals(NodeEvaluation(42)));
      expect(NodeEvaluation(42), isNot(equals(NodeEvaluation(43))));
    });

    test('NotEvaluated equality', () {
      expect(NodeEvaluation<int>.not(), equals(NodeEvaluation<int>.not()));
    });

    test('pattern matching with sealed class', () {
      final eval = NodeEvaluation<int>(42);

      final result = switch (eval) {
        Evaluated(value: final v) => 'value: $v',
        NotEvaluated() => 'not evaluated',
      };

      expect(result, 'value: 42');
    });
  });
}

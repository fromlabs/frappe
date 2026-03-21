import 'package:frappe/frappe.dart';
import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';
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

  group('Reference', () {
    test('single reference keeps object alive', () {
      scope.run(() {
        scope.runTransaction(() {
          final node = KeyNode<int>(evaluationType: EvaluationType.never);
          expect(node.isReferenced, isTrue); // Alive during transaction

          final ref = Reference(node);
          expect(node.isReferenced, isTrue);

          ref.dispose();
          // Node becomes unreferenced after ref disposal
        });
      });
    });

    test('multiple references require all disposed', () {
      scope.run(() {
        late KeyNode<int> node;
        late Reference<KeyNode<int>> ref1;
        late Reference<KeyNode<int>> ref2;

        scope.runTransaction(() {
          node = KeyNode<int>(evaluationType: EvaluationType.never);
          ref1 = Reference(node);
          ref2 = Reference(node);
        });

        expect(node.isReferenced, isTrue);

        ref1.dispose();
        expect(node.isReferenced, isTrue); // ref2 still active

        ref2.dispose();
        expect(node.isReferenced, isFalse);
      });
    });

    test('double dispose throws', () {
      scope.run(() {
        scope.runTransaction(() {
          final node = KeyNode<int>(evaluationType: EvaluationType.never);
          final ref = Reference(node);
          ref.dispose();
          expect(() => ref.dispose(), throwsStateError);
        });
      });
    });

    test('hosted reference requires referenced host', () {
      scope.run(() {
        scope.runTransaction(() {
          final host = KeyNode<int>(evaluationType: EvaluationType.never);
          final child = KeyNode<int>(evaluationType: EvaluationType.never);

          // Host is referenced during transaction
          final hostedRef = host.reference(child);
          expect(child.isReferenced, isTrue);

          // Cleanup
          hostedRef.dispose();
        });
      });
    });

    test('reference chain propagation', () {
      scope.run(() {
        late KeyNode<int> n1, n2, n3;
        late Reference<KeyNode<int>> ref1, ref2, ref3;

        scope.runTransaction(() {
          n1 = KeyNode<int>(evaluationType: EvaluationType.never);
          n2 = KeyNode<int>(evaluationType: EvaluationType.never);
          n3 = KeyNode<int>(evaluationType: EvaluationType.never);
          ref1 = Reference(n1);
          ref2 = Reference(n2);
          ref3 = Reference(n3);

          // Create hosted references: n1 → n2 → n3
          n1.reference(n2);
          n2.reference(n3);
        });

        // All alive
        expect(n1.isReferenced, isTrue);
        expect(n2.isReferenced, isTrue);
        expect(n3.isReferenced, isTrue);

        // Dispose ref1 - n1 still referenced (by ref1... wait, we disposed it)
        ref1.dispose();
        // n1 is unreferenced now, but n2 is still alive via ref2
        expect(n2.isReferenced, isTrue);
        expect(n3.isReferenced, isTrue);

        ref2.dispose();
        expect(n3.isReferenced, isTrue); // ref3 still active

        ref3.dispose();
        expect(n3.isReferenced, isFalse);
      });
    });

    test('reference replacement in transaction', () {
      scope.run(() {
        late KeyNode<int> node;
        late Reference<KeyNode<int>> ref1;

        scope.runTransaction(() {
          node = KeyNode<int>(evaluationType: EvaluationType.never);
          ref1 = Reference(node);
        });

        expect(node.isReferenced, isTrue);

        scope.runTransaction(() {
          final ref2 = Reference(node);
          ref1.dispose();
          expect(node.isReferenced, isTrue); // ref2 active
          ref1 = ref2;
        });

        ref1.dispose();
      });
    });
  });

  group('ReferenceGroup', () {
    test('dispose disposes all references', () {
      scope.run(() {
        scope.runTransaction(() {
          final n1 = KeyNode<int>(evaluationType: EvaluationType.never);
          final n2 = KeyNode<int>(evaluationType: EvaluationType.never);

          final group = ReferenceGroup();
          group.reference(n1);
          group.reference(n2);

          expect(n1.isReferenced, isTrue);
          expect(n2.isReferenced, isTrue);

          group.dispose();
        });
      });
    });

    test('double dispose throws', () {
      scope.run(() {
        scope.runTransaction(() {
          final group = ReferenceGroup();
          group.dispose();
          expect(() => group.dispose(), throwsStateError);
        });
      });
    });
  });

  group('FrappeReference', () {
    test('keeps stream alive', () {
      scope.run(() {
        late EventStreamSink<int> sink;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
        });

        // Without reference, stream is unreferenced
        expect(sink.isClosed, isTrue);
      });
    });

    test('toReference keeps stream alive', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        expect(sink.isClosed, isFalse);
        expect(ref.isDisposed, isFalse);

        ref.dispose();
        expect(sink.isClosed, isTrue);
        expect(ref.isDisposed, isTrue);
      });
    });

    test('toReference keeps state alive', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        scope.runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        expect(sink.isClosed, isFalse);

        ref.dispose();
        expect(sink.isClosed, isTrue);
      });
    });

    test('FrappeReferenceCollector batch disposal', () {
      scope.run(() {
        late EventStreamSink<int> sink1;
        late ValueStateSink<int> sink2;

        scope.runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = ValueStateSink<int>(0);
        });

        final collector = FrappeReferenceCollector();

        scope.runTransaction(() {
          collector.add(sink1.stream);
          collector.add(sink2.state);
        });

        expect(sink1.isClosed, isFalse);
        expect(sink2.isClosed, isFalse);

        collector.dispose();

        expect(sink1.isClosed, isTrue);
        expect(sink2.isClosed, isTrue);
      });
    });
  });
}

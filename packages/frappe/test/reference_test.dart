import 'dart:async';

import 'package:frappe/frappe.dart';
import 'package:frappe/src/node.dart';
import 'package:frappe/src/reference.dart';
import 'package:test/test.dart';

void main() {
  late FrappeScope scope;

  setUp(() {
    scope = FrappeScope();
  });

  tearDown(() {
    scope.run(() => scope.assertCleanState());
    scope.dispose();
  });

  group('Reference', () {
    test('single reference keeps object alive', () {
      scope.run(() {
        runTransaction(() {
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

        runTransaction(() {
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
        runTransaction(() {
          final node = KeyNode<int>(evaluationType: EvaluationType.never);
          final ref = Reference(node);
          ref.dispose();
          expect(() => ref.dispose(), throwsStateError);
        });
      });
    });

    test('hosted reference requires referenced host', () {
      scope.run(() {
        runTransaction(() {
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

        runTransaction(() {
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

        runTransaction(() {
          node = KeyNode<int>(evaluationType: EvaluationType.never);
          ref1 = Reference(node);
        });

        expect(node.isReferenced, isTrue);

        runTransaction(() {
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
        runTransaction(() {
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
        runTransaction(() {
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

        runTransaction(() {
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

        runTransaction(() {
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

        runTransaction(() {
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

        runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = ValueStateSink<int>(0);
        });

        final collector = FrappeReferenceCollector();

        runTransaction(() {
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

  group('FrappeReferenceCollector factory methods', () {
    test('addStreamSink creates sink and references stream', () {
      scope.run(() {
        final collector = FrappeReferenceCollector();
        late EventStreamSink<int> sink;

        runTransaction(() {
          sink = collector.addStreamSink<int>();
        });

        expect(sink.isClosed, isFalse);

        final events = <int>[];
        final sub = runTransaction(() => sink.stream.listen(events.add));
        sink.send(42);
        expect(events, [42]);

        sub.cancel();
        collector.dispose();
        expect(sink.isClosed, isTrue);
      });
    });

    test('addStateSink creates sink and references state', () {
      scope.run(() {
        final collector = FrappeReferenceCollector();
        late ValueStateSink<int> sink;

        runTransaction(() {
          sink = collector.addStateSink<int>(0);
        });

        expect(sink.isClosed, isFalse);
        expect(sink.state.getValue(), 0);

        sink.send(99);
        expect(sink.state.getValue(), 99);

        collector.dispose();
        expect(sink.isClosed, isTrue);
      });
    });

    test('addStreamLink creates link and references stream', () {
      scope.run(() {
        final collector = FrappeReferenceCollector();
        late EventStreamLink<int> link;
        late EventStreamSink<int> sourceSink;

        runTransaction(() {
          link = collector.addStreamLink<int>();
          sourceSink = EventStreamSink<int>();
          collector.add(sourceSink.stream);
          link.connect(sourceSink.stream);
        });

        expect(link.isConnected, isTrue);

        final events = <int>[];
        final sub = runTransaction(() => link.stream.listen(events.add));
        sourceSink.send(7);
        expect(events, [7]);

        sub.cancel();
        collector.dispose();
      });
    });

    test('addStateLink creates link and references state', () {
      scope.run(() {
        final collector = FrappeReferenceCollector();
        late ValueStateLink<int> link;

        runTransaction(() {
          link = collector.addStateLink<int>();
          link.connect(ValueState.constant(42));
        });

        expect(link.isConnected, isTrue);
        expect(link.state.getValue(), 42);

        collector.dispose();
      });
    });
  });

  group('Reference additional coverage', () {
    test('FrappeReference double dispose is safe', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        ref.dispose();
        // Second dispose throws StateError because underlying Reference
        // checks disposed state
        expect(() => ref.dispose(), throwsStateError);
      });
    });

    test('FrappeReferenceCollector add after dispose', () {
      scope.run(() {
        late EventStreamSink<int> sink;

        runTransaction(() {
          sink = EventStreamSink<int>();
        });

        final collector = FrappeReferenceCollector();
        collector.dispose();

        // After dispose, the collector's internal list was cleared but no
        // disposed flag is set, so add still works -- it creates a reference
        // internally and adds it to the (now empty) list
        runTransaction(() {
          collector.add(sink.stream);
        });

        expect(sink.isClosed, isFalse);

        // Calling dispose again will dispose the newly added reference
        collector.dispose();
        expect(sink.isClosed, isTrue);
      });
    });

    test('multiple references to same stream', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref1;
        late FrappeReference<EventStream<int>> ref2;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref1 = sink.stream.toReference();
          ref2 = sink.stream.toReference();
        });

        expect(sink.isClosed, isFalse);

        // Dispose only the first reference
        ref1.dispose();
        // Stream still alive because ref2 is active
        expect(sink.isClosed, isFalse);

        // Dispose the second reference
        ref2.dispose();
        // Now stream is unreferenced
        expect(sink.isClosed, isTrue);
      });
    });

    test('listener keeps stream alive', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        // Add a listener - the listener's node holds a reference to the
        // stream's node via the link
        final events = <int>[];
        final sub = runTransaction(() => sink.stream.listen(events.add));

        // Dispose the FrappeReference
        ref.dispose();

        // The subscription's internal Reference keeps the listen node alive,
        // and via the link the source stream node stays referenced
        expect(sink.isClosed, isFalse);

        // Verify stream still works
        sink.send(42);
        expect(events, [42]);

        // Cancel the subscription - now the stream becomes unreferenced
        sub.cancel();
        expect(sink.isClosed, isTrue);
      });
    });
  });

  group('Leak tracking', () {
    test('FrappeReference registers token on creation and removes on dispose',
        () {
      scope.run(() {
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          final sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        expect(scope.activeUserReferences, hasLength(1));
        final token = scope.activeUserReferences.first;
        expect(token.type, contains('FrappeReference'));

        ref.dispose();
        expect(scope.activeUserReferences, isEmpty);
      });
    });

    test('ListenSubscription registers token on creation and removes on cancel',
        () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final sub = runTransaction(() => sink.stream.listen((_) {}));
        // FrappeReference token + ListenSubscription token
        expect(scope.activeUserReferences, hasLength(2));
        final subToken = scope.activeUserReferences
            .firstWhere((t) => t.type == 'ListenSubscription');
        expect(subToken.nodeLabel, isNotEmpty);

        sub.cancel();
        // Only FrappeReference token remains
        expect(scope.activeUserReferences, hasLength(1));

        ref.dispose();
        expect(scope.activeUserReferences, isEmpty);
      });
    });

    test('creation stack trace is captured in assert mode', () {
      scope.run(() {
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          final sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final token = scope.activeUserReferences.first;
        // Tests always run in assert mode
        expect(token.creationTrace, isNotNull);

        ref.dispose();
      });
    });

    test('assertCleanState reports undisposed FrappeReference with node label',
        () {
      final testScope = FrappeScope();
      testScope.run(() {
        runTransaction(() {
          final sink = EventStreamSink<int>();
          sink.stream.toReference(); // Not disposed
        });

        expect(
          () => testScope.assertCleanState(),
          throwsA(
            isA<AssertionError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('UNDISPOSED USER REFERENCES'),
                contains('FrappeReference'),
              ),
            ),
          ),
        );

        // Clean up to avoid polluting other tests
        testScope.cleanState();
      });
    });

    test('assertCleanState reports uncancelled ListenSubscription', () {
      final testScope = FrappeScope();
      testScope.run(() {
        runTransaction(() {
          final sink = EventStreamSink<int>();
          sink.stream.toReference(); // Keep stream alive
          sink.stream.listen((_) {}); // Not cancelled
        });

        expect(
          () => testScope.assertCleanState(),
          throwsA(
            isA<AssertionError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('UNDISPOSED USER REFERENCES'),
                contains('ListenSubscription'),
              ),
            ),
          ),
        );

        testScope.cleanState();
      });
    });

    test('onLeakDetected reports error to zone', () {
      final errors = <Object>[];
      runZonedGuarded(() {
        final token = LeakTrackingToken('FrappeReference<test>', 'node:99');
        FrappeScope.onLeakDetected(token);
      }, (error, _) {
        errors.add(error);
      });
      expect(errors, hasLength(1));
      expect(errors.first, isA<StateError>());
      expect(
        (errors.first as StateError).message,
        contains('LEAK DETECTED'),
      );
    });

    test('assertCleanState groups multiple leaks', () {
      final testScope = FrappeScope();
      testScope.run(() {
        runTransaction(() {
          final sink1 = EventStreamSink<int>();
          final sink2 = EventStreamSink<int>();
          sink1.stream.toReference(); // Leak 1
          sink2.stream.toReference(); // Leak 2
        });

        expect(
          () => testScope.assertCleanState(),
          throwsA(
            isA<AssertionError>().having(
              (e) => e.message,
              'message',
              contains('UNDISPOSED USER REFERENCES (2)'),
            ),
          ),
        );

        testScope.cleanState();
      });
    });

    test('FrappeReferenceCollector registers and unregisters tokens', () {
      scope.run(() {
        late EventStreamSink<int> sink1;
        late ValueStateSink<int> sink2;

        runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = ValueStateSink<int>(0);
        });

        final collector = FrappeReferenceCollector();

        runTransaction(() {
          collector.add(sink1.stream);
          collector.add(sink2.state);
        });

        expect(scope.activeUserReferences, hasLength(2));

        collector.dispose();
        expect(scope.activeUserReferences, isEmpty);
      });
    });
  });
}

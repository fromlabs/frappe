import 'package:frappe/frappe.dart';
import 'package:frappe/src/event_stream.dart' show EventStreamNode;
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

  group('Transaction', () {
    test('isInTransaction is false outside transaction', () {
      scope.run(() {
        expect(Transaction.isInTransaction, isFalse);
      });
    });

    test('isInTransaction is true inside transaction', () {
      scope.run(() {
        scope.runTransaction(() {
          expect(Transaction.isInTransaction, isTrue);
        });
      });
    });

    test('requiredTransaction throws outside transaction', () {
      scope.run(() {
        expect(() => Transaction.requiredTransaction, throwsUnsupportedError);
      });
    });

    test('nested transactions reuse outer transaction', () {
      scope.run(() {
        scope.runTransaction(() {
          final outer = Transaction.requiredTransaction;
          scope.runTransaction(() {
            expect(Transaction.requiredTransaction, same(outer));
          });
        });
      });
    });

    test('transaction phases progress correctly', () {
      scope.run(() {
        final phases = <TransactionPhase>[];

        scope.runTransaction(() {
          final sink = EventStreamSink<int>();
          final ref = sink.stream.toReference();

          final sub = sink.stream.listen((value) {
            // This runs during publish phase
          });

          sink.send(1);

          phases.add(Transaction.requiredTransaction.phase);
          // Should be 'opened'
          expect(phases.last, TransactionPhase.opened);

          sub.cancel();
          ref.dispose();
        });
      });
    });

    test('send during publish creates new transaction', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        // A listener that sends during publish phase creates a new transaction
        var callCount = 0;
        final sub = scope.runTransaction(() => sink.stream.listen((value) {
              callCount++;
              if (callCount == 1) {
                // This creates a new transaction since we're in publish phase
                sink.send(value + 1);
              }
            }));

        sink.send(1);
        expect(callCount, 2); // Original + recursive via new transaction

        sub.cancel();
        ref.dispose();
      });
    });

    test('error in publish handler is caught and reported', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final sub = scope.runTransaction(
            () => sink.stream.listen((value) => throw Exception('test error')));

        // Should not throw - error is caught in publish phase
        expect(() => sink.send(1), returnsNormally);

        sub.cancel();
        ref.dispose();
      });
    });
  });

  group('Transaction via scope.runTransaction', () {
    test('creates and completes a transaction', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(() => sink.stream.listen(events.add));

        scope.runTransaction(() => sink.send(42));
        expect(events, [42]);

        sub.cancel();
        ref.dispose();
      });
    });
  });

  group('Transaction additional coverage', () {
    test('currentTransaction is null outside transaction', () {
      scope.run(() {
        expect(Transaction.currentTransaction, isNull);
      });
    });

    test('currentTransaction returns transaction inside', () {
      scope.run(() {
        scope.runTransaction(() {
          expect(Transaction.currentTransaction, isNotNull);
        });
      });
    });

    test('runNew creates independent transaction', () {
      scope.run(() {
        scope.runTransaction(() {
          final outer = Transaction.requiredTransaction;
          Transaction.runNew((inner) {
            expect(inner, isNot(same(outer)));
          });
        });
      });
    });

    test('multiple sinks in same transaction', () {
      scope.run(() {
        late EventStreamSink<int> sink1;
        late EventStreamSink<int> sink2;
        late FrappeReference<EventStream<int>> ref1;
        late FrappeReference<EventStream<int>> ref2;

        scope.runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = EventStreamSink<int>();
          ref1 = sink1.stream.toReference();
          ref2 = sink2.stream.toReference();
        });

        final events1 = <int>[];
        final events2 = <int>[];
        final sub1 =
            scope.runTransaction(() => sink1.stream.listen(events1.add));
        final sub2 =
            scope.runTransaction(() => sink2.stream.listen(events2.add));

        scope.runTransaction(() {
          sink1.send(10);
          sink2.send(20);
        });

        expect(events1, [10]);
        expect(events2, [20]);

        sub1.cancel();
        sub2.cancel();
        ref1.dispose();
        ref2.dispose();
      });
    });

    test(
        'multiple sends to same sink in transaction throws without merger', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        expect(
          () => scope.runTransaction(() {
            sink.send(1);
            sink.send(2);
          }),
          throwsUnsupportedError,
        );

        ref.dispose();
      });
    });

    test('multiple sends to same sink with merger succeeds', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>((a, b) => a + b);
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(() => sink.stream.listen(events.add));

        scope.runTransaction(() {
          sink.send(3);
          sink.send(7);
        });

        expect(events, [10]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('closing handler receives correct transaction', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        TransactionPhase? receivedPhase;
        scope.runTransaction(() {
          Transaction.addClosingTransactionHandler(
            sink.stream.node,
            (tx) {
              receivedPhase = tx.phase;
            },
          );
        });

        // Trigger a transaction so the closing handler fires
        scope.runTransaction(() {
          sink.send(42);
        });

        expect(receivedPhase, TransactionPhase.closing);

        // Clean up handler before disposing
        scope.runTransaction(() {
          Transaction.removeClosingTransactionHandler(sink.stream.node);
        });
        ref.dispose();
      });
    });
  });
}

import 'package:frappe/frappe.dart';
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

          sink.stream.listen((value) {
            // This runs during publish phase
          });

          sink.send(1);

          phases.add(Transaction.requiredTransaction.phase);
          // Should be 'opened'
          expect(phases.last, TransactionPhase.opened);

          ref.dispose();
        });
      });
    });

    test('send during evaluation/publish throws', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        // A listener that tries to send back into the same sink
        // should trigger a new transaction, not error
        var callCount = 0;
        final sub = scope.runTransaction(() => sink.stream.listen((value) {
              callCount++;
              if (callCount == 1) {
                // This creates a new transaction (we're in publish phase of outer)
                sink.send(value + 1);
              }
            }));

        sink.send(1);
        expect(callCount, 2); // Original + recursive

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
}

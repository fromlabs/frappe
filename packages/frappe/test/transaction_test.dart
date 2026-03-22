import 'dart:async';

import 'package:frappe/frappe.dart';
import 'package:frappe/src/event_stream.dart' show EventStreamNode;
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

  group('Transaction', () {
    test('isInTransaction is false outside transaction', () {
      scope.run(() {
        expect(Transaction.isInTransaction, isFalse);
      });
    });

    test('isInTransaction is true inside transaction', () {
      scope.run(() {
        runTransaction(() {
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
        runTransaction(() {
          final outer = Transaction.requiredTransaction;
          runTransaction(() {
            expect(Transaction.requiredTransaction, same(outer));
          });
        });
      });
    });

    test('transaction phases progress correctly', () {
      scope.run(() {
        final phases = <TransactionPhase>[];

        runTransaction(() {
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

    test('send during publish throws UnsupportedError', () {
      final errors = <Object>[];
      final errorScope =
          FrappeScope(onError: (error, _) => errors.add(error));
      errorScope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        // Sending from a listener is an FRP anti-pattern; the error is
        // caught by the publish phase's try-catch and reported, not thrown.
        final sub = runTransaction(() => sink.stream.listen((value) {
              sink.send(value + 1);
            }));

        expect(() => sink.send(1), returnsNormally);
        expect(errors, hasLength(1));
        expect(errors.first, isA<UnsupportedError>());

        sub.cancel();
        ref.dispose();
      });
      errorScope.run(() => errorScope.assertCleanState());
      errorScope.dispose();
    });

    test('error in publish handler is caught and reported', () {
      final errors = <Object>[];
      final errorScope =
          FrappeScope(onError: (error, _) => errors.add(error));
      errorScope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final sub = runTransaction(
            () => sink.stream.listen((value) => throw Exception('test error')));

        // Should not throw - error is caught in publish phase
        expect(() => sink.send(1), returnsNormally);
        expect(errors, hasLength(1));
        expect(errors.first, isA<Exception>());

        sub.cancel();
        ref.dispose();
      });
      errorScope.run(() => errorScope.assertCleanState());
      errorScope.dispose();
    });
  });

  group('Transaction via scope.runTransaction', () {
    test('creates and completes a transaction', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => sink.stream.listen(events.add));

        runTransaction(() => sink.send(42));
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
        runTransaction(() {
          expect(Transaction.currentTransaction, isNotNull);
        });
      });
    });

    test('runNew creates independent transaction', () {
      scope.run(() {
        runTransaction(() {
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

        runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = EventStreamSink<int>();
          ref1 = sink1.stream.toReference();
          ref2 = sink2.stream.toReference();
        });

        final events1 = <int>[];
        final events2 = <int>[];
        final sub1 = runTransaction(() => sink1.stream.listen(events1.add));
        final sub2 = runTransaction(() => sink2.stream.listen(events2.add));

        runTransaction(() {
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

    test('multiple sends to same sink in transaction throws without merger',
        () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        expect(
          () => runTransaction(() {
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

        runTransaction(() {
          sink = EventStreamSink<int>((a, b) => a + b);
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => sink.stream.listen(events.add));

        runTransaction(() {
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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        TransactionPhase? receivedPhase;
        runTransaction(() {
          Transaction.addClosingTransactionHandler(
            sink.stream.node,
            (tx) {
              receivedPhase = tx.phase;
            },
          );
        });

        // Trigger a transaction so the closing handler fires
        runTransaction(() {
          sink.send(42);
        });

        expect(receivedPhase, TransactionPhase.closing);

        // Clean up handler before disposing
        runTransaction(() {
          Transaction.removeClosingTransactionHandler(sink.stream.node);
        });
        ref.dispose();
      });
    });
  });

  group('Transaction error handling', () {
    test('publish error is routed to scope onError handler', () {
      final errors = <Object>[];
      final errorScope =
          FrappeScope(onError: (error, _) => errors.add(error));
      errorScope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final sub = runTransaction(
            () => sink.stream.listen((_) => throw StateError('publish fail')));

        sink.send(1);
        expect(errors, hasLength(1));
        expect((errors.first as StateError).message, 'publish fail');

        sub.cancel();
        ref.dispose();
      });
      errorScope.run(() => errorScope.assertCleanState());
      errorScope.dispose();
    });

    test('closing handler error is caught and reported', () {
      final errors = <Object>[];
      final errorScope =
          FrappeScope(onError: (error, _) => errors.add(error));
      errorScope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        runTransaction(() {
          Transaction.addClosingTransactionHandler(
            sink.stream.node,
            (_) => throw StateError('closing fail'),
          );
        });
        // Clear errors from the registration transaction (the handler fires
        // during every transaction's closing phase, including the one above).
        errors.clear();

        // Transaction should complete normally despite closing handler error
        expect(() => sink.send(1), returnsNormally);
        expect(errors, hasLength(1));
        expect((errors.first as StateError).message, 'closing fail');

        runTransaction(() {
          Transaction.removeClosingTransactionHandler(sink.stream.node);
        });
        ref.dispose();
      });
      errorScope.run(() => errorScope.assertCleanState());
      errorScope.dispose();
    });

    test('closing handler error does not prevent other handlers from running',
        () {
      final errors = <Object>[];
      var secondHandlerRan = false;
      final errorScope =
          FrappeScope(onError: (error, _) => errors.add(error));
      errorScope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;
        late EventStreamSink<int> sink2;
        late FrappeReference<EventStream<int>> ref2;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
          sink2 = EventStreamSink<int>();
          ref2 = sink2.stream.toReference();
        });

        // Register two closing handlers: first throws, second should still run
        runTransaction(() {
          Transaction.addClosingTransactionHandler(
            sink.stream.node,
            (_) => throw StateError('first handler'),
          );
          Transaction.addClosingTransactionHandler(
            sink2.stream.node,
            (_) => secondHandlerRan = true,
          );
        });
        // Clear errors from registration transaction's closing phase.
        errors.clear();
        secondHandlerRan = false;

        sink.send(1);
        expect(secondHandlerRan, isTrue);
        expect(errors, hasLength(1));

        runTransaction(() {
          Transaction.removeClosingTransactionHandler(sink.stream.node);
          Transaction.removeClosingTransactionHandler(sink2.stream.node);
        });
        ref.dispose();
        ref2.dispose();
      });
      errorScope.run(() => errorScope.assertCleanState());
      errorScope.dispose();
    });

    test('default error handler delegates to zone', () {
      final zoneErrors = <Object>[];
      runZonedGuarded(() {
        final errorScope = FrappeScope();
        errorScope.run(() {
          late EventStreamSink<int> sink;
          late FrappeReference<EventStream<int>> ref;

          runTransaction(() {
            sink = EventStreamSink<int>();
            ref = sink.stream.toReference();
          });

          final sub = runTransaction(
              () => sink.stream.listen((_) => throw StateError('zone test')));

          sink.send(1);

          sub.cancel();
          ref.dispose();
        });
        errorScope.run(() => errorScope.assertCleanState());
        errorScope.dispose();
      }, (error, _) {
        zoneErrors.add(error);
      });
      expect(zoneErrors, hasLength(1));
      expect((zoneErrors.first as StateError).message, 'zone test');
    });

    test('error handler that throws is handled gracefully', () {
      final errorScope = FrappeScope(
        onError: (_, __) => throw StateError('handler itself fails'),
      );
      errorScope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub1 = runTransaction(() => sink.stream.listen(events.add));
        final sub2 = runTransaction(
            () => sink.stream.listen((_) => throw Exception('listener fail')));

        // Use runZonedGuarded to catch the fallback zone error from _reportError
        final fallbackErrors = <Object>[];
        runZonedGuarded(() {
          sink.send(42);
        }, (error, _) {
          fallbackErrors.add(error);
        });

        // The non-throwing listener should still receive the value
        expect(events, [42]);
        // The fallback caught the error handler's own error
        expect(fallbackErrors, isNotEmpty);

        sub1.cancel();
        sub2.cancel();
        ref.dispose();
      });
      errorScope.run(() => errorScope.assertCleanState());
      errorScope.dispose();
    });

    test('multiple publish errors are all reported', () {
      final errors = <Object>[];
      final errorScope =
          FrappeScope(onError: (error, _) => errors.add(error));
      errorScope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final sub1 = runTransaction(
            () => sink.stream.listen((_) => throw StateError('error 1')));
        final sub2 = runTransaction(
            () => sink.stream.listen((_) => throw StateError('error 2')));

        sink.send(1);
        expect(errors, hasLength(2));

        sub1.cancel();
        sub2.cancel();
        ref.dispose();
      });
      errorScope.run(() => errorScope.assertCleanState());
      errorScope.dispose();
    });
  });
}

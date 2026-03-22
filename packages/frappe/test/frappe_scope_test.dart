import 'dart:async';

import 'package:frappe/frappe.dart';
import 'package:test/test.dart';

void main() {
  group('FrappeScope', () {
    test('current returns root when no explicit scope is active', () {
      expect(FrappeScope.current, same(FrappeScope.root));
    });

    test('currentOrNull returns null when no explicit scope is active', () {
      expect(FrappeScope.currentOrNull, isNull);
    });

    test('run makes scope available via current', () {
      final scope = FrappeScope();
      scope.run(() {
        expect(FrappeScope.current, same(scope));
        expect(FrappeScope.currentOrNull, same(scope));
      });
      scope.dispose();
    });

    test('nested scopes use innermost scope', () {
      final outer = FrappeScope();
      final inner = FrappeScope();

      outer.run(() {
        expect(FrappeScope.current, same(outer));
        inner.run(() {
          expect(FrappeScope.current, same(inner));
        });
        expect(FrappeScope.current, same(outer));
      });

      outer.dispose();
      inner.dispose();
    });

    test('dispose throws if state is not clean', () {
      final scope = FrappeScope();
      scope.run(() {
        runTransaction(() {
          final sink = EventStreamSink<int>();
          final ref = sink.stream.toReference();
          expect(
            () => scope.dispose(),
            throwsA(
              isA<AssertionError>().having(
                (e) => e.message,
                'message',
                contains('Clean state assertion failed'),
              ),
            ),
          );
          ref.dispose();
        });
      });
      scope.dispose();
    });

    test('dispose succeeds when state is clean', () {
      final scope = FrappeScope();
      scope.run(() {
        runTransaction(() {
          final sink = EventStreamSink<int>();
          final ref = sink.stream.toReference();
          ref.dispose();
        });
      });
      expect(() => scope.dispose(), returnsNormally);
    });

    test('double dispose throws', () {
      final scope = FrappeScope();
      scope.dispose();
      expect(() => scope.dispose(), throwsStateError);
    });

    test('scopes are isolated from each other', () {
      final scope1 = FrappeScope();
      final scope2 = FrappeScope();

      late EventStreamSink<int> sink1;
      late FrappeReference<EventStream<int>> ref1;

      scope1.run(() {
        runTransaction(() {
          sink1 = EventStreamSink<int>();
          ref1 = sink1.stream.toReference();
        });
      });

      // scope2 should have clean state
      scope2.dispose();

      // Clean up scope1
      scope1.run(() {
        ref1.dispose();
      });
      scope1.dispose();
    });

    test('root scope is always available for transactions', () {
      // No explicit scope needed
      late EventStreamSink<int> sink;
      late FrappeReference<EventStream<int>> ref;

      runTransaction(() {
        sink = EventStreamSink<int>();
        ref = sink.stream.toReference();
      });

      final events = <int>[];
      final sub = ref.object.listen(events.add);

      runTransaction(() => sink.send(42));
      expect(events, [42]);

      sub.cancel();
      ref.dispose();
    });

    test('custom onError receives publish errors', () {
      final errors = <Object>[];
      final scope = FrappeScope(onError: (error, _) => errors.add(error));
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final sub = runTransaction(
            () => sink.stream.listen((_) => throw StateError('scope test')));

        sink.send(1);
        expect(errors, hasLength(1));
        expect((errors.first as StateError).message, 'scope test');

        sub.cancel();
        ref.dispose();
      });
      scope.run(() => scope.assertCleanState());
      scope.dispose();
    });

    test('default scope uses Zone.handleUncaughtError', () {
      final zoneErrors = <Object>[];
      runZonedGuarded(() {
        final scope = FrappeScope();
        scope.run(() {
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
        scope.run(() => scope.assertCleanState());
        scope.dispose();
      }, (error, _) {
        zoneErrors.add(error);
      });
      expect(zoneErrors, hasLength(1));
      expect((zoneErrors.first as StateError).message, 'zone test');
    });
  });
}

import 'package:frappe/frappe.dart';
import 'package:test/test.dart';

void main() {
  group('ReactiveScope', () {
    test('current throws when no scope is active', () {
      expect(() => ReactiveScope.current, throwsStateError);
    });

    test('currentOrNull returns null when no scope is active', () {
      expect(ReactiveScope.currentOrNull, isNull);
    });

    test('run makes scope available via current', () {
      final scope = ReactiveScope();
      scope.run(() {
        expect(ReactiveScope.current, same(scope));
        expect(ReactiveScope.currentOrNull, same(scope));
      });
      scope.dispose();
    });

    test('nested scopes use innermost scope', () {
      final outer = ReactiveScope();
      final inner = ReactiveScope();

      outer.run(() {
        expect(ReactiveScope.current, same(outer));
        inner.run(() {
          expect(ReactiveScope.current, same(inner));
        });
        expect(ReactiveScope.current, same(outer));
      });

      outer.dispose();
      inner.dispose();
    });

    test('dispose throws if state is not clean', () {
      final scope = ReactiveScope();
      // Artificially add dangling state
      scope.run(() {
        scope.runTransaction(() {
          final sink = EventStreamSink<int>();
          final ref = sink.stream.toReference();
          // Don't dispose ref - should cause assertCleanState to fail
          expect(() => scope.dispose(), throwsA(isA<AssertionError>()));
          ref.dispose();
        });
      });
      scope.dispose();
    });

    test('dispose succeeds when state is clean', () {
      final scope = ReactiveScope();
      scope.run(() {
        scope.runTransaction(() {
          final sink = EventStreamSink<int>();
          final ref = sink.stream.toReference();
          ref.dispose();
        });
      });
      expect(() => scope.dispose(), returnsNormally);
    });

    test('double dispose throws', () {
      final scope = ReactiveScope();
      scope.dispose();
      expect(() => scope.dispose(), throwsStateError);
    });

    test('scopes are isolated from each other', () {
      final scope1 = ReactiveScope();
      final scope2 = ReactiveScope();

      late EventStreamSink<int> sink1;
      late FrappeReference<EventStream<int>> ref1;

      scope1.run(() {
        scope1.runTransaction(() {
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
  });
}

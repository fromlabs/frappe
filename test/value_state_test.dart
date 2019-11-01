import 'dart:collection';

import 'package:frappe/frappe.dart';
import 'package:frappe/src/transaction.dart';
import 'package:optional/optional_internal.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    assertCleanup();
  });
  tearDown(() {
    assertCleanup();
  });

  group('ValueState', () {
    test('Test 1', () {
      ValueState<int>.constant(1);
    });

    test('Test 2', () {
      final sink = ValueStateSink<int>(-1);

      sink.send(0);

      final events1 = Queue<int>();
      final subscription1 = sink.state.toUpdates().listen((event) {
        events1.addLast(event);
      });

      expect(events1, isEmpty);

      sink.send(1);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(1));
      expect(events1, isEmpty);

      sink.send(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);

      subscription1.cancel();

      sink.send(3);

      expect(events1, isEmpty);

      sink.close();
    });

    test('Test 3', () {
      final sink = ValueStateSink<int>(0);

      final events1 = Queue<int>();
      final subscription1 = sink.state.listen((event) {
        events1.addLast(event);
      });

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(0));
      expect(events1, isEmpty);

      subscription1.cancel();

      expect(events1, isEmpty);

      sink.close();
    });

    test('Test 4', () {
      final sink = ValueStateSink<int>(-1);

      final events1 = Queue<int>();
      ListenSubscription subscription1;
      runTransaction(() {
        sink.send(0);

        subscription1 = sink.state.listen((event) {
          events1.addLast(event);
        });
      });

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(0));
      expect(events1, isEmpty);

      subscription1.cancel();

      sink.send(3);

      expect(events1, isEmpty);

      sink.close();
    });

    test('Test 5', () {
      final sink = ValueStateSink<int>(-1);

      sink.send(0);

      final events1 = Queue<int>();
      final subscription1 = sink.state.listen((event) {
        events1.addLast(event);
      });

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(0));
      expect(events1, isEmpty);

      sink.send(1);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(1));
      expect(events1, isEmpty);

      sink.send(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);

      subscription1.cancel();

      sink.send(3);

      expect(events1, isEmpty);

      sink.close();
    });

    test('Test 6', () {
      final sink = ValueStateSink<int>(1);

      final events1 = Queue<int>();

      final subscription1 = runTransaction(
          () => sink.state.map((value) => 2 * value).listen((event) {
                events1.addLast(event);
              }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);

      sink.send(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(4));
      expect(events1, isEmpty);

      subscription1.cancel();

      sink.close();
    });

    test('Test 7', () {
      final sink = ValueStateSink<int>(0);

      final events1 = Queue<Optional<int>>();

      final subscription1 = runTransaction(() => sink.state
              .map<Optional<int>>((value) =>
                  value.isEven ? Optional.of(value) : Optional.empty())
              .asOptional()
              .listen((event) {
            events1.addLast(event);
          }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(Optional.of(0)));
      expect(events1, isEmpty);

      sink.send(1);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(Optional.empty()));
      expect(events1, isEmpty);

      sink.send(4);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(Optional.of(4)));
      expect(events1, isEmpty);

      sink.send(6);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(Optional.of(6)));
      expect(events1, isEmpty);

      sink.send(7);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(Optional.empty()));
      expect(events1, isEmpty);

      subscription1.cancel();

      sink.close();
    });

    test('Test 8', () {
      final sink = ValueStateSink<int>(-1);

      final events1 = Queue<int>();

      final subscription1 = runTransaction(
          () => sink.state.map((value) => 2 * value).distinct().listen((event) {
                events1.addLast(event);
              }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(-2));
      expect(events1, isEmpty);

      sink.send(1);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);

      sink.send(1);

      expect(events1, isEmpty);

      sink.send(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(4));
      expect(events1, isEmpty);

      sink.send(1);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);

      sink.send(1);

      expect(events1, isEmpty);

      subscription1.cancel();

      sink.close();
    });

    test('Test 6', () {
      final sink = ValueStateSink<int>(1);

      final events1 = Queue<int>();

      final subscription1 = runTransaction(() {
        final link = ValueStateLink<int>();

        link.connect(sink.state);

        return sink.state.map((value) => 2 * value).listen((event) {
          events1.addLast(event);
        });
      });

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);

      sink.send(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(4));
      expect(events1, isEmpty);

      subscription1.cancel();

      sink.close();
    });
  });

  group('OptionalValueState', () {
    test('Test 1', () {
      OptionalValueState<int>.constantOf(1);
    });
  });

  group('ValueStateSink', () {
    test('Test 1', () {
      final sink = ValueStateSink<int>(1);

      expect(sink.isClosed, isFalse);

      sink.send(1);

      sink.close();

      expect(sink.isClosed, isTrue);

      expect(() => sink.send(1), throwsStateError);
    });

    test('Test 2', () {
      final sink = ValueStateSink<int>(1);

      sink.send(1);

      sink.send(2);

      runTransaction(() {
        sink.send(3);
      });

      runTransaction(() {
        sink.send(4);

        expect(() => sink.send(5), throwsUnsupportedError);
      });

      sink.close();
    });

    test('Test 3', () {
      final sink = ValueStateSink<int>(1, (newValue, oldValue) => newValue);

      sink.send(1);

      sink.send(2);

      runTransaction(() {
        sink.send(3);
      });

      runTransaction(() {
        sink.send(4);

        sink.send(5);
      });

      sink.close();
    });
  });

  group('OptionalValueStateSink', () {
    test('Test 1', () {
      final sink = OptionalValueStateSink<int>.of(1);

      expect(sink.isClosed, isFalse);

      sink.send(Optional.of(1));

      sink.close();

      expect(sink.isClosed, isTrue);

      expect(() => sink.send(Optional.of(1)), throwsStateError);
    });

    test('Test 2', () {
      final sink = OptionalValueStateSink<int>.of(1);

      sink.send(Optional.of(1));

      sink.send(Optional.of(2));

      runTransaction(() {
        sink.send(Optional.of(3));
      });

      runTransaction(() {
        sink.send(Optional.of(4));

        expect(() => sink.send(Optional.of(5)), throwsUnsupportedError);
      });

      sink.close();
    });

    test('Test 3', () {
      final sink =
          OptionalValueStateSink<int>.empty((newValue, oldValue) => newValue);

      sink.send(Optional.of(1));

      sink.send(Optional.of(2));

      runTransaction(() {
        sink.send(Optional.of(3));
      });

      runTransaction(() {
        sink.send(Optional.of(4));

        sink.send(Optional.of(5));
      });

      sink.close();
    });
  });
}

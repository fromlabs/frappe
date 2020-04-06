import 'dart:collection';

import 'package:frappe/frappe.dart';
import 'package:optional/optional_internal.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    FrappeObject.cleanState();
  });

  tearDown(() {
    FrappeObject.assertCleanState();
  });

  group('ValueState 01', () {
    test('Test 01', () {
      runTransaction(() => ValueState<int>.constant(1));
    });

    test('Test 02', () {
      final sink = ValueStateSink<int>(-1);

      sink.send(0);

      final events1 = Queue<int>();
      final subscription1 =
          runTransaction(() => sink.state.toUpdates().listen((event) {
                events1.addLast(event);
              }));

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

    test('Test 03', () {
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

    test('Test 04', () {
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

    test('Test 05', () {
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

    test('Test 06', () {
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

    test('Test 07', () {
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

    test('Test 08', () {
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

    test('Test 09', () {
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

    test('Test 10', () {
      final sink1 = ValueStateSink<int>(1);
      final sink2 = ValueStateSink<int>(2);

      final events1 = Queue<int>();

      final subscription1 = runTransaction(() =>
          sink1.state.combine(sink2.state, (v1, v2) => v1 + v2).listen((event) {
            events1.addLast(event);
          }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(3));
      expect(events1, isEmpty);

      sink1.send(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(4));
      expect(events1, isEmpty);

      sink2.send(3);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(5));
      expect(events1, isEmpty);

      runTransaction(() {
        sink1.send(4);
        sink2.send(5);
      });

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(9));
      expect(events1, isEmpty);

      subscription1.cancel();

      sink1.close();
      sink2.close();
    });

    test('Test 11', () {
      final sink = runTransaction(
          () => ValueStateSink<EventStream<int>>(EventStream.never()));

      final sink1 = EventStreamSink<int>();
      final sink2 = EventStreamSink<int>();

      final events1 = Queue<int>();

      final subscription1 = runTransaction(
          () => ValueState.switchStream(sink.state).listen((event) {
                events1.addLast(event);
              }));

      expect(events1, isEmpty);

      sink1.send(1);
      sink2.send(2);

      expect(events1, isEmpty);

      runTransaction(() => sink.send(sink1.stream.map((value) => 2 * value)));

      expect(events1, isEmpty);

      sink1.send(3);
      sink2.send(4);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(6));
      expect(events1, isEmpty);

      runTransaction(() => sink.send(sink2.stream.map((value) => -2 * value)));

      expect(events1, isEmpty);

      sink1.send(5);
      sink2.send(6);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(-12));
      expect(events1, isEmpty);

      runTransaction(() => sink.send(EventStream.never()));

      expect(events1, isEmpty);

      sink1.send(7);
      sink2.send(8);

      expect(events1, isEmpty);

      subscription1.cancel();

      sink1.close();
      sink2.close();
      sink.close();
    });

    test('Test 12', () {
      final sink = runTransaction(
          () => ValueStateSink<ValueState<int>>(ValueState.constant(0)));

      final events1 = Queue<int>();

      final subscription1 = runTransaction(
          () => ValueState.switchState(sink.state).listen((event) {
                events1.addLast(event);
              }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(0));
      expect(events1, isEmpty);

      subscription1.cancel();

      sink.close();
    });

    test('Test 13', () {
      final sink1 = ValueStateSink<int>(1);
      final sink2 = ValueStateSink<int>(2);

      final events1 = Queue<int>();

      final subscription1 = runTransaction(() =>
          sink1.state.combine(sink2.state, (v1, v2) => v1 + v2).listen((event) {
            events1.addLast(event);
          }));

      subscription1.cancel();

      sink1.close();
      sink2.close();
    });

    test('Test 14', () {
      final sink1 = ValueStateSink<int>(1);

      final events1 = Queue<int>();

      final subscription1 =
          runTransaction(() => sink1.state.toValues().listen((event) {
                events1.addLast(event);
              }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(1));
      expect(events1, isEmpty);

      runTransaction(() {});

      expect(events1, isEmpty);

      subscription1.cancel();

      sink1.close();
    });
  });

  group('OptionalValueState 02', () {
    test('Test 01', () {
      runTransaction(() => OptionalValueState<int>.constantOf(1));
    });

    test('Test 10', () {
      final sink1 = OptionalValueStateSink<int>.of(1);
      final sink2 = OptionalValueStateSink<int>.of(2);

      final events1 = Queue<int>();

      final subscription1 = runTransaction(() => sink1.state
              .combine<Optional<int>, int>(
                  sink2.state, (v1, v2) => v1.value + v2.value)
              .listen((event) {
            events1.addLast(event);
          }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(3));
      expect(events1, isEmpty);

      sink1.sendOptionalOf(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(4));
      expect(events1, isEmpty);

      sink2.sendOptionalOf(3);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(5));
      expect(events1, isEmpty);

      runTransaction(() {
        sink1.sendOptionalOf(4);
        sink2.sendOptionalOf(5);
      });

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(9));
      expect(events1, isEmpty);

      subscription1.cancel();

      sink1.close();
      sink2.close();
    });

    test('Test 12', () {
      final sink = runTransaction(() => ValueStateSink<OptionalValueState<int>>(
          OptionalValueState.constantOf(0)));

      final events1 = Queue<Optional<int>>();

      final subscription1 = runTransaction(
          () => ValueState.switchState(sink.state).listen((event) {
                events1.addLast(event);
              }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(Optional.of(0)));
      expect(events1, isEmpty);

      subscription1.cancel();

      sink.close();
    });
  });

  group('ValueStateSink 03', () {
    test('Test 01', () {
      final sink = ValueStateSink<int>(1);

      expect(sink.isClosed, isFalse);

      sink.send(1);

      sink.close();

      expect(sink.isClosed, isTrue);

      expect(() => sink.send(1), throwsStateError);
    });

    test('Test 02', () {
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

    test('Test 03', () {
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

  group('OptionalValueStateSink 04', () {
    test('Test 01', () {
      final sink = OptionalValueStateSink<int>.of(1);

      expect(sink.isClosed, isFalse);

      sink.send(Optional.of(1));

      sink.close();

      expect(sink.isClosed, isTrue);

      expect(() => sink.send(Optional.of(1)), throwsStateError);
    });

    test('Test 02', () {
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

    test('Test 03', () {
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

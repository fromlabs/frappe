import 'dart:collection';

import 'package:frappe/frappe.dart';
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
      late final ValueStateSink<int> sink;
      late final FrappeReference<ValueState<int>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int>(-1);
        stateReference = sink.state.toReference();
      });

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

      stateReference.dispose();
    });

    test('Test 03', () {
      late final ValueStateSink<int> sink;
      late final FrappeReference<ValueState<int>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int>(0);
        stateReference = sink.state.toReference();
      });

      final events1 = Queue<int>();
      final subscription1 = sink.state.listen((event) {
        events1.addLast(event);
      });

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(0));
      expect(events1, isEmpty);

      subscription1.cancel();

      expect(events1, isEmpty);

      stateReference.dispose();
    });

    test('Test 04', () {
      late final ValueStateSink<int> sink;
      late final FrappeReference<ValueState<int>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int>(-1);
        stateReference = sink.state.toReference();
      });

      final events1 = Queue<int>();
      late final ListenSubscription subscription1;
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

      stateReference.dispose();
    });

    test('Test 05', () {
      late final ValueStateSink<int> sink;
      late final FrappeReference<ValueState<int>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int>(-1);
        stateReference = sink.state.toReference();
      });

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

      stateReference.dispose();
    });

    test('Test 06', () {
      late final ValueStateSink<int> sink;
      late final FrappeReference<ValueState<int>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int>(1);
        stateReference = sink.state.toReference();
      });

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

      stateReference.dispose();
    });

    test('Test 07', () {
      late final ValueStateSink<int> sink;
      late final FrappeReference<ValueState<int>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int>(0);
        stateReference = sink.state.toReference();
      });

      final events1 = Queue<int?>();

      final subscription1 = runTransaction(() => sink.state
              .map<int?>((value) => value.isEven ? value : null)
              .listen((event) {
            events1.addLast(event);
          }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(0));
      expect(events1, isEmpty);

      sink.send(1);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), isNull);
      expect(events1, isEmpty);

      sink.send(4);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(4));
      expect(events1, isEmpty);

      sink.send(6);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(6));
      expect(events1, isEmpty);

      sink.send(7);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), isNull);
      expect(events1, isEmpty);

      subscription1.cancel();

      stateReference.dispose();
    });

    test('Test 08', () {
      late final ValueStateSink<int> sink;
      late final FrappeReference<ValueState<int>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int>(-1);
        stateReference = sink.state.toReference();
      });

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

      stateReference.dispose();
    });

    test('Test 09', () {
      late final ValueStateSink<int> sink;
      late final FrappeReference<ValueState<int>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int>(1);
        stateReference = sink.state.toReference();
      });

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

      stateReference.dispose();
    });

    test('Test 10', () {
      late final ValueStateSink<int> sink1;
      late final ValueStateSink<int> sink2;
      late final FrappeReference<ValueState<int>> stateReference1;
      late final FrappeReference<ValueState<int>> stateReference2;

      runTransaction(() {
        sink1 = ValueStateSink<int>(1);
        sink2 = ValueStateSink<int>(2);
        stateReference1 = sink1.state.toReference();
        stateReference2 = sink2.state.toReference();
      });

      final events1 = Queue<int>();

      final subscription1 = runTransaction(() => sink1.state
              .combine<int, int>(sink2.state, (v1, v2) => v1 + v2)
              .listen((event) {
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

      stateReference1.dispose();
      stateReference2.dispose();
    });

    test('Test 11', () {
      late final ValueStateSink<EventStream<int>> sink;
      late final FrappeReference<ValueState<EventStream<int>>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<EventStream<int>>(EventStream.never());
        stateReference = sink.state.toReference();
      });

      late final EventStreamSink<int> sink1;
      late final EventStreamSink<int> sink2;
      late final FrappeReference<EventStream<int>> stateReference1;
      late final FrappeReference<EventStream<int>> stateReference2;

      runTransaction(() {
        sink1 = EventStreamSink<int>();
        sink2 = EventStreamSink<int>();
        stateReference1 = sink1.stream.toReference();
        stateReference2 = sink2.stream.toReference();
      });

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

      stateReference1.dispose();
      stateReference2.dispose();

      stateReference.dispose();
    });

    test('Test 12', () {
      late final ValueStateSink<ValueState<int>> sink;
      late final FrappeReference<ValueState<ValueState<int>>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<ValueState<int>>(ValueState.constant(0));
        stateReference = sink.state.toReference();
      });

      final events1 = Queue<int>();

      final subscription1 = runTransaction(
          () => ValueState.switchState(sink.state).listen((event) {
                events1.addLast(event);
              }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(0));
      expect(events1, isEmpty);

      subscription1.cancel();

      stateReference.dispose();
    });

    test('Test 13', () {
      late final ValueStateSink<int> sink1;
      late final ValueStateSink<int> sink2;
      late final FrappeReference<ValueState<int>> stateReference1;
      late final FrappeReference<ValueState<int>> stateReference2;

      runTransaction(() {
        sink1 = ValueStateSink<int>(1);
        sink2 = ValueStateSink<int>(2);
        stateReference1 = sink1.state.toReference();
        stateReference2 = sink2.state.toReference();
      });

      final events1 = Queue<int>();

      final subscription1 = runTransaction(() => sink1.state
              .combine<int, int>(sink2.state, (v1, v2) => v1 + v2)
              .listen((event) {
            events1.addLast(event);
          }));

      subscription1.cancel();

      stateReference1.dispose();
      stateReference2.dispose();
    });

    test('Test 14', () {
      late final ValueStateSink<int> sink;
      late final FrappeReference<ValueState<int>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int>(1);
        stateReference = sink.state.toReference();
      });

      final events1 = Queue<int>();

      final subscription1 =
          runTransaction(() => sink.state.toValues().listen((event) {
                events1.addLast(event);
              }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(1));
      expect(events1, isEmpty);

      runTransaction(() {});

      expect(events1, isEmpty);

      subscription1.cancel();

      stateReference.dispose();
    });
  });

  group('OptionalValueState 02', () {
    test('Test 01', () {
      runTransaction(() => ValueState<int?>.constant(1));
    });

    test('Test 10', () {
      late final ValueStateSink<int> sink1;
      late final ValueStateSink<int> sink2;
      late final FrappeReference<ValueState<int>> stateReference1;
      late final FrappeReference<ValueState<int>> stateReference2;

      runTransaction(() {
        sink1 = ValueStateSink<int>(1);
        sink2 = ValueStateSink<int>(2);
        stateReference1 = sink1.state.toReference();
        stateReference2 = sink2.state.toReference();
      });

      final events1 = Queue<int>();

      final subscription1 = runTransaction(() => sink1.state
              .combine<int, int>(sink2.state, (v1, v2) => v1 + v2)
              .listen((event) {
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

      stateReference1.dispose();
      stateReference2.dispose();
    });

    test('Test 12', () {
      late final ValueStateSink<ValueState<int?>> sink;
      late final FrappeReference<ValueState<ValueState<int?>>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<ValueState<int?>>(ValueState.constant(0));
        stateReference = sink.state.toReference();
      });

      final events1 = Queue<int?>();

      final subscription1 = runTransaction(
          () => ValueState.switchState(sink.state).listen((event) {
                events1.addLast(event);
              }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(0));
      expect(events1, isEmpty);

      subscription1.cancel();

      stateReference.dispose();
    });
  });

  group('ValueStateSink 03', () {
    test('Test 01', () {
      late final ValueStateSink<int> sink;
      late final FrappeReference<ValueState<int>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int>(1);
        stateReference = sink.state.toReference();
      });

      expect(sink.isClosed, isFalse);

      sink.send(1);

      stateReference.dispose();

      expect(sink.isClosed, isTrue);

      expect(() => sink.send(1), throwsStateError);
    });

    test('Test 02', () {
      late final ValueStateSink<int> sink;
      late final FrappeReference<ValueState<int>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int>(1);
        stateReference = sink.state.toReference();
      });

      sink.send(1);

      sink.send(2);

      runTransaction(() {
        sink.send(3);
      });

      runTransaction(() {
        sink.send(4);

        expect(() => sink.send(5), throwsUnsupportedError);
      });

      stateReference.dispose();
    });

    test('Test 03', () {
      late final ValueStateSink<int> sink;
      late final FrappeReference<ValueState<int>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int>(1, (newValue, oldValue) => newValue);
        stateReference = sink.state.toReference();
      });

      sink.send(1);

      sink.send(2);

      runTransaction(() {
        sink.send(3);
      });

      runTransaction(() {
        sink.send(4);

        sink.send(5);
      });

      stateReference.dispose();
    });
  });

  group('OptionalValueStateSink 04', () {
    test('Test 01', () {
      late final ValueStateSink<int?> sink;
      late final FrappeReference<ValueState<int?>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int?>(1);
        stateReference = sink.state.toReference();
      });

      expect(sink.isClosed, isFalse);

      sink.send(1);

      stateReference.dispose();

      expect(sink.isClosed, isTrue);

      expect(() => sink.send(1), throwsStateError);
    });

    test('Test 02', () {
      late final ValueStateSink<int?> sink;
      late final FrappeReference<ValueState<int?>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int?>(1);
        stateReference = sink.state.toReference();
      });

      sink.send(1);

      sink.send(2);

      runTransaction(() {
        sink.send(3);
      });

      runTransaction(() {
        sink.send(4);

        expect(() => sink.send(5), throwsUnsupportedError);
      });

      stateReference.dispose();
    });

    test('Test 03', () {
      late final ValueStateSink<int?> sink;
      late final FrappeReference<ValueState<int?>> stateReference;

      runTransaction(() {
        sink = ValueStateSink<int?>(null, (newValue, oldValue) => newValue);
        stateReference = sink.state.toReference();
      });

      sink.send(1);

      sink.send(2);

      runTransaction(() {
        sink.send(3);
      });

      runTransaction(() {
        sink.send(4);

        sink.send(5);
      });

      stateReference.dispose();
    });
  });
}

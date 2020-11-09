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

  group('EventStream', () {
    test('Test 01', () {
      runTransaction(() => EventStream<int>.never());
    });

    test('Test 04', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
      });

      sink.send(0);

      final events1 = Queue<int>();
      final subscription1 = sink.stream.listen((event) {
        events1.addLast(event);
      });

      final events2 = Queue<int>();

      sink.stream.listenOnce((event) {
        events2.addLast(event);
      });

      final events3 = Queue<int>();

      final subscription2 =
          runTransaction(() => sink.stream.once().listen((event) {
                events3.addLast(event);
              }));

      expect(events1, isEmpty);
      expect(events2, isEmpty);
      expect(events3, isEmpty);

      sink.send(1);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(1));
      expect(events1, isEmpty);
      expect(events2, isNotEmpty);
      expect(events2.removeLast(), equals(1));
      expect(events2, isEmpty);
      expect(events3, isNotEmpty);
      expect(events3.removeLast(), equals(1));
      expect(events3, isEmpty);

      sink.send(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);
      expect(events2, isEmpty);
      expect(events3, isEmpty);

      subscription1.cancel();
      subscription2.cancel();

      sink.send(3);

      expect(events1, isEmpty);
      expect(events2, isEmpty);
      expect(events3, isEmpty);

      streamReference.dispose();
    });

    test('Test 05', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
      });

      late final ListenSubscription subscription1;
      late final ListenSubscription subscription2;

      final events1 = Queue<int>();
      final events2 = Queue<int>();
      final events3 = Queue<int>();

      runTransaction(() {
        sink.send(1);

        subscription1 = sink.stream.listen((event) {
          events1.addLast(event);
        });

        sink.stream.listenOnce((event) {
          events2.addLast(event);
        });

        subscription2 = sink.stream.once().listen((event) {
          events3.addLast(event);
        });
      });

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(1));
      expect(events1, isEmpty);
      expect(events2, isNotEmpty);
      expect(events2.removeLast(), equals(1));
      expect(events2, isEmpty);
      expect(events3, isNotEmpty);
      expect(events3.removeLast(), equals(1));
      expect(events3, isEmpty);

      sink.send(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);
      expect(events2, isEmpty);
      expect(events3, isEmpty);

      subscription1.cancel();
      subscription2.cancel();

      sink.send(3);

      expect(events1, isEmpty);
      expect(events2, isEmpty);
      expect(events3, isEmpty);

      streamReference.dispose();
    });

    test('Test 06', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
      });

      expect(
          () => sink.stream.map((value) => 2 * value), throwsUnsupportedError);

      streamReference.dispose();
    });

    test('Test 07', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
      });

      final events1 = Queue<int>();

      final subscription1 = runTransaction(
          () => sink.stream.map((value) => 2 * value).listen((event) {
                events1.addLast(event);
              }));

      expect(events1, isEmpty);

      sink.send(1);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);

      subscription1.cancel();
      streamReference.dispose();
    });

    test('Test 08', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
      });

      final events1 = Queue<int>();

      final subscription1 = runTransaction(() =>
          sink.stream.map((value) => 2 * value).distinct().listen((event) {
            events1.addLast(event);
          }));

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

      streamReference.dispose();
    });

    test('Test 09', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
      });

      final events1 = Queue<int>();

      final subscription1 = runTransaction(() => sink.stream
              .map((value) => 2 * value)
              .where((value) => value % 10 == 0)
              .listen((event) {
            events1.addLast(event);
          }));

      expect(events1, isEmpty);

      sink.send(5);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(10));
      expect(events1, isEmpty);

      sink.send(2);

      expect(events1, isEmpty);

      sink.send(10);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(20));
      expect(events1, isEmpty);

      sink.send(4);

      expect(events1, isEmpty);

      sink.send(8);

      expect(events1, isEmpty);

      subscription1.cancel();

      streamReference.dispose();
    });

    test('Test 10', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
      });

      final events1 = Queue<int?>();

      final subscription1 = runTransaction(() => sink.stream
              .map<int?>((value) => value.isEven ? value : null)
              .listen((event) {
            events1.addLast(event);
          }));

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

      streamReference.dispose();
    });

    test('Test 11', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
      });

      final events1 = Queue<int>();

      final subscription1 = runTransaction(() =>
          sink.stream.map<int>((value) => 2 * value).toState(0).listen((event) {
            events1.addLast(event);
          }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(0));
      expect(events1, isEmpty);

      sink.send(1);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);

      subscription1.cancel();

      streamReference.dispose();
    });

    test('Test 12', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
      });

      final events1 = Queue<int>();

      final subscription1 = runTransaction(() {
        sink.send(1);

        return sink.stream
            .map<int>((value) => 2 * value)
            .toState(0)
            .listen((event) {
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

      streamReference.dispose();
    });

    test('Test 13', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
      });

      sink.send(0);

      final events1 = Queue<int>();
      final subscription1 = sink.stream.listen((event) {
        events1.addLast(event);
      });

      final events2 = Queue<int>();
      final subscriptions = subscription1.append(sink.stream.listen((event) {
        events2.addLast(event);
      }));

      expect(events1, isEmpty);
      expect(events2, isEmpty);

      sink.send(1);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(1));
      expect(events1, isEmpty);
      expect(events2, isNotEmpty);
      expect(events2.removeLast(), equals(1));
      expect(events2, isEmpty);

      sink.send(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);
      expect(events2, isNotEmpty);
      expect(events2.removeLast(), equals(2));
      expect(events2, isEmpty);

      subscriptions.cancel();

      sink.send(3);

      expect(events1, isEmpty);
      expect(events2, isEmpty);

      streamReference.dispose();
    });

    test('Test 14', () {
      late final EventStreamSink<int> sink1;
      late final EventStreamSink<int> sink2;
      late final FrappeReference<EventStream<int>> streamReference1;
      late final FrappeReference<EventStream<int>> streamReference2;

      runTransaction(() {
        sink1 = EventStreamSink<int>();
        sink2 = EventStreamSink<int>();
        streamReference1 = sink1.stream.toReference();
        streamReference2 = sink2.stream.toReference();
      });

      sink1.send(1);
      sink2.send(-1);

      final events1 = Queue<int>();
      final subscription1 = runTransaction(
          () => sink1.stream.orElse(sink2.stream).listen((event) {
                events1.addLast(event);
              }));

      expect(events1, isEmpty);

      sink1.send(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);

      sink2.send(-2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(-2));
      expect(events1, isEmpty);

      runTransaction(() {
        sink1.send(3);
        sink2.send(-3);
      });

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(3));
      expect(events1, isEmpty);

      subscription1.cancel();

      sink1.send(4);
      sink2.send(-4);

      expect(events1, isEmpty);

      streamReference1.dispose();
      streamReference2.dispose();
    });

    test('Test 15', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
      });

      final events1 = Queue<int>();

      final subscription1 = runTransaction(() => sink.stream
              .accumulate<int>(0, (value, state) => value + state)
              .listen((event) {
            events1.addLast(event);
          }));

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(0));
      expect(events1, isEmpty);

      sink.send(1);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(1));
      expect(events1, isEmpty);

      sink.send(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(3));
      expect(events1, isEmpty);

      subscription1.cancel();

      streamReference.dispose();
    });

    test('Test 16', () {
      late final EventStreamSink<int> sink1;
      late final EventStreamSink<int> sink2;
      late final FrappeReference<EventStream<int>> streamReference1;
      late final FrappeReference<EventStream<int>> streamReference2;

      runTransaction(() {
        sink1 = EventStreamSink<int>();
        sink2 = EventStreamSink<int>();
        streamReference1 = sink1.stream.toReference();
        streamReference2 = sink2.stream.toReference();
      });

      sink1.send(1);
      sink2.send(-1);

      final events1 = Queue<int>();
      final subscription1 = runTransaction(
          () => sink1.stream.orElse(sink2.stream).listen((event) {
                events1.addLast(event);
              }));

      expect(events1, isEmpty);

      sink1.send(2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(2));
      expect(events1, isEmpty);

      sink2.send(-2);

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(-2));
      expect(events1, isEmpty);

      runTransaction(() {
        sink1.send(3);
        sink2.send(-3);
      });

      expect(events1, isNotEmpty);
      expect(events1.removeLast(), equals(3));
      expect(events1, isEmpty);

      subscription1.cancel();

      sink1.send(4);
      sink2.send(-4);

      expect(events1, isEmpty);

      streamReference1.dispose();
      streamReference2.dispose();
    });

    test('Test 17', () {
      final events1 = Queue<int>();

      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();

        streamReference =
            sink.stream.map<int>((value) => 2 * value).toReference();
      });

      final subscription1 = runTransaction(() {
        sink.send(1);

        return streamReference.object.listen((event) {
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

      streamReference.dispose();
    });
  });

  group('OptionalEventStream', () {
    test('Test 01', () {
      runTransaction(() => EventStream<int?>.never());
    });
  });

  group('EventStreamSink', () {
    test('Test 01', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
      });

      expect(sink.isClosed, isFalse);

      sink.send(1);

      streamReference.dispose();

      expect(sink.isClosed, isTrue);

      expect(() => sink.send(1), throwsStateError);
    });

    test('Test 02', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>();
        streamReference = sink.stream.toReference();
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

      streamReference.dispose();
    });

    test('Test 03', () {
      late final EventStreamSink<int> sink;
      late final FrappeReference<EventStream<int>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int>((newValue, oldValue) => newValue);
        streamReference = sink.stream.toReference();
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

      streamReference.dispose();
    });
  });

  group('OptionalEventStreamSink', () {
    test('Test 01', () {
      late final EventStreamSink<int?> sink;
      late final FrappeReference<EventStream<int?>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int?>();
        streamReference = sink.stream.toReference();
      });

      expect(sink.isClosed, isFalse);

      sink.send(1);

      streamReference.dispose();

      expect(sink.isClosed, isTrue);

      expect(() => sink.send(1), throwsStateError);
    });

    test('Test 02', () {
      late final EventStreamSink<int?> sink;
      late final FrappeReference<EventStream<int?>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int?>();
        streamReference = sink.stream.toReference();
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

      streamReference.dispose();
    });

    test('Test 03', () {
      late final EventStreamSink<int?> sink;
      late final FrappeReference<EventStream<int?>> streamReference;

      runTransaction(() {
        sink = EventStreamSink<int?>((newValue, oldValue) => newValue);
        streamReference = sink.stream.toReference();
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

      final ref = sink.stream.toReference();

      ref.dispose();

      streamReference.dispose();
    });
  });

/*
  group('EventStreamReference', () {
    test('Test 1', () {
      final streamLink = EventStreamLink<int>();

      final events = Queue<int>();

      final subscription = streamLink.stream.listen(events.addLast);

      final sink = EventStreamSink<int>();

      expect(events, isEmpty);

      sink.send(0);

      expect(events, isEmpty);

      streamLink.connect(sink.stream);

      expect(() => streamLink.connect(sink.stream), throwsStateError);

      expect(events, isEmpty);

      sink.send(1);

      expect(events, isNotEmpty);
      expect(events.removeLast(), equals(1));
      expect(events, isEmpty);

      subscription.cancel();

      sink.close();
    });
  });

  group('OptionalEventStreamReference', () {
    test('Test 1', () {
      final streamLink = OptionalEventStreamLink<int>();

      final events = Queue<Optional<int>>();

      final subscription = streamLink.stream.listen(events.addLast);

      final sink = OptionalEventStreamSink<int>();

      expect(events, isEmpty);

      sink.send(Optional.empty());

      expect(events, isEmpty);

      streamLink.connect(sink.stream);

      expect(() => streamLink.connect(sink.stream), throwsStateError);

      expect(events, isEmpty);

      sink.send(Optional.of(1));

      expect(events, isNotEmpty);
      expect(events.removeLast(), equals(Optional.of(1)));
      expect(events, isEmpty);

      subscription.cancel();

      sink.close();
    });
  });
*/
}

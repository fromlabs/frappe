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
      final sink = EventStreamSink<int>();

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

      sink.close();
    });

    test('Test 05', () {
      final sink = EventStreamSink<int>();

      ListenSubscription subscription1;
      ListenSubscription subscription2;

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

      sink.close();
    });

    test('Test 06', () {
      final sink = EventStreamSink<int>();

      expect(
          () => sink.stream.map((value) => 2 * value), throwsUnsupportedError);

      sink.close();
    });

    test('Test 07', () {
      final sink = EventStreamSink<int>();

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

      sink.close();
    });

    test('Test 08', () {
      final sink = EventStreamSink<int>();

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

      sink.close();
    });

    test('Test 09', () {
      final sink = EventStreamSink<int>();

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

      sink.close();
    });

    test('Test 10', () {
      final sink = EventStreamSink<int>();

      final events1 = Queue<Optional<int>>();

      final subscription1 = runTransaction(() => sink.stream
              .map<Optional<int>>((value) =>
                  value.isEven ? Optional.of(value) : Optional.empty())
              .asOptional()
              .listen((event) {
            events1.addLast(event);
          }));

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

    test('Test 11', () {
      final sink = EventStreamSink<int>();

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

      sink.close();
    });

    test('Test 12', () {
      final sink = EventStreamSink<int>();

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

      sink.close();
    });

    test('Test 13', () {
      final sink = EventStreamSink<int>();

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

      sink.close();
    });

    test('Test 14', () {
      final sink1 = EventStreamSink<int>();
      final sink2 = EventStreamSink<int>();

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

      sink1.close();
      sink2.close();
    });

    test('Test 15', () {
      final sink = EventStreamSink<int>();

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

      sink.close();
    });

    test('Test 16', () {
      final sink1 = EventStreamSink<int>();
      final sink2 = EventStreamSink<int>();

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

      sink1.close();
      sink2.close();
    });

    test('Test 17', () {
      final events1 = Queue<int>();

      EventStreamSink<int> sink;
      FrappeReference<EventStream<int>> streamReference;

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
      sink.close();
    });
  });

  group('OptionalEventStream', () {
    test('Test 01', () {
      runTransaction(() => OptionalEventStream<int>.never());
    });
  });

  group('EventStreamSink', () {
    test('Test 01', () {
      final sink = EventStreamSink<int>();

      expect(sink.isClosed, isFalse);

      sink.send(1);

      sink.close();

      expect(sink.isClosed, isTrue);

      expect(() => sink.send(1), throwsStateError);
    });

    test('Test 02', () {
      final sink = EventStreamSink<int>();

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
      final sink = EventStreamSink<int>((newValue, oldValue) => newValue);

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

  group('OptionalEventStreamSink', () {
    test('Test 01', () {
      final sink = OptionalEventStreamSink<int>();

      expect(sink.isClosed, isFalse);

      sink.send(Optional.of(1));

      sink.close();

      expect(sink.isClosed, isTrue);

      expect(() => sink.send(Optional.of(1)), throwsStateError);
    });

    test('Test 02', () {
      final sink = OptionalEventStreamSink<int>();

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
          OptionalEventStreamSink<int>((newValue, oldValue) => newValue);

      sink.send(Optional.of(1));

      sink.send(Optional.of(2));

      runTransaction(() {
        sink.send(Optional.of(3));
      });

      runTransaction(() {
        sink.send(Optional.of(4));

        sink.send(Optional.of(5));
      });

      final ref = sink.stream.toReference();

      ref.dispose();

      sink.close();
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

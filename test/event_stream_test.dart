import 'dart:collection';

import 'package:frappe/frappe.dart';
import 'package:frappe/src/transaction.dart';
import 'package:optional/optional.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    assertCleanup();
  });

  group('EventStream', () {
    test('Test 1', () {
      EventStream<int>.never();
    });

    test('Test 4', () {
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
      expect(events2, isEmpty);

      subscription1.cancel();

      sink.send(3);

      expect(events1, isEmpty);
      expect(events2, isEmpty);

      sink.close();
    });

    test('Test 5', () {
      final sink = EventStreamSink<int>();

      ListenSubscription subscription1;

      final events1 = Queue<int>();
      final events2 = Queue<int>();

      runTransaction(() {
        sink.send(1);

        subscription1 = sink.stream.listen((event) {
          events1.addLast(event);
        });

        sink.stream.listenOnce((event) {
          events2.addLast(event);
        });
      });

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
      expect(events2, isEmpty);

      subscription1.cancel();

      sink.send(3);

      expect(events1, isEmpty);
      expect(events2, isEmpty);

      sink.close();
    });

    test('Test 6', () {
      final sink = EventStreamSink<int>();

      expect(
          () => sink.stream.map((value) => 2 * value), throwsUnsupportedError);

      sink.close();
    });

    test('Test 7', () {
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

    test('Test 8', () {
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

    test('Test 9', () {
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
  });

  group('OptionalEventStream', () {
    test('Test 1', () {
      OptionalEventStream<int>.never();
    });
  });

  group('EventStreamSink', () {
    test('Test 1', () {
      final sink = EventStreamSink<int>();

      expect(sink.isClosed, isFalse);

      sink.send(1);

      sink.close();

      expect(sink.isClosed, isTrue);

      expect(() => sink.send(1), throwsStateError);
    });

    test('Test 2', () {
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

    test('Test 3', () {
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
    test('Test 1', () {
      final sink = OptionalEventStreamSink<int>();

      expect(sink.isClosed, isFalse);

      sink.send(Optional.of(1));

      sink.close();

      expect(sink.isClosed, isTrue);

      expect(() => sink.send(Optional.of(1)), throwsStateError);
    });

    test('Test 2', () {
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

    test('Test 3', () {
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

      sink.close();
    });
  });

  group('EventStreamReference', () {
    test('Test 1', () {
      final streamReference = EventStreamReference<int>();

      final events = Queue<int>();

      final subscription = streamReference.stream.listen(events.addLast);

      final sink = EventStreamSink<int>();

      expect(events, isEmpty);

      sink.send(0);

      expect(events, isEmpty);

      streamReference.link(sink.stream);

      expect(() => streamReference.link(sink.stream), throwsStateError);

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
      final streamReference = OptionalEventStreamReference<int>();

      final events = Queue<Optional<int>>();

      final subscription = streamReference.stream.listen(events.addLast);

      final sink = OptionalEventStreamSink<int>();

      expect(events, isEmpty);

      sink.send(Optional.empty());

      expect(events, isEmpty);

      streamReference.link(sink.stream);

      expect(() => streamReference.link(sink.stream), throwsStateError);

      expect(events, isEmpty);

      sink.send(Optional.of(1));

      expect(events, isNotEmpty);
      expect(events.removeLast(), equals(Optional.of(1)));
      expect(events, isEmpty);

      subscription.cancel();

      sink.close();
    });
  });
}

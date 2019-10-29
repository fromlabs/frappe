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

      streamReference.link(sink.stream);

      expect(events, isEmpty);

      sink.send(1);

      expect(events, isNotEmpty);
      expect(events.removeLast(), equals(1));
      expect(events, isEmpty);

      subscription.cancel();

      sink.close();
    });
  });
}

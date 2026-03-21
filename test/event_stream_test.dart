import 'package:frappe/frappe.dart';
import 'package:test/test.dart';

void main() {
  late ReactiveScope scope;

  setUp(() {
    scope = ReactiveScope();
  });

  tearDown(() {
    scope.run(() => scope.assertCleanState());
    scope.dispose();
  });

  group('EventStream', () {
    test('never() creates a stream that emits no events', () {
      scope.run(() {
        scope.runTransaction(() {
          EventStream<int>.never();
        });
      });
    });

    test('events before listener are not delivered', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        // Send before listener
        sink.send(0);

        final events = <int>[];
        final sub = scope.runTransaction(() => sink.stream.listen(events.add));

        expect(events, isEmpty);

        sink.send(1);
        expect(events, [1]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('listener receives events sent after attachment', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(() => sink.stream.listen(events.add));

        sink.send(1);
        sink.send(2);
        sink.send(3);

        expect(events, [1, 2, 3]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('listener within same transaction receives events', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;
        final events = <int>[];
        late ListenSubscription sub;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
          sink.send(1);
          sub = sink.stream.listen(events.add);
        });

        expect(events, [1]);

        sink.send(2);
        expect(events, [1, 2]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('listenOnce fires only once', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        scope.runTransaction(() => sink.stream.listenOnce(events.add));

        sink.send(1);
        expect(events, [1]);

        sink.send(2);
        expect(events, [1]); // No new event

        ref.dispose();
      });
    });

    test('once() emits only the first event', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub =
            scope.runTransaction(() => sink.stream.once().listen(events.add));

        sink.send(1);
        expect(events, [1]);

        sink.send(2);
        expect(events, [1]); // Still only first event

        sub.cancel();
        ref.dispose();
      });
    });

    test('cancel stops event delivery', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(() => sink.stream.listen(events.add));

        sink.send(1);
        sub.cancel();
        sink.send(2);

        expect(events, [1]); // 2 not received

        ref.dispose();
      });
    });

    test('map transforms events', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(
            () => sink.stream.map((v) => v * 2).listen(events.add));

        sink.send(1);
        sink.send(3);
        expect(events, [2, 6]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('map outside transaction throws UnsupportedError', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        expect(
            () => sink.stream.map((value) => 2 * value), throwsUnsupportedError);

        ref.dispose();
      });
    });

    test('distinct filters consecutive duplicates', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(() =>
            sink.stream.map((v) => v * 2).distinct().listen(events.add));

        sink.send(1); // 2 - new
        sink.send(1); // 2 - dup
        sink.send(2); // 4 - new
        sink.send(1); // 2 - new (different from 4)
        sink.send(1); // 2 - dup

        expect(events, [2, 4, 2]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('where filters events', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(() => sink.stream
            .map((v) => v * 2)
            .where((v) => v % 10 == 0)
            .listen(events.add));

        sink.send(5); // 10 - matches
        sink.send(2); // 4 - no match
        sink.send(10); // 20 - matches

        expect(events, [10, 20]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('map to nullable type', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int?>[];
        final sub = scope.runTransaction(() => sink.stream
            .map<int?>((v) => v.isEven ? v : null)
            .listen(events.add));

        sink.send(1); // null
        sink.send(4); // 4
        sink.send(6); // 6
        sink.send(7); // null

        expect(events, [null, 4, 6, null]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('toState converts stream to state with initial value', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final values = <int>[];
        final sub = scope.runTransaction(
            () => sink.stream.toState(0).listen(values.add));

        expect(values, [0]); // Initial value

        sink.send(1);
        expect(values, [0, 1]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('toState with prior send uses latest value', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;
        final values = <int>[];
        late ListenSubscription sub;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
          sink.send(1);
          sub = sink.stream.toState(0).listen(values.add);
        });

        expect(values, [1]); // 1, not 0 since send happened before toState listener

        sink.send(2);
        expect(values, [1, 2]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('orElse merges two streams', () {
      scope.run(() {
        late EventStreamSink<int> sink1;
        late EventStreamSink<int> sink2;
        late FrappeReference<EventStream<int>> ref1;
        late FrappeReference<EventStream<int>> ref2;

        scope.runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = EventStreamSink<int>();
          ref1 = sink1.stream.toReference();
          ref2 = sink2.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(
            () => sink1.stream.orElse(sink2.stream).listen(events.add));

        sink1.send(1);
        sink2.send(-1);
        expect(events, [1, -1]);

        sub.cancel();
        ref1.dispose();
        ref2.dispose();
      });
    });

    test('orElse within same transaction prefers first stream', () {
      scope.run(() {
        late EventStreamSink<int> sink1;
        late EventStreamSink<int> sink2;
        late FrappeReference<EventStream<int>> ref1;
        late FrappeReference<EventStream<int>> ref2;

        scope.runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = EventStreamSink<int>();
          ref1 = sink1.stream.toReference();
          ref2 = sink2.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(
            () => sink1.stream.orElse(sink2.stream).listen(events.add));

        // Both send in same transaction
        scope.runTransaction(() {
          sink1.send(3);
          sink2.send(-3);
        });

        // First stream's value wins (default merger)
        expect(events, [3]);

        sub.cancel();
        ref1.dispose();
        ref2.dispose();
      });
    });

    test('accumulate maintains running state', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final values = <int>[];
        final sub = scope.runTransaction(() =>
            sink.stream.accumulate(0, (v, s) => v + s).listen(values.add));

        expect(values, [0]); // Initial

        sink.send(1);
        expect(values, [0, 1]);

        sink.send(2);
        expect(values, [0, 1, 3]); // 1 + 2

        sub.cancel();
        ref.dispose();
      });
    });

    test('append combines subscriptions', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events1 = <int>[];
        final events2 = <int>[];

        final sub = scope.runTransaction(() {
          final s1 = sink.stream.listen(events1.add);
          final s2 = sink.stream.listen(events2.add);
          return s1.append(s2);
        });

        sink.send(1);
        expect(events1, [1]);
        expect(events2, [1]);

        sub.cancel(); // Cancels both
        sink.send(2);
        expect(events1, [1]); // No new events
        expect(events2, [1]);

        ref.dispose();
      });
    });

    test('snapshot combines stream event with state value', () {
      scope.run(() {
        late EventStreamSink<int> eventSink;
        late ValueStateSink<int> stateSink;
        late FrappeReference<EventStream<int>> eventRef;
        late FrappeReference<ValueState<int>> stateRef;

        scope.runTransaction(() {
          eventSink = EventStreamSink<int>();
          stateSink = ValueStateSink<int>(10);
          eventRef = eventSink.stream.toReference();
          stateRef = stateSink.state.toReference();
        });

        final results = <int>[];
        final sub = scope.runTransaction(() =>
            eventSink.stream
                .snapshot(stateSink.state, (e, s) => e + s)
                .listen(results.add));

        eventSink.send(1);
        expect(results, [11]); // 1 + 10

        stateSink.send(20);
        eventSink.send(2);
        expect(results, [11, 22]); // 2 + 20

        sub.cancel();
        eventRef.dispose();
        stateRef.dispose();
      });
    });

    test('gate filters by condition state', () {
      scope.run(() {
        late EventStreamSink<int> eventSink;
        late ValueStateSink<bool> gateSink;
        late FrappeReference<EventStream<int>> eventRef;
        late FrappeReference<ValueState<bool>> gateRef;

        scope.runTransaction(() {
          eventSink = EventStreamSink<int>();
          gateSink = ValueStateSink<bool>(true);
          eventRef = eventSink.stream.toReference();
          gateRef = gateSink.state.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(
            () => eventSink.stream.gate(gateSink.state).listen(events.add));

        eventSink.send(1);
        expect(events, [1]); // Gate open

        gateSink.send(false);
        eventSink.send(2);
        expect(events, [1]); // Gate closed

        gateSink.send(true);
        eventSink.send(3);
        expect(events, [1, 3]); // Gate open again

        sub.cancel();
        eventRef.dispose();
        gateRef.dispose();
      });
    });

    test('mapTo maps to constant', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <String>[];
        final sub = scope.runTransaction(
            () => sink.stream.mapTo('event').listen(events.add));

        sink.send(1);
        sink.send(2);
        expect(events, ['event', 'event']);

        sub.cancel();
        ref.dispose();
      });
    });

    test('whereType filters by type', () {
      scope.run(() {
        late EventStreamSink<Object> sink;
        late FrappeReference<EventStream<Object>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<Object>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(
            () => sink.stream.whereType<int>().listen(events.add));

        sink.send(1);
        sink.send('hello');
        sink.send(2);
        sink.send(3.14);

        expect(events, [1, 2]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('collect with stateful transformation', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <String>[];
        final sub = scope.runTransaction(() => sink.stream
            .collect<String, int>(
                0, (data, state) => Tuple2('${state + data}', state + data))
            .listen(events.add));

        sink.send(1);
        expect(events, ['1']);

        sink.send(2);
        expect(events, ['1', '3']); // 1+2=3

        sub.cancel();
        ref.dispose();
      });
    });

    test('addListenSubscriptionCleaner ties subscription to stream lifetime', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;
        var cleaned = false;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final cleanableSub = ListenSubscription();
        final events = <int>[];

        final sub = scope.runTransaction(() {
          // Create a custom subscription to track cleanup
          final innerSub = sink.stream.listen((e) {
            events.add(e);
          });

          // Wrap with cleaner
          return sink.stream
              .addListenSubscriptionCleaner(innerSub)
              .listen(events.add);
        });

        sink.send(1);
        sub.cancel();
        ref.dispose();
      });
    });
  });

  group('EventStream nullable', () {
    test('EventStream<int?>.never() works', () {
      scope.run(() {
        scope.runTransaction(() {
          EventStream<int?>.never();
        });
      });
    });
  });

  group('EventStreamSink', () {
    test('isClosed after reference disposed', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        expect(sink.isClosed, isFalse);
        ref.dispose();
        expect(sink.isClosed, isTrue);
      });
    });

    test('send after close throws StateError', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        ref.dispose();
        expect(() => sink.send(1), throwsStateError);
      });
    });

    test('multiple sends in same transaction throws without merger', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        // Outside transaction: each send creates its own transaction
        sink.send(1);
        sink.send(2);

        // Inside transaction: second send throws
        expect(() {
          scope.runTransaction(() {
            sink.send(3);
            sink.send(4);
          });
        }, throwsUnsupportedError);

        ref.dispose();
      });
    });

    test('multiple sends with custom merger succeed', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>((newVal, oldVal) => newVal);
          ref = sink.stream.toReference();
        });

        // Multiple sends in same transaction work with merger
        scope.runTransaction(() {
          sink.send(1);
          sink.send(2);
          sink.send(3);
        });

        ref.dispose();
      });
    });
  });

  group('EventStreamSink nullable', () {
    test('isClosed lifecycle', () {
      scope.run(() {
        late EventStreamSink<int?> sink;
        late FrappeReference<EventStream<int?>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int?>();
          ref = sink.stream.toReference();
        });

        expect(sink.isClosed, isFalse);
        ref.dispose();
        expect(sink.isClosed, isTrue);
        expect(() => sink.send(null), throwsStateError);
      });
    });

    test('multiple sends without merger throws', () {
      scope.run(() {
        late EventStreamSink<int?> sink;
        late FrappeReference<EventStream<int?>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int?>();
          ref = sink.stream.toReference();
        });

        expect(() {
          scope.runTransaction(() {
            sink.send(1);
            sink.send(2);
          });
        }, throwsUnsupportedError);

        ref.dispose();
      });
    });

    test('multiple sends with merger succeed', () {
      scope.run(() {
        late EventStreamSink<int?> sink;
        late FrappeReference<EventStream<int?>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int?>((newVal, oldVal) => newVal);
          ref = sink.stream.toReference();
        });

        scope.runTransaction(() {
          sink.send(1);
          sink.send(null);
        });

        ref.dispose();
      });
    });
  });

  group('EventStreamLink', () {
    test('connect links forward-declared stream', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        late ListenSubscription sub;

        scope.runTransaction(() {
          final link = EventStreamLink<int>();
          sub = link.stream.listen(events.add);
          link.connect(sink.stream);
        });

        sink.send(1);
        expect(events, [1]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('double connect throws', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        expect(() {
          scope.runTransaction(() {
            final link = EventStreamLink<int>();
            link.connect(sink.stream);
            link.connect(sink.stream);
          });
        }, throwsStateError);

        ref.dispose();
      });
    });
  });
}

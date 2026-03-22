import 'package:frappe/frappe.dart';
import 'package:test/test.dart';

void main() {
  late FrappeScope scope;

  setUp(() {
    scope = FrappeScope();
  });

  tearDown(() {
    scope.run(() => scope.assertCleanState());
    scope.dispose();
  });

  group('EventStream', () {
    test('never() creates a stream that emits no events', () {
      scope.run(() {
        runTransaction(() {
          EventStream<int>.never();
        });
      });
    });

    test('events before listener are not delivered', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        // Send before listener
        sink.send(0);

        final events = <int>[];
        final sub = runTransaction(() => sink.stream.listen(events.add));

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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => sink.stream.listen(events.add));

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

        runTransaction(() {
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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        runTransaction(() => sink.stream.listenOnce(events.add));

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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => sink.stream.once().listen(events.add));

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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => sink.stream.listen(events.add));

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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        expect(() => sink.stream.map((value) => 2 * value),
            throwsUnsupportedError);

        ref.dispose();
      });
    });

    test('distinct filters consecutive duplicates', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
            () => sink.stream.map((v) => v * 2).distinct().listen(events.add));

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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => sink.stream
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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int?>[];
        final sub = runTransaction(() => sink.stream
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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final values = <int>[];
        final sub =
            runTransaction(() => sink.stream.toState(0).listen(values.add));

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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
          sink.send(1);
          sub = sink.stream.toState(0).listen(values.add);
        });

        expect(values,
            [1]); // 1, not 0 since send happened before toState listener

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

        runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = EventStreamSink<int>();
          ref1 = sink1.stream.toReference();
          ref2 = sink2.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
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

        runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = EventStreamSink<int>();
          ref1 = sink1.stream.toReference();
          ref2 = sink2.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
            () => sink1.stream.orElse(sink2.stream).listen(events.add));

        // Both send in same transaction
        runTransaction(() {
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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(() =>
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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events1 = <int>[];
        final events2 = <int>[];

        final sub = runTransaction(() {
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

        runTransaction(() {
          eventSink = EventStreamSink<int>();
          stateSink = ValueStateSink<int>(10);
          eventRef = eventSink.stream.toReference();
          stateRef = stateSink.state.toReference();
        });

        final results = <int>[];
        final sub = runTransaction(() => eventSink.stream
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

        runTransaction(() {
          eventSink = EventStreamSink<int>();
          gateSink = ValueStateSink<bool>(true);
          eventRef = eventSink.stream.toReference();
          gateRef = gateSink.state.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <String>[];
        final sub =
            runTransaction(() => sink.stream.mapTo('event').listen(events.add));

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

        runTransaction(() {
          sink = EventStreamSink<Object>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <String>[];
        final sub = runTransaction(() => sink.stream
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

    test('addListenSubscriptionCleaner ties subscription to stream lifetime',
        () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];

        final sub = runTransaction(() {
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
        runTransaction(() {
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

        runTransaction(() {
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

        runTransaction(() {
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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        // Outside transaction: each send creates its own transaction
        sink.send(1);
        sink.send(2);

        // Inside transaction: second send throws
        expect(() {
          runTransaction(() {
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

        runTransaction(() {
          sink = EventStreamSink<int>((newVal, oldVal) => newVal);
          ref = sink.stream.toReference();
        });

        // Multiple sends in same transaction work with merger
        runTransaction(() {
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

        runTransaction(() {
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

        runTransaction(() {
          sink = EventStreamSink<int?>();
          ref = sink.stream.toReference();
        });

        expect(() {
          runTransaction(() {
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

        runTransaction(() {
          sink = EventStreamSink<int?>((newVal, oldVal) => newVal);
          ref = sink.stream.toReference();
        });

        runTransaction(() {
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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        late ListenSubscription sub;

        runTransaction(() {
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

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        expect(() {
          runTransaction(() {
            final link = EventStreamLink<int>();
            link.connect(sink.stream);
            link.connect(sink.stream);
          });
        }, throwsStateError);

        ref.dispose();
      });
    });
  });

  group('EventStream additional coverage', () {
    test('cast casts stream type', () {
      scope.run(() {
        late EventStreamSink<num> sink;
        late FrappeReference<EventStream<num>> ref;

        runTransaction(() {
          sink = EventStreamSink<num>();
          ref = sink.stream.toReference();
        });

        final events = <num>[];
        final sub =
            runTransaction(() => sink.stream.cast<num>().listen(events.add));

        sink.send(1);
        sink.send(2.5);

        expect(events, [1, 2.5]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('mapTo chains correctly', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <String>[];
        final sub = runTransaction(
            () => sink.stream.mapTo(10).mapTo('hello').listen(events.add));

        sink.send(99);

        expect(events, ['hello']);

        sub.cancel();
        ref.dispose();
      });
    });

    test('accumulate returns same value still emits', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final values = <int>[];
        // Accumulator ignores the event and returns the current state unchanged
        final sub = runTransaction(() => sink.stream
            .accumulate(0, (event, state) => state)
            .listen(values.add));

        expect(values, [0]); // Initial

        sink.send(1);
        expect(values, [0, 0]); // Accumulator returns state=0, still emits

        sink.send(2);
        expect(values, [0, 0, 0]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('accumulateLazy provider called exactly once', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        var providerCallCount = 0;
        final values = <int>[];
        final sub = runTransaction(
            () => sink.stream.accumulateLazy(LazyValue.provide(() {
                  providerCallCount++;
                  return 0;
                }), (int acc, int e) => acc + e).listen(values.add));

        sink.send(1);
        sink.send(2);
        sink.send(3);

        expect(providerCallCount, 1);

        sub.cancel();
        ref.dispose();
      });
    });

    test('gate starts closed stays closed', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() =>
            sink.stream.gate(ValueState.constant(false)).listen(events.add));

        sink.send(1);
        sink.send(2);
        sink.send(3);

        expect(events, isEmpty);

        sub.cancel();
        ref.dispose();
      });
    });

    test('gate opens mid-stream', () {
      scope.run(() {
        late EventStreamSink<int> eventSink;
        late ValueStateSink<bool> gateSink;
        late FrappeReference<EventStream<int>> eventRef;
        late FrappeReference<ValueState<bool>> gateRef;

        runTransaction(() {
          eventSink = EventStreamSink<int>();
          gateSink = ValueStateSink<bool>(false);
          eventRef = eventSink.stream.toReference();
          gateRef = gateSink.state.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
            () => eventSink.stream.gate(gateSink.state).listen(events.add));

        eventSink.send(1);
        eventSink.send(2);
        expect(events, isEmpty); // Gate closed

        gateSink.send(true);
        eventSink.send(3);
        eventSink.send(4);
        expect(events, [3, 4]); // Only events after gate opened

        sub.cancel();
        eventRef.dispose();
        gateRef.dispose();
      });
    });

    test('snapshot reads current state value', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final results = <int>[];
        final sub = runTransaction(() => sink.stream
            .snapshot(ValueState.constant(100), (event, state) => event + state)
            .listen(results.add));

        sink.send(1);

        expect(results, [101]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('once with multiple listeners all receive first event', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events1 = <int>[];
        final events2 = <int>[];
        late ListenSubscription sub1;
        late ListenSubscription sub2;

        runTransaction(() {
          final onceStream = sink.stream.once();
          sub1 = onceStream.listen(events1.add);
          sub2 = onceStream.listen(events2.add);
        });

        sink.send(1);

        expect(events1, [1]);
        expect(events2, [1]);

        sink.send(2);

        expect(events1, [1]); // No second event
        expect(events2, [1]);

        sub1.cancel();
        sub2.cancel();
        ref.dispose();
      });
    });

    test('orElse first stream is never', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() =>
            EventStream<int>.never().orElse(sink.stream).listen(events.add));

        sink.send(1);
        sink.send(2);

        expect(events, [1, 2]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('orElses simultaneous emissions use merger', () {
      scope.run(() {
        late EventStreamSink<int> sink1;
        late EventStreamSink<int> sink2;
        late FrappeReference<EventStream<int>> ref1;
        late FrappeReference<EventStream<int>> ref2;

        runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = EventStreamSink<int>();
          ref1 = sink1.stream.toReference();
          ref2 = sink2.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => EventStream.merges(
              [sink1.stream, sink2.stream],
              (a, b) => a + b,
            ).listen(events.add));

        runTransaction(() {
          sink1.send(3);
          sink2.send(7);
        });

        expect(events, [10]); // 3 + 7

        sub.cancel();
        ref1.dispose();
        ref2.dispose();
      });
    });

    test('listenOnce listener error is caught', () {
      final errors = <Object>[];
      final errorScope =
          FrappeScope(onError: (error, _) => errors.add(error));
      errorScope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        runTransaction(
            () => sink.stream.listenOnce((_) => throw Exception('test error')));

        // Should not propagate - error is routed to scope's onError
        sink.send(1);
        expect(errors, hasLength(1));
        expect(errors.first, isA<Exception>());

        ref.dispose();
      });
      errorScope.run(() => errorScope.assertCleanState());
      errorScope.dispose();
    });

    test('cast to supertype', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <num>[];
        final sub =
            runTransaction(() => sink.stream.cast<num>().listen(events.add));

        sink.send(42);

        expect(events, [42]);
        expect(events.first, isA<num>());

        sub.cancel();
        ref.dispose();
      });
    });

    test('mapToNull emits null', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int?>[];
        final sub =
            runTransaction(() => sink.stream.mapToNull().listen(events.add));

        sink.send(42);

        expect(events, [null]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('whereType filters and casts', () {
      scope.run(() {
        late EventStreamSink<Object> sink;
        late FrappeReference<EventStream<Object>> ref;

        runTransaction(() {
          sink = EventStreamSink<Object>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
            () => sink.stream.whereType<int>().listen(events.add));

        sink.send(1);
        sink.send('hello');
        sink.send(2);

        expect(events, [1, 2]);

        sub.cancel();
        ref.dispose();
      });
    });
  });

  group('EventStream switchMap', () {
    test('switches to inner stream from each event', () {
      scope.run(() {
        late EventStreamSink<int> selectorSink;
        late EventStreamSink<int> dataSink1;
        late EventStreamSink<int> dataSink2;
        late FrappeReference<EventStream<int>> selectorRef;
        late FrappeReference<EventStream<int>> dataRef1;
        late FrappeReference<EventStream<int>> dataRef2;

        runTransaction(() {
          selectorSink = EventStreamSink<int>();
          dataSink1 = EventStreamSink<int>();
          dataSink2 = EventStreamSink<int>();
          selectorRef = selectorSink.stream.toReference();
          dataRef1 = dataSink1.stream.toReference();
          dataRef2 = dataSink2.stream.toReference();
        });

        final events = <int>[];
        final streams = [dataSink1.stream, dataSink2.stream];

        final sub = runTransaction(() => selectorSink.stream
            .switchMap((idx) => streams[idx])
            .listen(events.add));

        // No inner stream yet — data events are ignored
        dataSink1.send(100);
        expect(events, isEmpty);

        // Switch to stream 0
        selectorSink.send(0);
        dataSink1.send(1);
        dataSink2.send(99);
        expect(events, [1]); // Only stream 0

        // Switch to stream 1
        selectorSink.send(1);
        dataSink1.send(88);
        dataSink2.send(2);
        expect(events, [1, 2]); // Now stream 1

        sub.cancel();
        selectorRef.dispose();
        dataRef1.dispose();
        dataRef2.dispose();
      });
    });

    test('switchMap with mapper that transforms', () {
      scope.run(() {
        late EventStreamSink<int> multiplierSink;
        late EventStreamSink<int> dataSink;
        late FrappeReference<EventStream<int>> multiplierRef;
        late FrappeReference<EventStream<int>> dataRef;

        runTransaction(() {
          multiplierSink = EventStreamSink<int>();
          dataSink = EventStreamSink<int>();
          multiplierRef = multiplierSink.stream.toReference();
          dataRef = dataSink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => multiplierSink.stream
            .switchMap((m) => dataSink.stream.map((v) => v * m))
            .listen(events.add));

        // Set multiplier to 2
        multiplierSink.send(2);
        dataSink.send(5);
        expect(events, [10]); // 5 * 2

        // Change multiplier to 3
        multiplierSink.send(3);
        dataSink.send(5);
        expect(events, [10, 15]); // 5 * 3

        sub.cancel();
        multiplierRef.dispose();
        dataRef.dispose();
      });
    });

    test('switchMap without initial event emits nothing', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <String>[];
        final sub = runTransaction(() => sink.stream
            .switchMap((_) => EventStream<String>.never())
            .listen(events.add));

        expect(events, isEmpty);

        sub.cancel();
        ref.dispose();
      });
    });
  });
}

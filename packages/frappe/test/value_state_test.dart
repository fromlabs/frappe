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

  group('ValueState', () {
    test('constant has fixed value', () {
      scope.run(() {
        runTransaction(() {
          final state = ValueState.constant(42);
          expect(state.getValue(), 42);
        });
      });
    });

    test('toUpdates emits only changes, not initial', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(-1);
          ref = sink.state.toReference();
        });

        sink.send(0);

        final updates = <int>[];
        final sub =
            runTransaction(() => sink.state.toUpdates().listen(updates.add));

        expect(updates, isEmpty); // No initial value

        sink.send(1);
        expect(updates, [1]);

        sink.send(2);
        expect(updates, [1, 2]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('listen delivers current value immediately', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(-1);
          ref = sink.state.toReference();
        });

        sink.send(0);

        final values = <int>[];
        final sub = runTransaction(() => sink.state.listen(values.add));

        expect(values, [0]); // Current value delivered

        sub.cancel();
        ref.dispose();
      });
    });

    test('listen within transaction receives updated value', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;
        final values = <int>[];
        late ListenSubscription sub;

        runTransaction(() {
          sink = ValueStateSink<int>(-1);
          ref = sink.state.toReference();
          sink.send(0);
          sub = sink.state.listen(values.add);
        });

        expect(values, [0]); // Receives updated value, not -1

        sub.cancel();
        ref.dispose();
      });
    });

    test('listen outside transaction receives current value', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(-1);
          ref = sink.state.toReference();
        });

        sink.send(0);

        final values = <int>[];
        final sub = sink.state.listen(values.add);

        expect(values, [0]); // Current value

        sub.cancel();
        ref.dispose();
      });
    });

    test('map transforms state values', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(-1);
          ref = sink.state.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(
            () => sink.state.map((v) => v * 2).listen(values.add));

        expect(values, [-2]); // Transformed initial

        sink.send(1);
        expect(values, [-2, 2]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('map to nullable type', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        final values = <int?>[];
        final sub = runTransaction(() => sink.state
            .map<int?>((v) => v.isEven ? v : null)
            .listen(values.add));

        expect(values, [0]); // 0 is even

        sink.send(1);
        expect(values, [0, null]); // 1 is odd → null

        sink.send(4);
        expect(values, [0, null, 4]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('distinct filters consecutive duplicates', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(-1);
          ref = sink.state.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(
            () => sink.state.map((v) => v * 2).distinct().listen(values.add));

        expect(values, [-2]); // Initial

        sink.send(1); // 2 - new
        sink.send(1); // 2 - dup, filtered
        sink.send(2); // 4 - new
        sink.send(1); // 2 - new (after 4)
        sink.send(1); // 2 - dup

        expect(values, [-2, 2, 4, 2]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('combine two states', () {
      scope.run(() {
        late ValueStateSink<int> sink1;
        late ValueStateSink<int> sink2;
        late FrappeReference<ValueState<int>> ref1;
        late FrappeReference<ValueState<int>> ref2;

        runTransaction(() {
          sink1 = ValueStateSink<int>(1);
          sink2 = ValueStateSink<int>(2);
          ref1 = sink1.state.toReference();
          ref2 = sink2.state.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(() => sink1.state
            .combine(sink2.state, (v1, v2) => v1 + v2)
            .listen(values.add));

        expect(values, [3]); // 1 + 2

        sink1.send(2);
        expect(values, [3, 4]); // 2 + 2

        sink2.send(3);
        expect(values, [3, 4, 5]); // 2 + 3

        // Both in same transaction
        runTransaction(() {
          sink1.send(4);
          sink2.send(5);
        });
        expect(values, [3, 4, 5, 9]); // 4 + 5, one event

        sub.cancel();
        ref1.dispose();
        ref2.dispose();
      });
    });

    test('combine with no listener and cleanup', () {
      scope.run(() {
        late ValueStateSink<int> sink1;
        late ValueStateSink<int> sink2;
        late FrappeReference<ValueState<int>> ref1;
        late FrappeReference<ValueState<int>> ref2;

        runTransaction(() {
          sink1 = ValueStateSink<int>(1);
          sink2 = ValueStateSink<int>(2);
          ref1 = sink1.state.toReference();
          ref2 = sink2.state.toReference();
        });

        final sub = runTransaction(() => sink1.state
            .combine(sink2.state, (v1, v2) => v1 + v2)
            .listen((_) {}));

        sub.cancel();
        ref1.dispose();
        ref2.dispose();
      });
    });

    test('ValueStateLink forward-declared dependency', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        final values = <int>[];
        late ListenSubscription sub;

        runTransaction(() {
          final link = ValueStateLink<int>();
          sub = link.state.listen(values.add);
          link.connect(sink.state);
        });

        expect(values, [0]); // Current value via link

        sink.send(1);
        expect(values, [0, 1]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('switchStream switches between event streams', () {
      scope.run(() {
        late EventStreamSink<int> sink1;
        late EventStreamSink<int> sink2;
        late ValueStateSink<EventStream<int>> switchSink;
        late FrappeReference<EventStream<int>> ref1;
        late FrappeReference<EventStream<int>> ref2;
        late FrappeReference<ValueState<EventStream<int>>> switchRef;

        runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = EventStreamSink<int>();
          ref1 = sink1.stream.toReference();
          ref2 = sink2.stream.toReference();
          switchSink =
              ValueStateSink<EventStream<int>>(EventStream<int>.never());
          switchRef = switchSink.state.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
            () => ValueState.switchStream(switchSink.state).listen(events.add));

        // Initial: never → no events
        sink1.send(1);
        sink2.send(2);
        expect(events, isEmpty);

        // Switch to sink1's stream with map
        runTransaction(() => switchSink.send(sink1.stream.map((v) => v * 2)));
        sink1.send(3);
        expect(events, [6]); // 3 * 2

        // Switch to sink2's stream
        runTransaction(() => switchSink.send(sink2.stream.map((v) => v * -2)));
        sink2.send(6);
        expect(events, [6, -12]); // 6 * -2

        // Switch to never
        runTransaction(() => switchSink.send(EventStream<int>.never()));
        sink1.send(10);
        sink2.send(20);
        expect(events, [6, -12]); // No more events

        sub.cancel();
        ref1.dispose();
        ref2.dispose();
        switchRef.dispose();
      });
    });

    test('switchState unwraps nested state', () {
      scope.run(() {
        final values = <int>[];
        late ListenSubscription sub;

        runTransaction(() {
          final innerState = ValueState.constant(0);
          final outerState = ValueState.constant(innerState);
          sub = ValueState.switchState(outerState).listen(values.add);
        });

        expect(values, [0]); // Unwrapped value

        sub.cancel();
      });
    });

    test('toValues includes initial, toUpdates does not', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        final allValues = <int>[];
        final updates = <int>[];

        late ListenSubscription sub1;
        late ListenSubscription sub2;

        runTransaction(() {
          sub1 = sink.state.toValues().listen(allValues.add);
          sub2 = sink.state.toUpdates().listen(updates.add);
        });

        expect(allValues, [0]); // Initial value
        expect(updates, isEmpty); // No initial

        // Empty transaction shouldn't trigger updates
        runTransaction(() {});

        expect(allValues, [0]); // Unchanged
        expect(updates, isEmpty); // Unchanged

        sink.send(1);
        expect(allValues, [0, 1]);
        expect(updates, [1]);

        sub1.cancel();
        sub2.cancel();
        ref.dispose();
      });
    });
  });

  group('ValueState nullable', () {
    test('ValueState<int?>.constant works', () {
      scope.run(() {
        runTransaction(() {
          final state = ValueState<int?>.constant(null);
          expect(state.getValue(), isNull);
        });
      });
    });

    test('combine with nullable states', () {
      scope.run(() {
        late ValueStateSink<int?> sink1;
        late ValueStateSink<int?> sink2;
        late FrappeReference<ValueState<int?>> ref1;
        late FrappeReference<ValueState<int?>> ref2;

        runTransaction(() {
          sink1 = ValueStateSink<int?>(1);
          sink2 = ValueStateSink<int?>(2);
          ref1 = sink1.state.toReference();
          ref2 = sink2.state.toReference();
        });

        final values = <int?>[];
        final sub = runTransaction(() => sink1.state
            .combine<int?, int?>(sink2.state, (v1, v2) => (v1 ?? 0) + (v2 ?? 0))
            .listen(values.add));

        expect(values, [3]);

        sub.cancel();
        ref1.dispose();
        ref2.dispose();
      });
    });
  });

  group('ValueStateSink', () {
    test('isClosed after reference disposed', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        expect(sink.isClosed, isFalse);
        ref.dispose();
        expect(sink.isClosed, isTrue);
      });
    });

    test('send after close throws StateError', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        ref.dispose();
        expect(() => sink.send(1), throwsStateError);
      });
    });

    test('multiple sends in same transaction throws without merger', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
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
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0, (a, b) => a);
          ref = sink.state.toReference();
        });

        runTransaction(() {
          sink.send(1);
          sink.send(2);
          sink.send(3);
        });

        ref.dispose();
      });
    });
  });

  group('ValueStateSink nullable', () {
    test('lifecycle', () {
      scope.run(() {
        late ValueStateSink<int?> sink;
        late FrappeReference<ValueState<int?>> ref;

        runTransaction(() {
          sink = ValueStateSink<int?>(null);
          ref = sink.state.toReference();
        });

        expect(sink.isClosed, isFalse);
        ref.dispose();
        expect(sink.isClosed, isTrue);
        expect(() => sink.send(null), throwsStateError);
      });
    });
  });

  group('ValueState.switchMapState', () {
    test('maps and switches to inner states', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(1);
          ref = sink.state.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(() => sink.state
            .switchMapState((v) => ValueState.constant(v * 10))
            .listen(values.add));

        expect(values, [10]);

        sink.send(2);
        expect(values, [10, 20]);

        sub.cancel();
        ref.dispose();
      });
    });
  });

  group('ValueState.switchMapStream', () {
    test('maps and switches to inner streams', () {
      scope.run(() {
        late ValueStateSink<int> selectorSink;
        late EventStreamSink<int> dataSink;
        late FrappeReference<ValueState<int>> selectorRef;
        late FrappeReference<EventStream<int>> dataRef;

        runTransaction(() {
          selectorSink = ValueStateSink<int>(1);
          dataSink = EventStreamSink<int>();
          selectorRef = selectorSink.state.toReference();
          dataRef = dataSink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => selectorSink.state
            .switchMapStream(
                (selector) => dataSink.stream.map((v) => v * selector))
            .listen(events.add));

        dataSink.send(5);
        expect(events, [5]); // 5 * 1

        selectorSink.send(2);
        dataSink.send(5);
        expect(events, [5, 10]); // 5 * 2

        sub.cancel();
        selectorRef.dispose();
        dataRef.dispose();
      });
    });
  });

  group('ValueState additional coverage', () {
    test('combines with single state', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(3);
          ref = sink.state.toReference();
        });

        final values = <int>[];
        final sub =
            runTransaction(() => ValueState.combines<int>([sink.state], (vals) {
                  final it = vals.iterator;
                  it.moveNext();
                  return it.current * 10;
                }).listen(values.add));

        expect(values, [30]); // 3 * 10

        sink.send(5);
        expect(values, [30, 50]); // 5 * 10

        sub.cancel();
        ref.dispose();
      });
    });

    test('combines states change simultaneously', () {
      scope.run(() {
        late ValueStateSink<int> sink1;
        late ValueStateSink<int> sink2;
        late FrappeReference<ValueState<int>> ref1;
        late FrappeReference<ValueState<int>> ref2;

        runTransaction(() {
          sink1 = ValueStateSink<int>(1);
          sink2 = ValueStateSink<int>(2);
          ref1 = sink1.state.toReference();
          ref2 = sink2.state.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(
            () => ValueState.combines<int>([sink1.state, sink2.state], (vals) {
                  final it = vals.iterator;
                  it.moveNext();
                  final v1 = it.current as int;
                  it.moveNext();
                  final v2 = it.current as int;
                  return v1 + v2;
                }).listen(values.add));

        expect(values, [3]); // 1 + 2

        // Both change in the same transaction
        runTransaction(() {
          sink1.send(10);
          sink2.send(20);
        });
        expect(values, [3, 30]); // 10 + 20, single combined event

        sub.cancel();
        ref1.dispose();
        ref2.dispose();
      });
    });

    test('switchStream with same stream instance is no-op', () {
      scope.run(() {
        late EventStreamSink<int> dataSink;
        late ValueStateSink<EventStream<int>> switchSink;
        late FrappeReference<EventStream<int>> dataRef;
        late FrappeReference<ValueState<EventStream<int>>> switchRef;

        runTransaction(() {
          dataSink = EventStreamSink<int>();
          dataRef = dataSink.stream.toReference();
          switchSink = ValueStateSink<EventStream<int>>(dataSink.stream);
          switchRef = switchSink.state.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
            () => ValueState.switchStream(switchSink.state).listen(events.add));

        dataSink.send(1);
        expect(events, [1]);

        // Send the same stream instance again
        runTransaction(() => switchSink.send(dataSink.stream));

        dataSink.send(2);
        expect(events, [1, 2]); // Still receives events

        // Send the same stream instance yet again
        runTransaction(() => switchSink.send(dataSink.stream));

        dataSink.send(3);
        expect(events, [1, 2, 3]); // Still working

        sub.cancel();
        dataRef.dispose();
        switchRef.dispose();
      });
    });

    test('switchMapState with constant mapper', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(1);
          ref = sink.state.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(() => sink.state
            .switchMapState((_) => ValueState.constant(42))
            .listen(values.add));

        expect(values, [42]);

        sink.send(2);
        expect(values, [42, 42]); // Always 42

        sink.send(99);
        expect(values, [42, 42, 42]); // Still always 42

        sub.cancel();
        ref.dispose();
      });
    });

    test('toValues called after send reflects latest', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        sink.send(1);

        final values = <int>[];
        final sub =
            runTransaction(() => sink.state.toValues().listen(values.add));

        expect(values, [1]); // Reflects latest value after send

        sub.cancel();
        ref.dispose();
      });
    });

    test('multiple toValues each deliver initial', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(5);
          ref = sink.state.toReference();
        });

        final values1 = <int>[];
        final values2 = <int>[];

        final sub1 =
            runTransaction(() => sink.state.toValues().listen(values1.add));
        final sub2 =
            runTransaction(() => sink.state.toValues().listen(values2.add));

        expect(values1, [5]); // First listener receives initial
        expect(values2, [5]); // Second listener also receives initial

        sub1.cancel();
        sub2.cancel();
        ref.dispose();
      });
    });

    test('toUpdates with no updates produces empty', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        final updates = <int>[];
        final sub =
            runTransaction(() => sink.state.toUpdates().listen(updates.add));

        // No send calls
        expect(updates, isEmpty);

        sub.cancel();
        ref.dispose();
      });
    });

    test('ValueStateLink state before connect uses lazy', () {
      scope.run(() {
        late ValueStateLink<int> link;
        late FrappeReference<ValueState<int>> linkRef;

        runTransaction(() {
          link = ValueStateLink<int>();
          linkRef = link.state.toReference();
        });

        // Before connect, getValue should throw StateError
        expect(() => runTransaction(() => link.state.getValue()),
            throwsStateError);

        expect(link.isConnected, isFalse);

        // Now connect and verify it works
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> sinkRef;

        runTransaction(() {
          sink = ValueStateSink<int>(10);
          sinkRef = sink.state.toReference();
          link.connect(sink.state);
        });

        expect(link.isConnected, isTrue);

        final values = <int>[];
        final sub = runTransaction(() => link.state.listen(values.add));

        expect(values, [10]);

        sink.send(20);
        expect(values, [10, 20]);

        sub.cancel();
        linkRef.dispose();
        sinkRef.dispose();
      });
    });

    test('distinct with default equality', () {
      scope.run(() {
        late ValueStateSink<String> sink;
        late FrappeReference<ValueState<String>> ref;

        runTransaction(() {
          sink = ValueStateSink<String>('a');
          ref = sink.state.toReference();
        });

        final values = <String>[];
        final sub =
            runTransaction(() => sink.state.distinct().listen(values.add));

        expect(values, ['a']); // Initial value

        sink.send('a'); // Duplicate, filtered
        expect(values, ['a']);

        sink.send('b'); // New value
        expect(values, ['a', 'b']);

        sink.send('b'); // Duplicate, filtered
        expect(values, ['a', 'b']);

        sub.cancel();
        ref.dispose();
      });
    });

    test('switchMapStream maps and switches correctly', () {
      scope.run(() {
        late ValueStateSink<int> selectorSink;
        late EventStreamSink<int> dataSink;
        late FrappeReference<ValueState<int>> selectorRef;
        late FrappeReference<EventStream<int>> dataRef;

        runTransaction(() {
          selectorSink = ValueStateSink<int>(1);
          dataSink = EventStreamSink<int>();
          selectorRef = selectorSink.state.toReference();
          dataRef = dataSink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => selectorSink.state
            .switchMapStream(
                (selector) => dataSink.stream.map((v) => v * selector))
            .listen(events.add));

        // With selector=1, data*1
        dataSink.send(3);
        expect(events, [3]); // 3 * 1

        dataSink.send(7);
        expect(events, [3, 7]); // 7 * 1

        // Switch to selector=2
        selectorSink.send(2);
        dataSink.send(3);
        expect(events, [3, 7, 6]); // 3 * 2

        dataSink.send(5);
        expect(events, [3, 7, 6, 10]); // 5 * 2

        sub.cancel();
        selectorRef.dispose();
        dataRef.dispose();
      });
    });

    test('combine updates when either state changes', () {
      scope.run(() {
        late ValueStateSink<String> sink1;
        late ValueStateSink<String> sink2;
        late FrappeReference<ValueState<String>> ref1;
        late FrappeReference<ValueState<String>> ref2;

        runTransaction(() {
          sink1 = ValueStateSink<String>('hello');
          sink2 = ValueStateSink<String>('world');
          ref1 = sink1.state.toReference();
          ref2 = sink2.state.toReference();
        });

        final values = <String>[];
        final sub = runTransaction(() => sink1.state
            .combine(sink2.state, (v1, v2) => '$v1 $v2')
            .listen(values.add));

        expect(values, ['hello world']); // Initial

        // Change only the first state
        sink1.send('hi');
        expect(values, ['hello world', 'hi world']);

        // Change only the second state
        sink2.send('there');
        expect(values, ['hello world', 'hi world', 'hi there']);

        sub.cancel();
        ref1.dispose();
        ref2.dispose();
      });
    });
  });

  group('ValueState.loop', () {
    test('creates self-referential state with accumulation', () {
      scope.run(() {
        late EventStreamSink<void> incrementSink;
        late FrappeReference<EventStream<void>> incrementRef;

        runTransaction(() {
          incrementSink = EventStreamSink<void>();
          incrementRef = incrementSink.stream.toReference();
        });

        // Build a counter that snapshots its own value and increments it.
        // This is the canonical use case for loop: the state references
        // itself via the forward-declared `self` parameter.
        final values = <int>[];
        final sub = runTransaction(() {
          final counter = ValueState.loop<int>((self) =>
              incrementSink.stream.snapshot(self, (_, n) => n + 1).toState(0));
          return counter.listen(values.add);
        });

        expect(values, [0]); // Initial value

        incrementSink.send(null);
        expect(values, [0, 1]); // First increment

        incrementSink.send(null);
        expect(values, [0, 1, 2]); // Second increment

        incrementSink.send(null);
        expect(values, [0, 1, 2, 3]); // Third increment

        sub.cancel();
        incrementRef.dispose();
      });
    });

    test('initial value comes from builder toState', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        // The initial value is determined by the toState argument inside
        // the builder, not by any external source.
        late ValueState<int> loopState;
        final values = <int>[];
        final sub = runTransaction(() {
          loopState = ValueState.loop<int>((self) =>
              sink.stream.snapshot(self, (event, current) => event).toState(42));
          return loopState.listen(values.add);
        });

        // The initial value should be 42 as passed to toState
        expect(values, [42]);
        expect(loopState.getValue(), 42);

        // After sending an event, the value updates
        sink.send(100);
        expect(values, [42, 100]);
        expect(loopState.getValue(), 100);

        sub.cancel();
        ref.dispose();
      });
    });
  });
}

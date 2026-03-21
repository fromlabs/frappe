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

  group('ValueState', () {
    test('constant has fixed value', () {
      scope.run(() {
        scope.runTransaction(() {
          final state = ValueState.constant(42);
          expect(state.getValue(), 42);
        });
      });
    });

    test('toUpdates emits only changes, not initial', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        scope.runTransaction(() {
          sink = ValueStateSink<int>(-1);
          ref = sink.state.toReference();
        });

        sink.send(0);

        final updates = <int>[];
        final sub =
            scope.runTransaction(() => sink.state.toUpdates().listen(updates.add));

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

        scope.runTransaction(() {
          sink = ValueStateSink<int>(-1);
          ref = sink.state.toReference();
        });

        sink.send(0);

        final values = <int>[];
        final sub = scope.runTransaction(() => sink.state.listen(values.add));

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

        scope.runTransaction(() {
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

        scope.runTransaction(() {
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

        scope.runTransaction(() {
          sink = ValueStateSink<int>(-1);
          ref = sink.state.toReference();
        });

        final values = <int>[];
        final sub = scope.runTransaction(
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

        scope.runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        final values = <int?>[];
        final sub = scope.runTransaction(() =>
            sink.state.map<int?>((v) => v.isEven ? v : null).listen(values.add));

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

        scope.runTransaction(() {
          sink = ValueStateSink<int>(-1);
          ref = sink.state.toReference();
        });

        final values = <int>[];
        final sub = scope.runTransaction(() =>
            sink.state.map((v) => v * 2).distinct().listen(values.add));

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

        scope.runTransaction(() {
          sink1 = ValueStateSink<int>(1);
          sink2 = ValueStateSink<int>(2);
          ref1 = sink1.state.toReference();
          ref2 = sink2.state.toReference();
        });

        final values = <int>[];
        final sub = scope.runTransaction(() =>
            sink1.state.combine(sink2.state, (v1, v2) => v1 + v2).listen(values.add));

        expect(values, [3]); // 1 + 2

        sink1.send(2);
        expect(values, [3, 4]); // 2 + 2

        sink2.send(3);
        expect(values, [3, 4, 5]); // 2 + 3

        // Both in same transaction
        scope.runTransaction(() {
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

        scope.runTransaction(() {
          sink1 = ValueStateSink<int>(1);
          sink2 = ValueStateSink<int>(2);
          ref1 = sink1.state.toReference();
          ref2 = sink2.state.toReference();
        });

        final sub = scope.runTransaction(() =>
            sink1.state.combine(sink2.state, (v1, v2) => v1 + v2).listen((_) {}));

        sub.cancel();
        ref1.dispose();
        ref2.dispose();
      });
    });

    test('ValueStateLink forward-declared dependency', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        scope.runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        final values = <int>[];
        late ListenSubscription sub;

        scope.runTransaction(() {
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

        scope.runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = EventStreamSink<int>();
          ref1 = sink1.stream.toReference();
          ref2 = sink2.stream.toReference();
          switchSink =
              ValueStateSink<EventStream<int>>(EventStream<int>.never());
          switchRef = switchSink.state.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(() =>
            ValueState.switchStream(switchSink.state).listen(events.add));

        // Initial: never → no events
        sink1.send(1);
        sink2.send(2);
        expect(events, isEmpty);

        // Switch to sink1's stream with map
        scope.runTransaction(
            () => switchSink.send(sink1.stream.map((v) => v * 2)));
        sink1.send(3);
        expect(events, [6]); // 3 * 2

        // Switch to sink2's stream
        scope.runTransaction(
            () => switchSink.send(sink2.stream.map((v) => v * -2)));
        sink2.send(6);
        expect(events, [6, -12]); // 6 * -2

        // Switch to never
        switchSink.send(EventStream<int>.never());
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

        scope.runTransaction(() {
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

        scope.runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        final allValues = <int>[];
        final updates = <int>[];

        late ListenSubscription sub1;
        late ListenSubscription sub2;

        scope.runTransaction(() {
          sub1 = sink.state.toValues().listen(allValues.add);
          sub2 = sink.state.toUpdates().listen(updates.add);
        });

        expect(allValues, [0]); // Initial value
        expect(updates, isEmpty); // No initial

        // Empty transaction shouldn't trigger updates
        scope.runTransaction(() {});

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
        scope.runTransaction(() {
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

        scope.runTransaction(() {
          sink1 = ValueStateSink<int?>(1);
          sink2 = ValueStateSink<int?>(2);
          ref1 = sink1.state.toReference();
          ref2 = sink2.state.toReference();
        });

        final values = <int?>[];
        final sub = scope.runTransaction(() => sink1.state
            .combine<int?, int?>(
                sink2.state, (v1, v2) => (v1 ?? 0) + (v2 ?? 0))
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

        scope.runTransaction(() {
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

        scope.runTransaction(() {
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

        scope.runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
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
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        scope.runTransaction(() {
          sink = ValueStateSink<int>(0, (a, b) => a);
          ref = sink.state.toReference();
        });

        scope.runTransaction(() {
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

        scope.runTransaction(() {
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

        scope.runTransaction(() {
          sink = ValueStateSink<int>(1);
          ref = sink.state.toReference();
        });

        final values = <int>[];
        final sub = scope.runTransaction(() => sink.state
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

        scope.runTransaction(() {
          selectorSink = ValueStateSink<int>(1);
          dataSink = EventStreamSink<int>();
          selectorRef = selectorSink.state.toReference();
          dataRef = dataSink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(() => selectorSink.state
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
}

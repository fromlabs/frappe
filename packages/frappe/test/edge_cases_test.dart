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

  group('Edge cases', () {
    test('empty transaction is no-op', () {
      scope.run(() {
        runTransaction(() {});
      });
    });

    test('multiple listeners on same stream', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events1 = <int>[];
        final events2 = <int>[];
        final events3 = <int>[];

        final sub1 = runTransaction(() => sink.stream.listen(events1.add));
        final sub2 = runTransaction(() => sink.stream.listen(events2.add));
        final sub3 = runTransaction(() => sink.stream.listen(events3.add));

        sink.send(1);
        expect(events1, [1]);
        expect(events2, [1]);
        expect(events3, [1]);

        sub1.cancel();
        sink.send(2);
        expect(events1, [1]); // Cancelled
        expect(events2, [1, 2]);
        expect(events3, [1, 2]);

        sub2.cancel();
        sub3.cancel();
        ref.dispose();
      });
    });

    test('cascading map operations', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => sink.stream
            .map((v) => v + 1)
            .map((v) => v * 2)
            .map((v) => v - 3)
            .listen(events.add));

        sink.send(5); // (5+1)*2-3 = 9
        sink.send(0); // (0+1)*2-3 = -1

        expect(events, [9, -1]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('combine3 with three states', () {
      scope.run(() {
        late ValueStateSink<int> s1, s2, s3;
        late FrappeReference<ValueState<int>> r1, r2, r3;

        runTransaction(() {
          s1 = ValueStateSink<int>(1);
          s2 = ValueStateSink<int>(2);
          s3 = ValueStateSink<int>(3);
          r1 = s1.state.toReference();
          r2 = s2.state.toReference();
          r3 = s3.state.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(() => s1.state
            .combine2(s2.state, s3.state, (a, b, c) => a + b + c)
            .listen(values.add));

        expect(values, [6]); // 1+2+3

        s1.send(10);
        expect(values, [6, 15]); // 10+2+3

        sub.cancel();
        r1.dispose();
        r2.dispose();
        r3.dispose();
      });
    });

    test('combine4 with four states', () {
      scope.run(() {
        late ValueStateSink<int> s1, s2, s3, s4;
        late FrappeReference<ValueState<int>> r1, r2, r3, r4;

        runTransaction(() {
          s1 = ValueStateSink<int>(1);
          s2 = ValueStateSink<int>(2);
          s3 = ValueStateSink<int>(3);
          s4 = ValueStateSink<int>(4);
          r1 = s1.state.toReference();
          r2 = s2.state.toReference();
          r3 = s3.state.toReference();
          r4 = s4.state.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(() => s1.state
            .combine3(
                s2.state, s3.state, s4.state, (a, b, c, d) => a + b + c + d)
            .listen(values.add));

        expect(values, [10]); // 1+2+3+4

        sub.cancel();
        r1.dispose();
        r2.dispose();
        r3.dispose();
        r4.dispose();
      });
    });

    test('merges empty list creates never stream', () {
      scope.run(() {
        runTransaction(() {
          final stream = EventStream.merges<int>([]);
          // Should be a never stream - no events
          final events = <int>[];
          final sub = stream.listen(events.add);
          expect(events, isEmpty);
          sub.cancel();
        });
      });
    });

    test('merges single stream returns same stream', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
            () => EventStream.merges([sink.stream]).listen(events.add));

        sink.send(1);
        expect(events, [1]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('merges three streams', () {
      scope.run(() {
        late EventStreamSink<int> s1, s2, s3;
        late FrappeReference<EventStream<int>> r1, r2, r3;

        runTransaction(() {
          s1 = EventStreamSink<int>();
          s2 = EventStreamSink<int>();
          s3 = EventStreamSink<int>();
          r1 = s1.stream.toReference();
          r2 = s2.stream.toReference();
          r3 = s3.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() =>
            EventStream.merges([s1.stream, s2.stream, s3.stream])
                .listen(events.add));

        s1.send(1);
        s2.send(2);
        s3.send(3);

        expect(events, [1, 2, 3]);

        sub.cancel();
        r1.dispose();
        r2.dispose();
        r3.dispose();
      });
    });

    test('send from listener is caught and reported as error', () {
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

        final events = <int>[];
        final sub = runTransaction(() => sink.stream.listen((value) {
              events.add(value);
              sink.send(value + 10); // FRP anti-pattern: throws UnsupportedError
            }));

        sink.send(1);
        expect(events, [1]); // Only the original event is delivered
        expect(errors, hasLength(1));
        expect(errors.first, isA<UnsupportedError>());

        sub.cancel();
        ref.dispose();
      });
      errorScope.run(() => errorScope.assertCleanState());
      errorScope.dispose();
    });

    test('error recovery in listener', () {
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

        final events = <int>[];
        final sub = runTransaction(() => sink.stream.listen((value) {
              if (value == 2) throw Exception('error');
              events.add(value);
            }));

        sink.send(1); // OK
        sink.send(2); // Error thrown but caught
        sink.send(3); // Should still work

        expect(events, [1, 3]);
        expect(errors, hasLength(1));

        sub.cancel();
        ref.dispose();
      });
      errorScope.run(() => errorScope.assertCleanState());
      errorScope.dispose();
    });

    test('cancel is idempotent', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final sub = runTransaction(() => sink.stream.listen((_) {}));

        sub.cancel();
        sub.cancel(); // Should not throw

        ref.dispose();
      });
    });

    test('complex DAG with multiple paths', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final doubled = <int>[];
        final tripled = <int>[];
        final combined = <int>[];

        late ListenSubscription sub1, sub2, sub3;

        runTransaction(() {
          final d = sink.stream.map((v) => v * 2);
          final t = sink.stream.map((v) => v * 3);
          final c = d.orElse(t); // Merged, d wins on simultaneous

          sub1 = d.listen(doubled.add);
          sub2 = t.listen(tripled.add);
          sub3 = c.listen(combined.add);
        });

        sink.send(5);
        expect(doubled, [10]);
        expect(tripled, [15]);
        expect(combined, [10]); // d wins (first in orElse)

        sub1.cancel();
        sub2.cancel();
        sub3.cancel();
        ref.dispose();
      });
    });

    test('DisposableCollector with listen subscriptions', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final collector = DisposableCollector();
        final events = <int>[];

        runTransaction(() {
          collector.add(sink.stream.listen(events.add).toDisposable());
        });

        sink.send(1);
        expect(events, [1]);

        collector.dispose();
        sink.send(2);
        expect(events, [1]); // Disposed, no more events

        ref.dispose();
      });
    });

    test('lazy ValueStateSink', () {
      scope.run(() {
        var evaluated = false;
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;

        runTransaction(() {
          sink = ValueStateSink.lazy(LazyValue.provide(() {
            evaluated = true;
            return 42;
          }));
          ref = sink.state.toReference();
        });

        expect(evaluated, isFalse); // Not yet evaluated

        final value = runTransaction(() => sink.state.getValue());
        expect(value, 42);
        expect(evaluated, isTrue);

        ref.dispose();
      });
    });
  });

  group('Coverage gaps', () {
    test('toReference on derived (mapped) stream', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> sinkRef;
        late FrappeReference<EventStream<int>> mappedRef;

        runTransaction(() {
          sink = EventStreamSink<int>();
          sinkRef = sink.stream.toReference();
          mappedRef = sink.stream.map((v) => v * 2).toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => mappedRef.object.listen(events.add));

        sink.send(3);
        expect(events, [6]);

        sink.send(5);
        expect(events, [6, 10]);

        sub.cancel();
        mappedRef.dispose();
        sinkRef.dispose();
      });
    });

    test('almostOneInput evaluation type fires with partial input', () {
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

        // orElse uses almostOneInput internally
        final events = <int>[];
        final sub = runTransaction(
            () => sink1.stream.orElse(sink2.stream).listen(events.add));

        // Only sink1 fires
        sink1.send(10);
        expect(events, [10]);

        // Only sink2 fires
        sink2.send(20);
        expect(events, [10, 20]);

        // Both fire in same transaction - first wins
        runTransaction(() {
          sink1.send(30);
          sink2.send(40);
        });
        expect(events, [10, 20, 30]);

        sub.cancel();
        ref1.dispose();
        ref2.dispose();
      });
    });

    test('multiple FrappeReferences on same stream', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref1;
        late FrappeReference<EventStream<int>> ref2;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref1 = sink.stream.toReference();
          ref2 = sink.stream.toReference();
        });

        expect(sink.isClosed, isFalse);

        ref1.dispose();
        expect(sink.isClosed, isFalse); // ref2 still holds it

        ref2.dispose();
        expect(sink.isClosed, isTrue); // Both gone
      });
    });

    test('orElses with >2 streams', () {
      scope.run(() {
        late EventStreamSink<int> s1, s2, s3, s4;
        late FrappeReference<EventStream<int>> r1, r2, r3, r4;

        runTransaction(() {
          s1 = EventStreamSink<int>();
          s2 = EventStreamSink<int>();
          s3 = EventStreamSink<int>();
          s4 = EventStreamSink<int>();
          r1 = s1.stream.toReference();
          r2 = s2.stream.toReference();
          r3 = s3.stream.toReference();
          r4 = s4.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => s1.stream
            .orElses([s2.stream, s3.stream, s4.stream]).listen(events.add));

        s3.send(30);
        expect(events, [30]);

        s1.send(10);
        expect(events, [30, 10]);

        s4.send(40);
        expect(events, [30, 10, 40]);

        // All in same transaction
        runTransaction(() {
          s1.send(100);
          s2.send(200);
          s3.send(300);
          s4.send(400);
        });
        // First stream wins via default merger
        expect(events, [30, 10, 40, 100]);

        sub.cancel();
        r1.dispose();
        r2.dispose();
        r3.dispose();
        r4.dispose();
      });
    });

    test('switchStream multiple rapid transitions', () {
      scope.run(() {
        late EventStreamSink<int> sink1;
        late EventStreamSink<int> sink2;
        late EventStreamSink<int> sink3;
        late ValueStateSink<EventStream<int>> switchSink;
        late FrappeReference<EventStream<int>> r1, r2, r3;
        late FrappeReference<ValueState<EventStream<int>>> switchRef;

        runTransaction(() {
          sink1 = EventStreamSink<int>();
          sink2 = EventStreamSink<int>();
          sink3 = EventStreamSink<int>();
          r1 = sink1.stream.toReference();
          r2 = sink2.stream.toReference();
          r3 = sink3.stream.toReference();
          switchSink = ValueStateSink<EventStream<int>>(sink1.stream);
          switchRef = switchSink.state.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
            () => ValueState.switchStream(switchSink.state).listen(events.add));

        sink1.send(1);
        expect(events, [1]);

        // Switch to sink2
        switchSink.send(sink2.stream);
        sink2.send(2);
        expect(events, [1, 2]);

        // Switch to sink3
        switchSink.send(sink3.stream);
        sink3.send(3);
        expect(events, [1, 2, 3]);

        // Old streams no longer propagate
        sink1.send(100);
        sink2.send(200);
        expect(events, [1, 2, 3]);

        // Switch back to sink1
        switchSink.send(sink1.stream);
        sink1.send(10);
        expect(events, [1, 2, 3, 10]);

        sub.cancel();
        r1.dispose();
        r2.dispose();
        r3.dispose();
        switchRef.dispose();
      });
    });

    test('switchState multiple transitions', () {
      scope.run(() {
        late ValueStateSink<int> inner1;
        late ValueStateSink<int> inner2;
        late ValueStateSink<ValueState<int>> outerSink;
        late FrappeReference<ValueState<int>> r1, r2;
        late FrappeReference<ValueState<ValueState<int>>> outerRef;

        runTransaction(() {
          inner1 = ValueStateSink<int>(10);
          inner2 = ValueStateSink<int>(20);
          r1 = inner1.state.toReference();
          r2 = inner2.state.toReference();
          outerSink = ValueStateSink<ValueState<int>>(inner1.state);
          outerRef = outerSink.state.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(
            () => ValueState.switchState(outerSink.state).listen(values.add));

        expect(values, [10]); // inner1's initial value

        inner1.send(11);
        expect(values, [10, 11]);

        // Switch to inner2
        outerSink.send(inner2.state);
        expect(values, [10, 11, 20]); // inner2's current value

        inner2.send(21);
        expect(values, [10, 11, 20, 21]);

        // inner1 no longer propagates
        inner1.send(12);
        expect(values, [10, 11, 20, 21]);

        sub.cancel();
        r1.dispose();
        r2.dispose();
        outerRef.dispose();
      });
    });

    test('mapWhereNotNull extension on nullable stream', () {
      scope.run(() {
        late EventStreamSink<int?> sink;
        late FrappeReference<EventStream<int?>> ref;

        runTransaction(() {
          sink = EventStreamSink<int?>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(
            () => sink.stream.mapWhereNotNull().listen(events.add));

        sink.send(null);
        sink.send(1);
        sink.send(null);
        sink.send(2);

        expect(events, [1, 2]); // Nulls filtered, type narrowed to int

        sub.cancel();
        ref.dispose();
      });
    });

    test('sendNull on nullable sink', () {
      scope.run(() {
        late EventStreamSink<int?> sink;
        late FrappeReference<EventStream<int?>> ref;

        runTransaction(() {
          sink = EventStreamSink<int?>();
          ref = sink.stream.toReference();
        });

        final events = <int?>[];
        final sub = runTransaction(() => sink.stream.listen(events.add));

        sink.sendNull();
        sink.send(42);
        sink.sendNull();

        expect(events, [null, 42, null]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('ValueStateSink sendNull on nullable', () {
      scope.run(() {
        late ValueStateSink<int?> sink;
        late FrappeReference<ValueState<int?>> ref;

        runTransaction(() {
          sink = ValueStateSink<int?>(42);
          ref = sink.state.toReference();
        });

        final values = <int?>[];
        final sub = runTransaction(() => sink.state.listen(values.add));

        expect(values, [42]);

        sink.sendNull();
        expect(values, [42, null]);

        sink.send(10);
        expect(values, [42, null, 10]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('combines with 5 states (combine4)', () {
      scope.run(() {
        late ValueStateSink<int> s1, s2, s3, s4, s5;
        late FrappeReference<ValueState<int>> r1, r2, r3, r4, r5;

        runTransaction(() {
          s1 = ValueStateSink<int>(1);
          s2 = ValueStateSink<int>(2);
          s3 = ValueStateSink<int>(3);
          s4 = ValueStateSink<int>(4);
          s5 = ValueStateSink<int>(5);
          r1 = s1.state.toReference();
          r2 = s2.state.toReference();
          r3 = s3.state.toReference();
          r4 = s4.state.toReference();
          r5 = s5.state.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(() => s1.state
            .combine4(s2.state, s3.state, s4.state, s5.state,
                (a, b, c, d, e) => a + b + c + d + e)
            .listen(values.add));

        expect(values, [15]); // 1+2+3+4+5

        s3.send(10);
        expect(values, [15, 22]); // 1+2+10+4+5

        sub.cancel();
        r1.dispose();
        r2.dispose();
        r3.dispose();
        r4.dispose();
        r5.dispose();
      });
    });

    test('addReferencedSubscription ties cleanup to state', () {
      scope.run(() {
        late ValueStateSink<int> sink;
        late FrappeReference<ValueState<int>> ref;
        late FrappeReference<ValueState<int>> refWithSub;
        var listenerCancelled = false;

        runTransaction(() {
          sink = ValueStateSink<int>(0);
          ref = sink.state.toReference();
        });

        final trackingSub = _TrackingSubscription(() {
          listenerCancelled = true;
        });

        runTransaction(() {
          refWithSub =
              sink.state.addReferencedSubscription(trackingSub).toReference();
        });

        expect(listenerCancelled, isFalse);

        refWithSub.dispose();
        expect(listenerCancelled, isTrue);

        ref.dispose();
      });
    });

    test('castToNullable converts stream type', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int?>[];
        final sub = runTransaction(
            () => sink.stream.castToNullable().listen(events.add));

        sink.send(1);
        sink.send(2);
        expect(events, [1, 2]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('mapToNull maps all events to null', () {
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

        sink.send(1);
        sink.send(2);
        expect(events, [null, null]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('whereNull filters to only null values', () {
      scope.run(() {
        late EventStreamSink<int?> sink;
        late FrappeReference<EventStream<int?>> ref;

        runTransaction(() {
          sink = EventStreamSink<int?>();
          ref = sink.stream.toReference();
        });

        final events = <int?>[];
        final sub =
            runTransaction(() => sink.stream.whereNull().listen(events.add));

        sink.send(1);
        sink.send(null);
        sink.send(2);
        sink.send(null);

        expect(events, [null, null]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('distinct with custom equalizer', () {
      scope.run(() {
        late EventStreamSink<String> sink;
        late FrappeReference<EventStream<String>> ref;

        runTransaction(() {
          sink = EventStreamSink<String>();
          ref = sink.stream.toReference();
        });

        final events = <String>[];
        // Case-insensitive distinct
        final sub = runTransaction(() => sink.stream
            .distinct((a, b) => a.toLowerCase() == b.toLowerCase())
            .listen(events.add));

        sink.send('Hello');
        sink.send('hello'); // Same, filtered
        sink.send('HELLO'); // Same, filtered
        sink.send('World'); // Different
        sink.send('world'); // Same, filtered

        expect(events, ['Hello', 'World']);

        sub.cancel();
        ref.dispose();
      });
    });

    test('ValueState distinct with custom equalizer', () {
      scope.run(() {
        late ValueStateSink<String> sink;
        late FrappeReference<ValueState<String>> ref;

        runTransaction(() {
          sink = ValueStateSink<String>('Hello');
          ref = sink.state.toReference();
        });

        final values = <String>[];
        final sub = runTransaction(() => sink.state
            .distinct((a, b) => a.toLowerCase() == b.toLowerCase())
            .listen(values.add));

        expect(values, ['Hello']);

        sink.send('hello'); // Same (case-insensitive), filtered
        sink.send('World'); // Different
        sink.send('WORLD'); // Same, filtered

        expect(values, ['Hello', 'World']);

        sub.cancel();
        ref.dispose();
      });
    });

    test('accumulateLazy with deferred initial value', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;
        var providerCalled = false;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(
            () => sink.stream.accumulateLazy(LazyValue.provide(() {
                  providerCalled = true;
                  return 100;
                }), (v, s) => v + s).listen(values.add));

        expect(providerCalled, isTrue); // Provider called for initial
        expect(values, [100]); // Lazy initial value

        sink.send(1);
        expect(values, [100, 101]); // 100 + 1

        sub.cancel();
        ref.dispose();
      });
    });
  });

  group('Extensions', () {
    test('whereIsTrue / whereIsFalse', () {
      scope.run(() {
        late EventStreamSink<bool> sink;
        late FrappeReference<EventStream<bool>> ref;

        runTransaction(() {
          sink = EventStreamSink<bool>();
          ref = sink.stream.toReference();
        });

        final trues = <bool>[];
        final falses = <bool>[];

        late ListenSubscription sub1, sub2;
        runTransaction(() {
          sub1 = sink.stream.whereIsTrue().listen(trues.add);
          sub2 = sink.stream.whereIsFalse().listen(falses.add);
        });

        sink.send(true);
        sink.send(false);
        sink.send(true);

        expect(trues, [true, true]);
        expect(falses, [false]);

        sub1.cancel();
        sub2.cancel();
        ref.dispose();
      });
    });

    test('mapToUnit', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <Unit>[];
        final sub =
            runTransaction(() => sink.stream.mapToUnit().listen(events.add));

        sink.send(1);
        sink.send(2);
        expect(events, [unit, unit]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('sendUnit on Unit sink', () {
      scope.run(() {
        late EventStreamSink<Unit> sink;
        late FrappeReference<EventStream<Unit>> ref;

        runTransaction(() {
          sink = EventStreamSink<Unit>();
          ref = sink.stream.toReference();
        });

        final events = <Unit>[];
        final sub = runTransaction(() => sink.stream.listen(events.add));

        sink.sendUnit();
        expect(events, [unit]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('nullable extensions mapIsNull/mapIsNotNull', () {
      scope.run(() {
        late EventStreamSink<int?> sink;
        late FrappeReference<EventStream<int?>> ref;

        runTransaction(() {
          sink = EventStreamSink<int?>();
          ref = sink.stream.toReference();
        });

        final isNull = <bool>[];
        final isNotNull = <bool>[];

        late ListenSubscription sub1, sub2;
        runTransaction(() {
          sub1 = sink.stream.mapIsNull().listen(isNull.add);
          sub2 = sink.stream.mapIsNotNull().listen(isNotNull.add);
        });

        sink.send(null);
        sink.send(42);

        expect(isNull, [true, false]);
        expect(isNotNull, [false, true]);

        sub1.cancel();
        sub2.cancel();
        ref.dispose();
      });
    });

    test('whereValue filters by value', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub =
            runTransaction(() => sink.stream.whereValue(42).listen(events.add));

        sink.send(1);
        sink.send(42);
        sink.send(3);
        sink.send(42);

        expect(events, [42, 42]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('ValueState nullable mapIsNull/mapIsNotNull', () {
      scope.run(() {
        late ValueStateSink<int?> sink;
        late FrappeReference<ValueState<int?>> ref;

        runTransaction(() {
          sink = ValueStateSink<int?>(null);
          ref = sink.state.toReference();
        });

        final values = <bool>[];
        final sub =
            runTransaction(() => sink.state.mapIsNull().listen(values.add));

        expect(values, [true]); // null is null

        sink.send(42);
        expect(values, [true, false]);

        sub.cancel();
        ref.dispose();
      });
    });
  });

  group('LazyValue', () {
    test('value has immediate value', () {
      final lazy = LazyValue.value(42);
      expect(lazy.hasValue, isTrue);
      expect(lazy.get(), 42);
    });

    test('provide defers evaluation', () {
      var count = 0;
      final lazy = LazyValue.provide(() => ++count);

      expect(lazy.hasValue, isFalse);
      expect(lazy.get(), 1);
      expect(lazy.hasValue, isTrue);
      expect(lazy.get(), 1); // Cached
      expect(count, 1); // Only called once
    });

    test('map transforms lazily', () {
      final lazy = LazyValue.value(21);
      final mapped = lazy.map((v) => v * 2);

      expect(mapped.get(), 42);
    });

    test('combines multiple lazy values', () {
      final combined = LazyValue.combines(
        [LazyValue.value(1), LazyValue.value(2), LazyValue.value(3)],
        (values) => values.cast<int>().fold<int>(0, (a, b) => a + b),
      );

      expect(combined.get(), 6);
    });
  });

  group('Tuple2', () {
    test('equality', () {
      expect(Tuple2(1, 'a'), equals(Tuple2(1, 'a')));
      expect(Tuple2(1, 'a'), isNot(equals(Tuple2(2, 'a'))));
      expect(Tuple2(1, 'a'), isNot(equals(Tuple2(1, 'b'))));
    });

    test('hashCode consistency', () {
      expect(Tuple2(1, 'a').hashCode, equals(Tuple2(1, 'a').hashCode));
    });

    test('toString', () {
      expect(Tuple2(1, 'a').toString(), 'Tuple2(1, a)');
    });
  });

  group('ListenSubscription', () {
    test('base subscription cancel is no-op', () {
      final sub = ListenSubscription();
      expect(() => sub.cancel(), returnsNormally);
    });

    test('append creates composite subscription', () {
      var cancelled1 = false;
      var cancelled2 = false;

      final sub = _TrackingSubscription(() => cancelled1 = true)
          .append(_TrackingSubscription(() => cancelled2 = true));

      sub.cancel();
      expect(cancelled1, isTrue);
      expect(cancelled2, isTrue);
    });
  });

  // --- Phase 3: Test coverage gaps ---

  group('switchMap edge cases', () {
    test('rapid re-switching keeps only latest inner stream', () {
      scope.run(() {
        late EventStreamSink<int> selectorSink;
        late EventStreamSink<String> dataSinkA, dataSinkB, dataSinkC;
        late FrappeReference<EventStream<int>> selectorRef;
        late FrappeReference<EventStream<String>> refA, refB, refC;

        runTransaction(() {
          selectorSink = EventStreamSink<int>();
          dataSinkA = EventStreamSink<String>();
          dataSinkB = EventStreamSink<String>();
          dataSinkC = EventStreamSink<String>();
          selectorRef = selectorSink.stream.toReference();
          refA = dataSinkA.stream.toReference();
          refB = dataSinkB.stream.toReference();
          refC = dataSinkC.stream.toReference();
        });

        final events = <String>[];
        final streams = [dataSinkA.stream, dataSinkB.stream, dataSinkC.stream];
        final sub = runTransaction(() => selectorSink.stream
            .switchMap((i) => streams[i])
            .listen(events.add));

        // Rapid-fire: switch 0 -> 1 -> 2 in quick succession
        selectorSink.send(0);
        selectorSink.send(1);
        selectorSink.send(2);

        // Only stream C (index 2) should be active
        dataSinkA.send('a');
        dataSinkB.send('b');
        dataSinkC.send('c');
        expect(events, ['c']);

        sub.cancel();
        selectorRef.dispose();
        refA.dispose();
        refB.dispose();
        refC.dispose();
      });
    });

    test('error in mapper does not break graph', () {
      final errors = <Object>[];
      final errorScope = FrappeScope(onError: (e, s) => errors.add(e));

      errorScope.run(() {
        late EventStreamSink<int> sink;
        late EventStreamSink<String> dataSink;
        late FrappeReference<EventStream<int>> sinkRef;
        late FrappeReference<EventStream<String>> dataRef;

        runTransaction(() {
          sink = EventStreamSink<int>();
          dataSink = EventStreamSink<String>();
          sinkRef = sink.stream.toReference();
          dataRef = dataSink.stream.toReference();
        });

        final events = <String>[];
        final sub = runTransaction(() => sink.stream
            .switchMap((i) {
              if (i == 99) throw StateError('bad mapper');
              return dataSink.stream.map((s) => '$s:$i');
            })
            .listen(events.add));

        // Normal switch works
        sink.send(1);
        dataSink.send('x');
        expect(events, ['x:1']);

        // Mapper throws — error reported, node stays linked to previous
        sink.send(99);
        expect(errors, hasLength(1));

        // Previous inner stream still works after failed switch
        dataSink.send('y');
        expect(events, ['x:1', 'y:1']);

        sub.cancel();
        sinkRef.dispose();
        dataRef.dispose();
      });

      errorScope.run(() => errorScope.assertCleanState());
      errorScope.dispose();
    });
  });

  group('switchState edge cases', () {
    test('mutable inner state transitions propagate correctly', () {
      scope.run(() {
        late ValueStateSink<int> innerA, innerB;
        late ValueStateSink<ValueState<int>> outerSink;
        late FrappeReference<ValueState<int>> refA, refB;
        late FrappeReference<ValueState<ValueState<int>>> outerRef;

        runTransaction(() {
          innerA = ValueStateSink<int>(1);
          innerB = ValueStateSink<int>(100);
          refA = innerA.state.toReference();
          refB = innerB.state.toReference();
          outerSink = ValueStateSink<ValueState<int>>(innerA.state);
          outerRef = outerSink.state.toReference();
        });

        final values = <int>[];
        final sub = runTransaction(
            () => ValueState.switchState(outerSink.state).listen(values.add));

        expect(values, [1]); // innerA initial

        // Mutate innerA
        innerA.send(2);
        innerA.send(3);
        expect(values, [1, 2, 3]);

        // Switch to innerB
        outerSink.send(innerB.state);
        expect(values, [1, 2, 3, 100]);

        // Mutate innerB
        innerB.send(200);
        expect(values, [1, 2, 3, 100, 200]);

        // innerA mutations no longer propagate
        innerA.send(999);
        expect(values, [1, 2, 3, 100, 200]);

        // Switch back to innerA — picks up its current value
        outerSink.send(innerA.state);
        expect(values, [1, 2, 3, 100, 200, 999]);

        sub.cancel();
        refA.dispose();
        refB.dispose();
        outerRef.dispose();
      });
    });
  });

  group('Reactive feedback loops', () {
    test('EventStreamLink feedback cycle with accumulate', () {
      scope.run(() {
        late EventStreamSink<void> tickSink;
        late FrappeReference<EventStream<void>> tickRef;
        late FrappeReference<ValueState<int>> counterRef;

        late ValueState<int> counter;
        runTransaction(() {
          tickSink = EventStreamSink<void>();
          tickRef = tickSink.stream.toReference();
          counter = tickSink.stream.accumulate<int>(0, (_, count) => count + 1);
          counterRef = counter.toReference();
        });

        expect(counter.getValue(), 0);

        tickSink.send(null);
        expect(counter.getValue(), 1);

        tickSink.send(null);
        tickSink.send(null);
        expect(counter.getValue(), 3);

        counterRef.dispose();
        tickRef.dispose();
      });
    });

    test('ValueStateLink feedback cycle', () {
      scope.run(() {
        late EventStreamSink<int> addSink;
        late FrappeReference<EventStream<int>> addRef;
        late FrappeReference<ValueState<int>> sumRef;

        late ValueState<int> sum;
        runTransaction(() {
          addSink = EventStreamSink<int>();
          addRef = addSink.stream.toReference();
          final link = ValueStateLink<int>();
          link.connect(
              addSink.stream.snapshot(link.state, (e, s) => s + e).toState(0));
          sum = link.state;
          sumRef = sum.toReference();
        });

        expect(sum.getValue(), 0);

        addSink.send(5);
        expect(sum.getValue(), 5);

        addSink.send(3);
        expect(sum.getValue(), 8);

        addSink.send(-2);
        expect(sum.getValue(), 6);

        sumRef.dispose();
        addRef.dispose();
      });
    });
  });

  group('Transaction error recovery', () {
    test('error in evaluate handler propagates but does not corrupt state', () {
      final errors = <Object>[];
      final errorScope = FrappeScope(onError: (e, s) => errors.add(e));

      errorScope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = runTransaction(() => sink.stream
            .map((v) {
              if (v == 42) throw StateError('boom');
              return v;
            })
            .listen(events.add));

        // Normal event works
        sink.send(1);
        expect(events, [1]);

        // Throwing mapper — evaluation error propagates out of runTransaction
        expect(() => sink.send(42), throwsStateError);

        // Subsequent events still work — graph is not corrupted
        sink.send(2);
        expect(events, [1, 2]);

        sub.cancel();
        ref.dispose();
      });

      errorScope.run(() => errorScope.assertCleanState());
      errorScope.dispose();
    });
  });
}

class _TrackingSubscription extends ListenSubscription {
  final void Function() _onCancel;

  _TrackingSubscription(this._onCancel);

  @override
  void cancel() => _onCancel();
}

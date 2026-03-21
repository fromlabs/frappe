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

  group('Edge cases', () {
    test('empty transaction is no-op', () {
      scope.run(() {
        scope.runTransaction(() {});
      });
    });

    test('multiple listeners on same stream', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events1 = <int>[];
        final events2 = <int>[];
        final events3 = <int>[];

        final sub1 =
            scope.runTransaction(() => sink.stream.listen(events1.add));
        final sub2 =
            scope.runTransaction(() => sink.stream.listen(events2.add));
        final sub3 =
            scope.runTransaction(() => sink.stream.listen(events3.add));

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

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(() => sink.stream
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

        scope.runTransaction(() {
          s1 = ValueStateSink<int>(1);
          s2 = ValueStateSink<int>(2);
          s3 = ValueStateSink<int>(3);
          r1 = s1.state.toReference();
          r2 = s2.state.toReference();
          r3 = s3.state.toReference();
        });

        final values = <int>[];
        final sub = scope.runTransaction(() => s1.state
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

        scope.runTransaction(() {
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
        final sub = scope.runTransaction(() => s1.state
            .combine3(s2.state, s3.state, s4.state, (a, b, c, d) => a + b + c + d)
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
        scope.runTransaction(() {
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

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(
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

        scope.runTransaction(() {
          s1 = EventStreamSink<int>();
          s2 = EventStreamSink<int>();
          s3 = EventStreamSink<int>();
          r1 = s1.stream.toReference();
          r2 = s2.stream.toReference();
          r3 = s3.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(() =>
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

    test('recursive send from listener creates new transaction', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        var recursionCount = 0;

        final sub = scope.runTransaction(() => sink.stream.listen((value) {
              events.add(value);
              if (recursionCount < 2) {
                recursionCount++;
                sink.send(value + 10);
              }
            }));

        sink.send(1);
        expect(events, [1, 11, 21]); // Recursive sends

        sub.cancel();
        ref.dispose();
      });
    });

    test('error recovery in listener', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(() => sink.stream.listen((value) {
              if (value == 2) throw Exception('error');
              events.add(value);
            }));

        sink.send(1); // OK
        sink.send(2); // Error thrown but caught
        sink.send(3); // Should still work

        expect(events, [1, 3]);

        sub.cancel();
        ref.dispose();
      });
    });

    test('cancel is idempotent', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final sub = scope.runTransaction(() => sink.stream.listen((_) {}));

        sub.cancel();
        sub.cancel(); // Should not throw

        ref.dispose();
      });
    });

    test('complex DAG with multiple paths', () {
      scope.run(() {
        late EventStreamSink<int> sink;
        late FrappeReference<EventStream<int>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final doubled = <int>[];
        final tripled = <int>[];
        final combined = <int>[];

        late ListenSubscription sub1, sub2, sub3;

        scope.runTransaction(() {
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

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final collector = DisposableCollector();
        final events = <int>[];

        scope.runTransaction(() {
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

        scope.runTransaction(() {
          sink = ValueStateSink.lazy(LazyValue.provide(() {
            evaluated = true;
            return 42;
          }));
          ref = sink.state.toReference();
        });

        expect(evaluated, isFalse); // Not yet evaluated

        final value = scope.runTransaction(() => sink.state.getValue());
        expect(value, 42);
        expect(evaluated, isTrue);

        ref.dispose();
      });
    });
  });

  group('Extensions', () {
    test('whereIsTrue / whereIsFalse', () {
      scope.run(() {
        late EventStreamSink<bool> sink;
        late FrappeReference<EventStream<bool>> ref;

        scope.runTransaction(() {
          sink = EventStreamSink<bool>();
          ref = sink.stream.toReference();
        });

        final trues = <bool>[];
        final falses = <bool>[];

        late ListenSubscription sub1, sub2;
        scope.runTransaction(() {
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

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <Unit>[];
        final sub =
            scope.runTransaction(() => sink.stream.mapToUnit().listen(events.add));

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

        scope.runTransaction(() {
          sink = EventStreamSink<Unit>();
          ref = sink.stream.toReference();
        });

        final events = <Unit>[];
        final sub =
            scope.runTransaction(() => sink.stream.listen(events.add));

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

        scope.runTransaction(() {
          sink = EventStreamSink<int?>();
          ref = sink.stream.toReference();
        });

        final isNull = <bool>[];
        final isNotNull = <bool>[];

        late ListenSubscription sub1, sub2;
        scope.runTransaction(() {
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

        scope.runTransaction(() {
          sink = EventStreamSink<int>();
          ref = sink.stream.toReference();
        });

        final events = <int>[];
        final sub = scope.runTransaction(
            () => sink.stream.whereValue(42).listen(events.add));

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

        scope.runTransaction(() {
          sink = ValueStateSink<int?>(null);
          ref = sink.state.toReference();
        });

        final values = <bool>[];
        final sub = scope.runTransaction(
            () => sink.state.mapIsNull().listen(values.add));

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
        (values) => values.fold<int>(0, (a, b) => a + b),
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
}

class _TrackingSubscription extends ListenSubscription {
  final void Function() _onCancel;

  _TrackingSubscription(this._onCancel);

  @override
  void cancel() => _onCancel();
}

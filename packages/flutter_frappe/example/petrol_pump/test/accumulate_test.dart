import 'package:frappe/frappe.dart';
import 'package:petrol_pump/petrol_pump.dart';
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

  group('accumulate', () {
    test('starts at zero', () {
      scope.run(() {
        runTransaction(() {
          final clearSink = EventStreamSink<Unit>();
          final deltaSink = EventStreamSink<int>();
          final calibration = ValueState.constant(1.0);

          final result =
              accumulate(clearSink.stream, deltaSink.stream, calibration);
          final ref = result.toReference();

          expect(result.getValue(), 0.0);

          ref.dispose();
        });
      });
    });

    test('accumulates deltas with calibration', () {
      scope.run(() {
        late EventStreamSink<Unit> clearSink;
        late EventStreamSink<int> deltaSink;
        late ValueState<double> result;
        late FrappeReference ref;

        runTransaction(() {
          clearSink = EventStreamSink<Unit>();
          deltaSink = EventStreamSink<int>();
          final calibration = ValueState.constant(0.5);

          result =
              accumulate(clearSink.stream, deltaSink.stream, calibration);
          ref = result.toReference();
        });

        deltaSink.send(10);
        // 10 * 0.5 = 5.0
        expect(result.getValue(), 5.0);

        deltaSink.send(20);
        // (10 + 20) * 0.5 = 15.0
        expect(result.getValue(), 15.0);

        ref.dispose();
      });
    });

    test('clears on clear event', () {
      scope.run(() {
        late EventStreamSink<Unit> clearSink;
        late EventStreamSink<int> deltaSink;
        late ValueState<double> result;
        late FrappeReference ref;

        runTransaction(() {
          clearSink = EventStreamSink<Unit>();
          deltaSink = EventStreamSink<int>();
          final calibration = ValueState.constant(1.0);

          result =
              accumulate(clearSink.stream, deltaSink.stream, calibration);
          ref = result.toReference();
        });

        deltaSink.send(100);
        expect(result.getValue(), 100.0);

        clearSink.send(unit);
        expect(result.getValue(), 0.0);

        // Accumulate again after clear.
        deltaSink.send(50);
        expect(result.getValue(), 50.0);

        ref.dispose();
      });
    });
  });
}

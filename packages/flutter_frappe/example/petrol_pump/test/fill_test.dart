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

  group('Fill', () {
    test('initially all values are zero', () {
      scope.run(() {
        runTransaction(() {
          final clearSink = EventStreamSink<Unit>();
          final pulsesSink = EventStreamSink<int>();
          final startSink = EventStreamSink<Fuel>();

          final fill = Fill(
            clearAccumulatorStream: clearSink.stream,
            fuelsPulsesStream: pulsesSink.stream,
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: startSink.stream,
          );

          final refs = FrappeReferenceCollector();
          refs.add(fill.priceState);
          refs.add(fill.litersDeliveredState);
          refs.add(fill.dollarsDeliveredState);

          expect(fill.priceState.getValue(), 0.0);
          expect(fill.litersDeliveredState.getValue(), 0.0);
          expect(fill.dollarsDeliveredState.getValue(), 0.0);

          refs.dispose();
        });
      });
    });

    test('captures price for Fuel.one on start', () {
      scope.run(() {
        late EventStreamSink<Fuel> startSink;
        late Fill fill;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          final clearSink = EventStreamSink<Unit>();
          final pulsesSink = EventStreamSink<int>();
          startSink = EventStreamSink<Fuel>();

          refs = FrappeReferenceCollector();
          // Keep input streams alive across transactions.
          refs.add(clearSink.stream);
          refs.add(pulsesSink.stream);
          refs.add(startSink.stream);

          fill = Fill(
            clearAccumulatorStream: clearSink.stream,
            fuelsPulsesStream: pulsesSink.stream,
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: startSink.stream,
          );

          // Reference all outputs to prevent GC.
          refs.add(fill.priceState);
          refs.add(fill.litersDeliveredState);
          refs.add(fill.dollarsDeliveredState);
        });

        startSink.send(Fuel.one);
        expect(fill.priceState.getValue(), 2.0);

        refs.dispose();
      });
    });

    test('captures price for Fuel.two on start', () {
      scope.run(() {
        late EventStreamSink<Fuel> startSink;
        late Fill fill;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          final clearSink = EventStreamSink<Unit>();
          final pulsesSink = EventStreamSink<int>();
          startSink = EventStreamSink<Fuel>();

          refs = FrappeReferenceCollector();
          refs.add(clearSink.stream);
          refs.add(pulsesSink.stream);
          refs.add(startSink.stream);

          fill = Fill(
            clearAccumulatorStream: clearSink.stream,
            fuelsPulsesStream: pulsesSink.stream,
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: startSink.stream,
          );

          refs.add(fill.priceState);
          refs.add(fill.litersDeliveredState);
          refs.add(fill.dollarsDeliveredState);
        });

        startSink.send(Fuel.two);
        expect(fill.priceState.getValue(), 3.0);

        refs.dispose();
      });
    });

    test('computes dollars delivered as liters * price', () {
      scope.run(() {
        late EventStreamSink<int> pulsesSink;
        late EventStreamSink<Fuel> startSink;
        late Fill fill;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          final clearSink = EventStreamSink<Unit>();
          pulsesSink = EventStreamSink<int>();
          startSink = EventStreamSink<Fuel>();

          refs = FrappeReferenceCollector();
          refs.add(clearSink.stream);
          refs.add(pulsesSink.stream);
          refs.add(startSink.stream);

          fill = Fill(
            clearAccumulatorStream: clearSink.stream,
            fuelsPulsesStream: pulsesSink.stream,
            calibrationState: ValueState.constant(0.1),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: startSink.stream,
          );

          refs.add(fill.priceState);
          refs.add(fill.litersDeliveredState);
          refs.add(fill.dollarsDeliveredState);
        });

        startSink.send(Fuel.three);
        expect(fill.priceState.getValue(), 4.0);

        pulsesSink.send(10);
        // liters = 10 * 0.1 = 1.0, dollars = 1.0 * 4.0 = 4.0
        expect(fill.litersDeliveredState.getValue(), 1.0);
        expect(fill.dollarsDeliveredState.getValue(), 4.0);

        refs.dispose();
      });
    });

    test('clear resets accumulation', () {
      scope.run(() {
        late EventStreamSink<Unit> clearSink;
        late EventStreamSink<int> pulsesSink;
        late EventStreamSink<Fuel> startSink;
        late Fill fill;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          clearSink = EventStreamSink<Unit>();
          pulsesSink = EventStreamSink<int>();
          startSink = EventStreamSink<Fuel>();

          refs = FrappeReferenceCollector();
          refs.add(clearSink.stream);
          refs.add(pulsesSink.stream);
          refs.add(startSink.stream);

          fill = Fill(
            clearAccumulatorStream: clearSink.stream,
            fuelsPulsesStream: pulsesSink.stream,
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: startSink.stream,
          );

          refs.add(fill.priceState);
          refs.add(fill.litersDeliveredState);
          refs.add(fill.dollarsDeliveredState);
        });

        startSink.send(Fuel.one);
        pulsesSink.send(100);
        expect(fill.litersDeliveredState.getValue(), 100.0);

        clearSink.send(unit);
        expect(fill.litersDeliveredState.getValue(), 0.0);

        refs.dispose();
      });
    });
  });
}

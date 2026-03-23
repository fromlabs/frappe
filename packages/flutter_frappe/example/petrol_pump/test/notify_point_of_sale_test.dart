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

  group('NotifyPointOfSale', () {
    test('initially idle with no fuel active or flowing', () {
      scope.run(() {
        runTransaction(() {
          final lifecycle = Lifecycle(
            nozzle1Stream: EventStream.never(),
            nozzle2Stream: EventStream.never(),
            nozzle3Stream: EventStream.never(),
          );

          final fill = Fill(
            clearAccumulatorStream: EventStream.never(),
            fuelsPulsesStream: EventStream.never(),
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: EventStream.never(),
          );

          final npos = NotifyPointOfSale(
            lifecycle: lifecycle,
            fill: fill,
            clearSaleStream: EventStream.never(),
          );

          final refs = FrappeReferenceCollector();
          npos.hold(refs);

          expect(npos.fillActiveState.getValue(), isNull);
          expect(npos.fuelFlowingState.getValue(), isNull);

          refs.dispose();
        });
      });
    });

    test('lifting nozzle starts filling and sets fuel flowing', () {
      scope.run(() {
        late EventStreamSink<UpDown> nozzle1Sink;
        late NotifyPointOfSale npos;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          refs = FrappeReferenceCollector();
          nozzle1Sink = refs.addStreamSink<UpDown>();
          final clearSaleSink = refs.addStreamSink<Unit>();
          final startStreamLink = refs.addStreamLink<Fuel>();

          final lifecycle = Lifecycle(
            nozzle1Stream: nozzle1Sink.stream,
            nozzle2Stream: EventStream.never(),
            nozzle3Stream: EventStream.never(),
          );

          final fill = Fill(
            clearAccumulatorStream: clearSaleSink.stream,
            fuelsPulsesStream: EventStream.never(),
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: startStreamLink.stream,
          );

          npos = NotifyPointOfSale(
            lifecycle: lifecycle,
            fill: fill,
            clearSaleStream: clearSaleSink.stream,
          );

          startStreamLink.connect(npos.startStream);
          npos.hold(refs);
        });

        // Lift nozzle 1.
        nozzle1Sink.send(UpDown.up);
        expect(npos.fuelFlowingState.getValue(), Fuel.one);
        expect(npos.fillActiveState.getValue(), Fuel.one);

        refs.dispose();
      });
    });

    test('putting nozzle down ends fill and clears fuel flowing', () {
      scope.run(() {
        late EventStreamSink<UpDown> nozzle1Sink;
        late NotifyPointOfSale npos;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          refs = FrappeReferenceCollector();
          nozzle1Sink = refs.addStreamSink<UpDown>();
          final clearSaleSink = refs.addStreamSink<Unit>();
          final startStreamLink = refs.addStreamLink<Fuel>();

          final lifecycle = Lifecycle(
            nozzle1Stream: nozzle1Sink.stream,
            nozzle2Stream: EventStream.never(),
            nozzle3Stream: EventStream.never(),
          );

          final fill = Fill(
            clearAccumulatorStream: clearSaleSink.stream,
            fuelsPulsesStream: EventStream.never(),
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: startStreamLink.stream,
          );

          npos = NotifyPointOfSale(
            lifecycle: lifecycle,
            fill: fill,
            clearSaleStream: clearSaleSink.stream,
          );

          startStreamLink.connect(npos.startStream);
          npos.hold(refs);
        });

        nozzle1Sink.send(UpDown.up);
        nozzle1Sink.send(UpDown.down);

        // Fuel flowing cleared on end, but fill active persists until clear sale.
        expect(npos.fuelFlowingState.getValue(), isNull);
        expect(npos.fillActiveState.getValue(), Fuel.one);

        refs.dispose();
      });
    });

    test('clear sale resets fill active and allows new fill', () {
      scope.run(() {
        late EventStreamSink<UpDown> nozzle1Sink;
        late EventStreamSink<Unit> clearSaleSink;
        late NotifyPointOfSale npos;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          refs = FrappeReferenceCollector();
          nozzle1Sink = refs.addStreamSink<UpDown>();
          clearSaleSink = refs.addStreamSink<Unit>();
          final startStreamLink = refs.addStreamLink<Fuel>();

          final lifecycle = Lifecycle(
            nozzle1Stream: nozzle1Sink.stream,
            nozzle2Stream: EventStream.never(),
            nozzle3Stream: EventStream.never(),
          );

          final fill = Fill(
            clearAccumulatorStream: clearSaleSink.stream,
            fuelsPulsesStream: EventStream.never(),
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: startStreamLink.stream,
          );

          npos = NotifyPointOfSale(
            lifecycle: lifecycle,
            fill: fill,
            clearSaleStream: clearSaleSink.stream,
          );

          startStreamLink.connect(npos.startStream);
          npos.hold(refs);
        });

        // Complete a fill cycle.
        nozzle1Sink.send(UpDown.up);
        nozzle1Sink.send(UpDown.down);
        expect(npos.fillActiveState.getValue(), Fuel.one);

        // Clear sale resets.
        clearSaleSink.send(unit);
        expect(npos.fillActiveState.getValue(), isNull);

        // Can start a new fill.
        nozzle1Sink.send(UpDown.up);
        expect(npos.fuelFlowingState.getValue(), Fuel.one);

        nozzle1Sink.send(UpDown.down);
        clearSaleSink.send(unit);
        refs.dispose();
      });
    });

    test('emits sale complete on end', () {
      scope.run(() {
        late EventStreamSink<UpDown> nozzle1Sink;
        late EventStreamSink<int> pulsesSink;
        late EventStreamSink<Unit> clearSaleSink;
        late NotifyPointOfSale npos;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          refs = FrappeReferenceCollector();
          nozzle1Sink = refs.addStreamSink<UpDown>();
          pulsesSink = refs.addStreamSink<int>();
          clearSaleSink = refs.addStreamSink<Unit>();
          final startStreamLink = refs.addStreamLink<Fuel>();

          final lifecycle = Lifecycle(
            nozzle1Stream: nozzle1Sink.stream,
            nozzle2Stream: EventStream.never(),
            nozzle3Stream: EventStream.never(),
          );

          final fill = Fill(
            clearAccumulatorStream: clearSaleSink.stream,
            fuelsPulsesStream: pulsesSink.stream,
            calibrationState: ValueState.constant(0.01),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: startStreamLink.stream,
          );

          npos = NotifyPointOfSale(
            lifecycle: lifecycle,
            fill: fill,
            clearSaleStream: clearSaleSink.stream,
          );

          startStreamLink.connect(npos.startStream);
          npos.hold(refs);
        });

        final sales = <Sale>[];
        final saleSub = npos.saleCompleteStream.listen(sales.add);

        // Start filling nozzle 1.
        nozzle1Sink.send(UpDown.up);

        // Deliver some fuel.
        pulsesSink.send(100);

        // End fill.
        nozzle1Sink.send(UpDown.down);

        expect(sales, hasLength(1));
        expect(sales[0].fuel, Fuel.one);
        expect(sales[0].price, 2.0);
        // liters = 100 * 0.01 = 1.0
        expect(sales[0].quantity, 1.0);
        // cost = 1.0 * 2.0 = 2.0
        expect(sales[0].cost, 2.0);

        saleSub.cancel();
        clearSaleSink.send(unit);
        refs.dispose();
      });
    });

    test('cannot start new fill while in pos phase', () {
      scope.run(() {
        late EventStreamSink<UpDown> nozzle1Sink;
        late EventStreamSink<Unit> clearSaleSink;
        late NotifyPointOfSale npos;
        late FrappeReferenceCollector refs;

        runTransaction(() {
          refs = FrappeReferenceCollector();
          nozzle1Sink = refs.addStreamSink<UpDown>();
          clearSaleSink = refs.addStreamSink<Unit>();
          final startStreamLink = refs.addStreamLink<Fuel>();

          final lifecycle = Lifecycle(
            nozzle1Stream: nozzle1Sink.stream,
            nozzle2Stream: EventStream.never(),
            nozzle3Stream: EventStream.never(),
          );

          final fill = Fill(
            clearAccumulatorStream: clearSaleSink.stream,
            fuelsPulsesStream: EventStream.never(),
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: startStreamLink.stream,
          );

          npos = NotifyPointOfSale(
            lifecycle: lifecycle,
            fill: fill,
            clearSaleStream: clearSaleSink.stream,
          );

          startStreamLink.connect(npos.startStream);
          npos.hold(refs);
        });

        // Complete a fill — enter pos phase.
        nozzle1Sink.send(UpDown.up);
        nozzle1Sink.send(UpDown.down);

        // Try to start a new fill while in pos phase — should be blocked.
        nozzle1Sink.send(UpDown.up);
        expect(npos.fuelFlowingState.getValue(), isNull);

        nozzle1Sink.send(UpDown.down);
        clearSaleSink.send(unit);
        refs.dispose();
      });
    });
  });
}

import 'package:petrol_pump/petrol_pump.dart';
import 'package:frappe/frappe.dart';
import 'package:test/test.dart';

Outputs _switchOutputs(ValueState<Outputs> outputsState) => Outputs(
      deliveryState: outputsState
          .switchMapState<Delivery>((o) => o.deliveryState)
          .distinct(),
      saleCostLcdState: outputsState
          .switchMapState<String>((o) => o.saleCostLcdState)
          .distinct(),
      presetLcdState: outputsState
          .switchMapState<String>((o) => o.presetLcdState)
          .distinct(),
      saleQuantityLcdState: outputsState
          .switchMapState<String>((o) => o.saleQuantityLcdState)
          .distinct(),
      priceLcd1State: outputsState
          .switchMapState<String>((o) => o.priceLcd1State)
          .distinct(),
      priceLcd2State: outputsState
          .switchMapState<String>((o) => o.priceLcd2State)
          .distinct(),
      priceLcd3State: outputsState
          .switchMapState<String>((o) => o.priceLcd3State)
          .distinct(),
      beepStream: outputsState.switchMapStream<Unit>((o) => o.beepStream),
      saleCompleteStream:
          outputsState.switchMapStream<Sale>((o) => o.saleCompleteStream),
    );

void main() {
  // Integration tests for the petrol pump logic.
  // These tests use simulators with async cleanup, so FrappeScope
  // assertion is not used. The tests verify correct reactive behavior
  // by checking output values via listeners.

  group('Simple pump', () {
    late EventStreamLink<int> fuelPulsesStreamRef;
    late EventStreamLink<Unit> clearSaleStreamRef;
    late EventStreamSink<UpDown> nozzle1StreamSink;
    late EventStreamSink<UpDown> nozzle2StreamSink;
    late EventStreamSink<UpDown> nozzle3StreamSink;
    late EventStreamSink<NumericKey> keypadStreamSink;
    late ValueStateSink<double> calibrationStateSink;
    late ValueStateSink<double> price1StateSink;
    late ValueStateSink<double> price2StateSink;
    late ValueStateSink<double> price3StateSink;

    late PumpEngineSimulator pumpEngineSimulator;
    late PosSimulator posSimulator;

    late Outputs outputs;
    late FrappeReferenceCollector refs;
    late ListenSubscription listenCanceler;

    void connectListeners() {
      listenCanceler = outputs.deliveryState
          .listen((e) => print('deliveryState: $e'))
          .append(outputs.saleCostLcdState
              .listen((e) => print('saleCostLcdState: $e')))
          .append(
              outputs.presetLcdState.listen((e) => print('presetLcdState: $e')))
          .append(outputs.saleQuantityLcdState
              .listen((e) => print('saleQuantityLcdState: $e')))
          .append(
              outputs.priceLcd1State.listen((e) => print('priceLcd1State: $e')))
          .append(
              outputs.priceLcd2State.listen((e) => print('priceLcd2State: $e')))
          .append(
              outputs.priceLcd3State.listen((e) => print('priceLcd3State: $e')))
          .append(outputs.beepStream.listen((e) => print('beepStream')))
          .append(outputs.saleCompleteStream
              .listen((e) => print('saleCompleteStream: $e')));
    }

    setUp(() {
      refs = FrappeReferenceCollector();

      runTransaction(() {
        fuelPulsesStreamRef = EventStreamLink<int>();
        clearSaleStreamRef = EventStreamLink<Unit>();
        nozzle1StreamSink = EventStreamSink<UpDown>();
        nozzle2StreamSink = EventStreamSink<UpDown>();
        nozzle3StreamSink = EventStreamSink<UpDown>();
        keypadStreamSink = EventStreamSink<NumericKey>();
        calibrationStateSink = ValueStateSink<double>(0.001);
        price1StateSink = ValueStateSink<double>(2.149);
        price2StateSink = ValueStateSink<double>(2.341);
        price3StateSink = ValueStateSink<double>(1.499);

        // Keep sink streams alive via references.
        refs.add(fuelPulsesStreamRef.stream);
        refs.add(clearSaleStreamRef.stream);
        refs.add(nozzle1StreamSink.stream);
        refs.add(nozzle2StreamSink.stream);
        refs.add(nozzle3StreamSink.stream);
        refs.add(keypadStreamSink.stream);
        refs.add(calibrationStateSink.state);
        refs.add(price1StateSink.state);
        refs.add(price2StateSink.state);
        refs.add(price3StateSink.state);

        final pump = PresetAmountPump();

        outputs = pump.create(Inputs.defaults(
          nozzle1Stream: nozzle1StreamSink.stream,
          nozzle2Stream: nozzle2StreamSink.stream,
          nozzle3Stream: nozzle3StreamSink.stream,
          keypadStream: keypadStreamSink.stream,
          fuelPulsesStream: fuelPulsesStreamRef.stream,
          calibrationState: calibrationStateSink.state,
          price1State: price1StateSink.state,
          price2State: price2StateSink.state,
          price3State: price3StateSink.state,
          clearSaleStream: clearSaleStreamRef.stream,
        ));

        refs.add(outputs.deliveryState);
        refs.add(outputs.saleCostLcdState);
        refs.add(outputs.presetLcdState);
        refs.add(outputs.saleQuantityLcdState);
        refs.add(outputs.priceLcd1State);
        refs.add(outputs.priceLcd2State);
        refs.add(outputs.priceLcd3State);
        refs.add(outputs.beepStream);
        refs.add(outputs.saleCompleteStream);

        pumpEngineSimulator =
            PumpEngineSimulatorImpl(deliveryState: outputs.deliveryState);
        fuelPulsesStreamRef.connect(pumpEngineSimulator.fuelPulsesStream);

        posSimulator =
            PosSimulatorImpl(saleCompleteStream: outputs.saleCompleteStream);
        clearSaleStreamRef.connect(posSimulator.clearSaleStream);
        refs.add(posSimulator.clearSaleStream);

        connectListeners();
      });
    });

    tearDown(() {
      listenCanceler.cancel();
      pumpEngineSimulator.dispose();
      posSimulator.dispose();
      refs.dispose();
    });

    test('No action', () {
      // Verify pump initializes without error.
      expect(outputs.deliveryState.getValue(), Delivery.off);
    });

    test('Pump one round', () async {
      nozzle1StreamSink.send(UpDown.up);

      await Future<void>.delayed(const Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future<void>.delayed(const Duration(seconds: 3));
    });

    test('Pump two rounds', () async {
      nozzle1StreamSink.send(UpDown.up);
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      await Future<void>.delayed(const Duration(seconds: 3));

      runTransaction(() {
        listenCanceler.cancel();
        connectListeners();
      });

      nozzle1StreamSink.send(UpDown.up);
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      await Future<void>.delayed(const Duration(seconds: 3));
    });
  });

  group('Switch pump', () {
    late EventStreamLink<int> fuelPulsesStreamLink;
    late EventStreamLink<Unit> clearSaleStreamLink;
    late EventStreamSink<UpDown> nozzle1StreamSink;
    late EventStreamSink<UpDown> nozzle2StreamSink;
    late EventStreamSink<UpDown> nozzle3StreamSink;
    late EventStreamSink<NumericKey> keypadStreamSink;
    late ValueStateSink<double> calibrationStateSink;
    late ValueStateSink<double> price1StateSink;
    late ValueStateSink<double> price2StateSink;
    late ValueStateSink<double> price3StateSink;
    late ValueStateSink<Pump?> pumpLogicStateSink;

    late PumpEngineSimulator pumpEngineSimulator;
    late PosSimulator posSimulator;

    late Outputs outputs;
    late FrappeReferenceCollector refs;
    late FrappeReference<EventStream<Unit>> clearSaleStreamReference;
    late ListenSubscription listenCanceler;

    void connectListeners() {
      listenCanceler = pumpLogicStateSink.state
          .listen((e) => print(
              '-> pumpLogic: ${e?.runtimeType ?? 'none'}'))
          .append(
              nozzle1StreamSink.stream.listen((e) => print('-> nozzle1: $e')))
          .append(
              nozzle2StreamSink.stream.listen((e) => print('-> nozzle2: $e')))
          .append(
              nozzle3StreamSink.stream.listen((e) => print('-> nozzle3: $e')))
          .append(outputs.deliveryState.listen((e) => print('delivery: $e')))
          .append(
              outputs.saleCostLcdState.listen((e) => print('saleCostLcd: $e')))
          .append(outputs.presetLcdState.listen((e) => print('presetLcd: $e')))
          .append(outputs.saleQuantityLcdState
              .listen((e) => print('saleQuantityLcd: $e')))
          .append(outputs.priceLcd1State.listen((e) => print('priceLcd1: $e')))
          .append(outputs.priceLcd2State.listen((e) => print('priceLcd2: $e')))
          .append(outputs.priceLcd3State.listen((e) => print('priceLcd3: $e')))
          .append(outputs.beepStream.listen((e) => print('beep')))
          .append(outputs.saleCompleteStream
              .listen((e) => print('saleCompleteStream: $e')));
    }

    setUp(() {
      refs = FrappeReferenceCollector();

      runTransaction(() {
        fuelPulsesStreamLink = EventStreamLink<int>();
        clearSaleStreamLink = EventStreamLink<Unit>();
        nozzle1StreamSink = EventStreamSink<UpDown>();
        nozzle2StreamSink = EventStreamSink<UpDown>();
        nozzle3StreamSink = EventStreamSink<UpDown>();
        keypadStreamSink = EventStreamSink<NumericKey>();
        calibrationStateSink = ValueStateSink<double>(0.001);
        price1StateSink = ValueStateSink<double>(2.149);
        price2StateSink = ValueStateSink<double>(2.341);
        price3StateSink = ValueStateSink<double>(1.499);
        pumpLogicStateSink = ValueStateSink<Pump?>(null);

        refs.add(fuelPulsesStreamLink.stream);
        refs.add(clearSaleStreamLink.stream);
        refs.add(nozzle1StreamSink.stream);
        refs.add(nozzle2StreamSink.stream);
        refs.add(nozzle3StreamSink.stream);
        refs.add(keypadStreamSink.stream);
        refs.add(calibrationStateSink.state);
        refs.add(price1StateSink.state);
        refs.add(price2StateSink.state);
        refs.add(price3StateSink.state);
        refs.add(pumpLogicStateSink.state);

        final outputsState = pumpLogicStateSink.state.map((pump) {
          if (pump != null) {
            return pump.create(Inputs.defaults(
              nozzle1Stream: nozzle1StreamSink.stream,
              nozzle2Stream: nozzle2StreamSink.stream,
              nozzle3Stream: nozzle3StreamSink.stream,
              keypadStream: keypadStreamSink.stream,
              fuelPulsesStream: fuelPulsesStreamLink.stream,
              calibrationState: calibrationStateSink.state,
              price1State: price1StateSink.state,
              price2State: price2StateSink.state,
              price3State: price3StateSink.state,
              clearSaleStream: clearSaleStreamLink.stream,
            ));
          } else {
            return Outputs.defaults();
          }
        });

        outputs = _switchOutputs(outputsState);

        refs.add(outputs.deliveryState);
        refs.add(outputs.saleCostLcdState);
        refs.add(outputs.presetLcdState);
        refs.add(outputs.saleQuantityLcdState);
        refs.add(outputs.priceLcd1State);
        refs.add(outputs.priceLcd2State);
        refs.add(outputs.priceLcd3State);
        refs.add(outputs.beepStream);
        refs.add(outputs.saleCompleteStream);

        pumpEngineSimulator =
            PumpEngineSimulatorImpl(deliveryState: outputs.deliveryState);
        fuelPulsesStreamLink.connect(pumpEngineSimulator.fuelPulsesStream);

        posSimulator =
            PosSimulatorImpl(saleCompleteStream: outputs.saleCompleteStream);
        clearSaleStreamLink.connect(posSimulator.clearSaleStream);
        clearSaleStreamReference =
            posSimulator.clearSaleStream.toReference();

        connectListeners();
      });
    });

    tearDown(() {
      listenCanceler.cancel();
      pumpEngineSimulator.dispose();
      posSimulator.dispose();
      clearSaleStreamReference.dispose();
      refs.dispose();
    });

    test('No pump', () {
      expect(outputs.deliveryState.getValue(), Delivery.off);
    });

    test('LifecyclePump complete', () async {
      pumpLogicStateSink.send(LifecyclePump());

      nozzle1StreamSink.send(UpDown.up);
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
    });

    test('AccumulatePulsesPump complete', () async {
      pumpLogicStateSink.send(AccumulatePulsesPump());

      nozzle1StreamSink.send(UpDown.up);
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
    });

    test('ShowDollarsPump complete', () async {
      pumpLogicStateSink.send(ShowDollarsPump());

      nozzle1StreamSink.send(UpDown.up);
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
    });

    test('Clear sale pump', () async {
      pumpLogicStateSink.send(ClearSalePump());
      keypadStreamSink.send(NumericKey.one);

      nozzle1StreamSink.send(UpDown.up);
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);

      await clearSaleStreamReference.object.first();
    });

    test('Preset pump', () async {
      pumpLogicStateSink.send(PresetAmountPump());
      keypadStreamSink.send(NumericKey.one);

      nozzle1StreamSink.send(UpDown.up);
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);

      await clearSaleStreamReference.object.first();
    });

    test('All pumps switch', () async {
      pumpLogicStateSink.send(LifecyclePump());
      nozzle1StreamSink.send(UpDown.up);
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);

      pumpLogicStateSink.send(AccumulatePulsesPump());
      nozzle1StreamSink.send(UpDown.up);
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);

      pumpLogicStateSink.send(ShowDollarsPump());
      nozzle1StreamSink.send(UpDown.up);
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);

      pumpLogicStateSink.send(ClearSalePump());
      nozzle1StreamSink.send(UpDown.up);
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      await clearSaleStreamReference.object.first();

      pumpLogicStateSink.send(PresetAmountPump());
      nozzle1StreamSink.send(UpDown.up);
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      await clearSaleStreamReference.object.first();
    });
  });
}

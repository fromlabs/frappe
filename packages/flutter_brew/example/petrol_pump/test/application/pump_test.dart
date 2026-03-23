import 'package:petrol_pump_brew/petrol_pump_brew.dart';
import 'package:frappe/frappe.dart';
import 'package:test/test.dart';

/// References all output fields via [refs] to keep them alive.
void _holdOutputs(Outputs outputs, FrappeReferenceCollector refs) {
  refs
    ..add(outputs.deliveryState)
    ..add(outputs.presetLcdState)
    ..add(outputs.saleCostLcdState)
    ..add(outputs.saleQuantityLcdState)
    ..add(outputs.priceLcd1State)
    ..add(outputs.priceLcd2State)
    ..add(outputs.priceLcd3State)
    ..add(outputs.beepStream)
    ..add(outputs.saleCompleteStream);
}

void main() {
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

    late PumpEngine pumpEngineSimulator;
    late PosTerminal posSimulator;

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
        fuelPulsesStreamRef = refs.addStreamLink<int>();
        clearSaleStreamRef = refs.addStreamLink<Unit>();
        nozzle1StreamSink = refs.addStreamSink<UpDown>();
        nozzle2StreamSink = refs.addStreamSink<UpDown>();
        nozzle3StreamSink = refs.addStreamSink<UpDown>();
        keypadStreamSink = refs.addStreamSink<NumericKey>();
        calibrationStateSink = refs.addStateSink<double>(0.001);
        price1StateSink = refs.addStateSink<double>(2.149);
        price2StateSink = refs.addStateSink<double>(2.341);
        price3StateSink = refs.addStateSink<double>(1.499);

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

        _holdOutputs(outputs, refs);

        pumpEngineSimulator =
            DefaultPumpEngine(deliveryState: outputs.deliveryState);
        fuelPulsesStreamRef.connect(pumpEngineSimulator.fuelPulsesStream);

        posSimulator =
            DefaultPosTerminal(saleCompleteStream: outputs.saleCompleteStream);
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
      expect(outputs.deliveryState.getValue(), Delivery.off);
      expect(outputs.presetLcdState.getValue(), '0');
      expect(outputs.saleCostLcdState.getValue(), '0.0');
      expect(outputs.saleQuantityLcdState.getValue(), '0.0');
    });

    test('Pump one round', () async {
      nozzle1StreamSink.send(UpDown.up);
      expect(outputs.deliveryState.getValue(), isNot(Delivery.off));

      await Future<void>.delayed(const Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);
      expect(outputs.deliveryState.getValue(), Delivery.off);

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
      expect(outputs.deliveryState.getValue(), isNot(Delivery.off));
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      expect(outputs.deliveryState.getValue(), Delivery.off);
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

    late PumpEngine pumpEngineSimulator;
    late PosTerminal posSimulator;

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
        fuelPulsesStreamLink = refs.addStreamLink<int>();
        clearSaleStreamLink = refs.addStreamLink<Unit>();
        nozzle1StreamSink = refs.addStreamSink<UpDown>();
        nozzle2StreamSink = refs.addStreamSink<UpDown>();
        nozzle3StreamSink = refs.addStreamSink<UpDown>();
        keypadStreamSink = refs.addStreamSink<NumericKey>();
        calibrationStateSink = refs.addStateSink<double>(0.001);
        price1StateSink = refs.addStateSink<double>(2.149);
        price2StateSink = refs.addStateSink<double>(2.341);
        price3StateSink = refs.addStateSink<double>(1.499);
        pumpLogicStateSink = refs.addStateSink<Pump?>(null);

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

        outputs = Outputs.switchFrom(outputsState);

        _holdOutputs(outputs, refs);

        pumpEngineSimulator =
            DefaultPumpEngine(deliveryState: outputs.deliveryState);
        fuelPulsesStreamLink.connect(pumpEngineSimulator.fuelPulsesStream);

        posSimulator =
            DefaultPosTerminal(saleCompleteStream: outputs.saleCompleteStream);
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
      expect(outputs.deliveryState.getValue(), isNot(Delivery.off));
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      expect(outputs.deliveryState.getValue(), Delivery.off);
    });

    test('AccumulatePulsesPump complete', () async {
      pumpLogicStateSink.send(AccumulatePulsesPump());

      nozzle1StreamSink.send(UpDown.up);
      expect(outputs.deliveryState.getValue(), isNot(Delivery.off));
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      expect(outputs.deliveryState.getValue(), Delivery.off);
    });

    test('ShowDollarsPump complete', () async {
      pumpLogicStateSink.send(ShowDollarsPump());

      nozzle1StreamSink.send(UpDown.up);
      expect(outputs.deliveryState.getValue(), isNot(Delivery.off));
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      expect(outputs.deliveryState.getValue(), Delivery.off);
    });

    test('Clear sale pump', () async {
      pumpLogicStateSink.send(ClearSalePump());
      keypadStreamSink.send(NumericKey.one);

      nozzle1StreamSink.send(UpDown.up);
      expect(outputs.deliveryState.getValue(), isNot(Delivery.off));
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      expect(outputs.deliveryState.getValue(), Delivery.off);

      await clearSaleStreamReference.object.first();
    });

    test('Preset pump', () async {
      pumpLogicStateSink.send(PresetAmountPump());
      keypadStreamSink.send(NumericKey.one);

      nozzle1StreamSink.send(UpDown.up);
      expect(outputs.deliveryState.getValue(), isNot(Delivery.off));
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      expect(outputs.deliveryState.getValue(), Delivery.off);

      await clearSaleStreamReference.object.first();
    });

    test('All pumps switch', () async {
      pumpLogicStateSink.send(LifecyclePump());
      nozzle1StreamSink.send(UpDown.up);
      expect(outputs.deliveryState.getValue(), isNot(Delivery.off));
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      expect(outputs.deliveryState.getValue(), Delivery.off);

      pumpLogicStateSink.send(AccumulatePulsesPump());
      nozzle1StreamSink.send(UpDown.up);
      expect(outputs.deliveryState.getValue(), isNot(Delivery.off));
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      expect(outputs.deliveryState.getValue(), Delivery.off);

      pumpLogicStateSink.send(ShowDollarsPump());
      nozzle1StreamSink.send(UpDown.up);
      expect(outputs.deliveryState.getValue(), isNot(Delivery.off));
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      expect(outputs.deliveryState.getValue(), Delivery.off);

      pumpLogicStateSink.send(ClearSalePump());
      nozzle1StreamSink.send(UpDown.up);
      expect(outputs.deliveryState.getValue(), isNot(Delivery.off));
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      expect(outputs.deliveryState.getValue(), Delivery.off);
      await clearSaleStreamReference.object.first();

      pumpLogicStateSink.send(PresetAmountPump());
      nozzle1StreamSink.send(UpDown.up);
      expect(outputs.deliveryState.getValue(), isNot(Delivery.off));
      await Future<void>.delayed(const Duration(seconds: 1));
      nozzle1StreamSink.send(UpDown.down);
      expect(outputs.deliveryState.getValue(), Delivery.off);
      await clearSaleStreamReference.object.first();
    });
  });
}

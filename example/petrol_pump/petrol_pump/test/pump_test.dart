import 'dart:async';

import 'package:petrol_pump/petrol_pump.dart';
import 'package:frappe/frappe.dart';
import 'package:test/test.dart';

void main() {
  group('Simple pump', () {
    EventStreamLink<int> fuelPulsesStreamRef;
    EventStreamLink<Unit> clearSaleStreamRef;
    EventStreamSink<UpDown> nozzle1StreamSink;
    EventStreamSink<UpDown> nozzle2StreamSink;
    EventStreamSink<UpDown> nozzle3StreamSink;
    EventStreamSink<NumericKey> keypadStreamSink;
    ValueStateSink<double> calibrationStateSink;
    ValueStateSink<double> price1StateSink;
    ValueStateSink<double> price2StateSink;
    ValueStateSink<double> price3StateSink;

    PumpEngineSimulator pumpEngineSimulator;
    PosSimulator posSimulator;

    Outputs outputs;

    ListenSubscription listenCanceler;

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

    Future<void> disconnectListeners() async {
      await ListenCancelerDisposable(listenCanceler).dispose();
    }

    setUpAll(() {
      initTransaction();
    });

    setUp(() {
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

        final pump = PresetAmountPump();

        outputs = pump.create(Inputs.fromDefault((builder) => builder
          ..nozzle1Stream = nozzle1StreamSink.stream
          ..nozzle2Stream = nozzle2StreamSink.stream
          ..nozzle3Stream = nozzle3StreamSink.stream
          ..keypadStream = keypadStreamSink.stream
          ..fuelPulsesStream = fuelPulsesStreamRef.stream
          ..calibrationState = calibrationStateSink.state
          ..price1State = price1StateSink.state
          ..price2State = price2StateSink.state
          ..price3State = price3StateSink.state
          ..clearSaleStream = clearSaleStreamRef.stream));

        pumpEngineSimulator =
            PumpEngineSimulatorImpl(deliveryState: outputs.deliveryState);
        fuelPulsesStreamRef.connect(pumpEngineSimulator.fuelPulsesStream);

        posSimulator =
            PosSimulatorImpl(saleCompleteStream: outputs.saleCompleteStream);
        clearSaleStreamRef.connect(posSimulator.clearSaleStream);

        connectListeners();
      });
    });

    tearDown(() async {
      await disconnectListeners();

      await Future.wait([
        posSimulator,
        pumpEngineSimulator,
        EventStreamSinkDisposable(nozzle1StreamSink),
        EventStreamSinkDisposable(nozzle2StreamSink),
        EventStreamSinkDisposable(nozzle3StreamSink),
        EventStreamSinkDisposable(keypadStreamSink),
        ValueStateSinkDisposable(calibrationStateSink),
        ValueStateSinkDisposable(price1StateSink),
        ValueStateSinkDisposable(price2StateSink),
        ValueStateSinkDisposable(price3StateSink),
      ]
          .map<Future>((disposable) => disposable?.dispose())
          .where((future) => future != null));

      assertCleanup();
    });

    test('No action', () {});

    test('Pump one round', () async {
      print('-> nozzle1: ${UpDown.up}');

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      print('-> nozzle1: ${UpDown.down}');

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 3));
    });

    test('Pump two rounds', () async {
      connectListeners();

      print('nozzle1: ${UpDown.up}');

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      print('nozzle1: ${UpDown.down}');

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 3));

      await disconnectListeners();

      connectListeners();

      print('nozzle1: ${UpDown.up}');

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      print('nozzle1: ${UpDown.down}');

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 3));

      await disconnectListeners();
    });
  });

  group('Switch pump', () {
    EventStreamReference<EventStream<int>> fuelPulsesStreamReference;
    EventStreamReference<EventStream<Unit>> clearSaleStreamReference;
    EventStreamSink<UpDown> nozzle1StreamSink;
    EventStreamSink<UpDown> nozzle2StreamSink;
    EventStreamSink<UpDown> nozzle3StreamSink;
    EventStreamSink<NumericKey> keypadStreamSink;
    ValueStateSink<double> calibrationStateSink;
    ValueStateSink<double> price1StateSink;
    ValueStateSink<double> price2StateSink;
    ValueStateSink<double> price3StateSink;
    OptionalValueStateSink<Pump> pumpLogicStateSink;

    PumpEngineSimulator pumpEngineSimulator;
    PosSimulator posSimulator;

    Outputs outputs;

    ListenSubscription listenCanceler;

    void connectListeners() {
      listenCanceler = ListenSubscription()
          .append(pumpLogicStateSink.state.listen((e) => print(
              '-> pumpLogic: ${e.map((pump) => pump.runtimeType.toString()).orElse('none')}')))
          .append(nozzle1StreamSink.stream.listen((e) => print('-> nozzle1: $e')))
          .append(nozzle2StreamSink.stream.listen((e) => print('-> nozzle2: $e')))
          .append(nozzle3StreamSink.stream.listen((e) => print('-> nozzle3: $e')))
          .append(outputs.deliveryState.listen((e) => print('delivery: $e')))
          .append(outputs.saleCostLcdState
              .listen((e) => print('saleCostLcd: $e')))
          .append(
              outputs.presetLcdState.listen((e) => print('presetLcd: $e')))
          .append(outputs.saleQuantityLcdState
              .listen((e) => print('saleQuantityLcd: $e')))
          .append(
              outputs.priceLcd1State.listen((e) => print('priceLcd1: $e')))
          .append(
              outputs.priceLcd2State.listen((e) => print('priceLcd2: $e')))
          .append(
              outputs.priceLcd3State.listen((e) => print('priceLcd3: $e')))
          .append(outputs.beepStream.listen((e) => print('beep')))
          .append(outputs.saleCompleteStream
              .listen((e) => print('saleCompleteStream: $e')));
    }

    Future<void> disconnectListeners() async {
      await ListenCancelerDisposable(listenCanceler).dispose();
    }

    setUpAll(() {
      initTransaction();
    });

    setUp(() {
      runTransaction(() {
        final fuelPulsesStreamLink = EventStreamLink<int>();
        final clearSaleStreamLink = EventStreamLink<Unit>();
        fuelPulsesStreamReference = fuelPulsesStreamLink.stream.toReference();
        clearSaleStreamReference = clearSaleStreamLink.stream.toReference();
        nozzle1StreamSink = EventStreamSink<UpDown>();
        nozzle2StreamSink = EventStreamSink<UpDown>();
        nozzle3StreamSink = EventStreamSink<UpDown>();
        keypadStreamSink = EventStreamSink<NumericKey>();
        calibrationStateSink = ValueStateSink<double>(0.001);
        price1StateSink = ValueStateSink<double>(2.149);
        price2StateSink = ValueStateSink<double>(2.341);
        price3StateSink = ValueStateSink<double>(1.499);
        pumpLogicStateSink = OptionalValueStateSink<Pump>.empty();

        final outputsState = pumpLogicStateSink.state.map((pump) {
          if (pump.isPresent) {
            return pump.value.create(Inputs.fromDefault(
              (builder) => builder
                ..nozzle1Stream = nozzle1StreamSink.stream
                ..nozzle2Stream = nozzle2StreamSink.stream
                ..nozzle3Stream = nozzle3StreamSink.stream
                ..keypadStream = keypadStreamSink.stream
                ..fuelPulsesStream = fuelPulsesStreamLink.stream
                ..calibrationState = calibrationStateSink.state
                ..price1State = price1StateSink.state
                ..price2State = price2StateSink.state
                ..price3State = price3StateSink.state
                ..clearSaleStream = clearSaleStreamLink.stream,
            ));
          } else {
            return Outputs.fromDefault();
          }
        });

        outputs = switchOutputs(outputsState);

        pumpEngineSimulator =
            PumpEngineSimulatorImpl(deliveryState: outputs.deliveryState);
        fuelPulsesStreamLink.connect(pumpEngineSimulator.fuelPulsesStream);

        posSimulator =
            PosSimulatorImpl(saleCompleteStream: outputs.saleCompleteStream);
        clearSaleStreamLink.connect(posSimulator.clearSaleStream);

        connectListeners();
      });
    });

    tearDown(() async {
      await disconnectListeners();

      await Future.wait([
        posSimulator,
        pumpEngineSimulator,
        fuelPulsesStreamReference,
        clearSaleStreamReference,
        EventStreamSinkDisposable(nozzle1StreamSink),
        EventStreamSinkDisposable(nozzle2StreamSink),
        EventStreamSinkDisposable(nozzle3StreamSink),
        EventStreamSinkDisposable(keypadStreamSink),
        ValueStateSinkDisposable(calibrationStateSink),
        ValueStateSinkDisposable(price1StateSink),
        ValueStateSinkDisposable(price2StateSink),
        ValueStateSinkDisposable(price3StateSink),
        ValueStateSinkDisposable(pumpLogicStateSink),
      ]
          .map<Future>((disposable) => disposable?.dispose())
          .where((future) => future != null));

      assertCleanup();
    });

    test('No pump', () async {      
    });

    test('LifecyclePump complete', () async {
      runTransaction(() => pumpLogicStateSink.sendOptionalOf(LifecyclePump()));

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);
    });

    test('AccumulatePulsesPump complete', () async {
      runTransaction(() => pumpLogicStateSink.sendOptionalOf(AccumulatePulsesPump()));

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);
    });

    test('ShowDollarsPump complete', () async {
      runTransaction(() => pumpLogicStateSink.sendOptionalOf(ShowDollarsPump()));

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);
    });

    test('Clear sale pump', () async {
      runTransaction(() => pumpLogicStateSink.sendOptionalOf(ClearSalePump())); 

      keypadStreamSink.send(NumericKey.one);

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await clearSaleStreamReference.stream.toLegacyStream().first;
    });

    test('Preset pump', () async {
      runTransaction(() => pumpLogicStateSink.sendOptionalOf(PresetAmountPump()));

      keypadStreamSink.send(NumericKey.one);

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await clearSaleStreamReference.stream.toLegacyStream().first;
    });

    test('All pumps switch', () async {
      runTransaction(() => pumpLogicStateSink.sendOptionalOf(LifecyclePump()));

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      runTransaction(() => pumpLogicStateSink.sendOptionalOf(AccumulatePulsesPump()));

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      runTransaction(() => pumpLogicStateSink.sendOptionalOf(ShowDollarsPump()));

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      runTransaction(() => pumpLogicStateSink.sendOptionalOf(ClearSalePump()));

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await clearSaleStreamReference.stream.toLegacyStream().first;

      runTransaction(() => pumpLogicStateSink.sendOptionalOf(PresetAmountPump()));

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await clearSaleStreamReference.stream.toLegacyStream().first;
    });

    test('All pumps switch two times', () async {
      for (var i = 0; i < 2; i++) {
        runTransaction(() => pumpLogicStateSink.sendOptionalOf(LifecyclePump()));
          nozzle1StreamSink.send(UpDown.up);

          await Future.delayed(Duration(seconds: 1));

          nozzle1StreamSink.send(UpDown.down);

          runTransaction(() => pumpLogicStateSink.sendOptionalOf(AccumulatePulsesPump()));

          nozzle1StreamSink.send(UpDown.up);

          await Future.delayed(Duration(seconds: 1));

          nozzle1StreamSink.send(UpDown.down);

          runTransaction(() => pumpLogicStateSink.sendOptionalOf(ShowDollarsPump()));

          nozzle1StreamSink.send(UpDown.up);

          await Future.delayed(Duration(seconds: 1));

          nozzle1StreamSink.send(UpDown.down);

          runTransaction(() => pumpLogicStateSink.sendOptionalOf(ClearSalePump()));

          nozzle1StreamSink.send(UpDown.up);

          await Future.delayed(Duration(seconds: 1));

          nozzle1StreamSink.send(UpDown.down);

          await clearSaleStreamReference.stream.toLegacyStream().first;

          runTransaction(() => pumpLogicStateSink.sendOptionalOf(PresetAmountPump()));

          nozzle1StreamSink.send(UpDown.up);

          await Future.delayed(Duration(seconds: 1));

          nozzle1StreamSink.send(UpDown.down);

          await clearSaleStreamReference.stream.toLegacyStream().first;
      }
    });
  });
}

Outputs switchOutputs(ValueState<Outputs> outputsState) =>
    Outputs((builder) => builder
      ..deliveryState = outputsState
          .switchMapState<Delivery>((outputs) => outputs.deliveryState)
          .distinct()
      ..saleCostLcdState = outputsState
          .switchMapState<String>((outputs) => outputs.saleCostLcdState)
          .distinct()
      ..presetLcdState = outputsState
          .switchMapState<String>((outputs) => outputs.presetLcdState)
          .distinct()
      ..saleQuantityLcdState = outputsState
          .switchMapState<String>((outputs) => outputs.saleQuantityLcdState)
          .distinct()
      ..priceLcd1State = outputsState
          .switchMapState<String>((outputs) => outputs.priceLcd1State)
          .distinct()
      ..priceLcd2State = outputsState
          .switchMapState<String>((outputs) => outputs.priceLcd2State)
          .distinct()
      ..priceLcd3State = outputsState
          .switchMapState<String>((outputs) => outputs.priceLcd3State)
          .distinct()
      ..beepStream =
          outputsState.switchMapStream<Unit>((outputs) => outputs.beepStream)
      ..saleCompleteStream = outputsState
          .switchMapStream<Sale>((outputs) => outputs.saleCompleteStream));

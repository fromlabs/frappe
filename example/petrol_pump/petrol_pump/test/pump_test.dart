import 'dart:async';

import 'package:petrol_pump/petrol_pump.dart';
import 'package:frappe/frappe.dart';
import 'package:test/test.dart';

void main() {
  group('Simple pump', () {
    EventStreamReference<int> fuelPulsesStreamRef;
    EventStreamReference<Unit> clearSaleStreamRef;
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

    ListenSubscription listenCanceler;

    Outputs outputs;

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

    setUp(() {
      fuelPulsesStreamRef = EventStreamReference<int>();
      clearSaleStreamRef = EventStreamReference<Unit>();
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
      fuelPulsesStreamRef.link(pumpEngineSimulator.fuelPulsesStream);

      posSimulator =
          PosSimulatorImpl(saleCompleteStream: outputs.saleCompleteStream);
      clearSaleStreamRef.link(posSimulator.clearSaleStream);
    });

    tearDown(() async {
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

      assertEmptyBroadcastStreamSubscribers();
    });

    test('No action', () {});

    test('Pump one round', () async {
      connectListeners();

      print('-> nozzle1: ${UpDown.up}');

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      print('-> nozzle1: ${UpDown.down}');

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 3));

      await disconnectListeners();
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
    EventStreamReference<int> fuelPulsesStreamRef;
    EventStreamReference<Unit> clearSaleStreamRef;
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
      listenCanceler = outputs.deliveryState
          .listen((e) => print('deliveryState: $e'))
          .append(pumpLogicStateSink.state
              .listen((e) => print('pumpLogicState: ${e.map((pump) => pump.runtimeType.toString()).orElse('none')}')))
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

    setUp(() {
      fuelPulsesStreamRef = EventStreamReference<int>();
      clearSaleStreamRef = EventStreamReference<Unit>();
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
              ..fuelPulsesStream = fuelPulsesStreamRef.stream
              ..calibrationState = calibrationStateSink.state
              ..price1State = price1StateSink.state
              ..price2State = price2StateSink.state
              ..price3State = price3StateSink.state
              ..clearSaleStream = clearSaleStreamRef.stream,
          ));
        } else {
          return Outputs.fromDefault();
        }
      });

      outputs = switchOutputs(outputsState);

      pumpEngineSimulator =
          PumpEngineSimulatorImpl(deliveryState: outputs.deliveryState);
      fuelPulsesStreamRef.link(pumpEngineSimulator.fuelPulsesStream);

      posSimulator =
          PosSimulatorImpl(saleCompleteStream: outputs.saleCompleteStream);
      clearSaleStreamRef.link(posSimulator.clearSaleStream);
    });

    tearDown(() async {
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
        ValueStateSinkDisposable(pumpLogicStateSink),
      ]
          .map<Future>((disposable) => disposable?.dispose())
          .where((future) => future != null));

      assertEmptyBroadcastStreamSubscribers();
    });

    test('No pump', () async {
      connectListeners();

      await disconnectListeners();
    });

    test('LifecyclePump complete', () async {
      connectListeners();

      pumpLogicStateSink.sendOptionalOf(LifecyclePump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 1));

      await disconnectListeners();
    });

    test('AccumulatePulsesPump complete', () async {
      connectListeners();

      pumpLogicStateSink.sendOptionalOf(AccumulatePulsesPump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 1));

      await disconnectListeners();
    });

    test('ShowDollarsPump complete', () async {
      connectListeners();

      pumpLogicStateSink.sendOptionalOf(ShowDollarsPump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 1));

      await disconnectListeners();
    });

    test('Clear sale pump', () async {
      connectListeners();

      pumpLogicStateSink.sendOptionalOf(ClearSalePump());

      await Future(() {});

      keypadStreamSink.send(NumericKey.one);

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 3));

      await disconnectListeners();
    });

    test('Preset pump', () async {
      connectListeners();

      pumpLogicStateSink.sendOptionalOf(PresetAmountPump());

      await Future(() {});

      keypadStreamSink.send(NumericKey.one);

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 3));

      await disconnectListeners();
    });

    test('All pumps switch', () async {
      connectListeners();

      pumpLogicStateSink.sendOptionalOf(LifecyclePump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 1));

      pumpLogicStateSink.sendOptionalOf(AccumulatePulsesPump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 1));

      pumpLogicStateSink.sendOptionalOf(ShowDollarsPump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 1));

      pumpLogicStateSink.sendOptionalOf(ClearSalePump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 3));

      pumpLogicStateSink.sendOptionalOf(PresetAmountPump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 3));

      await disconnectListeners();
    });

    test('All pumps switch two times', () async {
      connectListeners();

      pumpLogicStateSink.sendOptionalOf(LifecyclePump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 1));

      pumpLogicStateSink.sendOptionalOf(AccumulatePulsesPump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 1));

      pumpLogicStateSink.sendOptionalOf(ShowDollarsPump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 1));

      pumpLogicStateSink.sendOptionalOf(ClearSalePump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 3));

      pumpLogicStateSink.sendOptionalOf(PresetAmountPump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 3));

      await disconnectListeners();

      connectListeners();

      pumpLogicStateSink.sendOptionalOf(LifecyclePump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 1));

      pumpLogicStateSink.sendOptionalOf(AccumulatePulsesPump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 1));

      pumpLogicStateSink.sendOptionalOf(ShowDollarsPump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 1));

      pumpLogicStateSink.sendOptionalOf(ClearSalePump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 3));

      pumpLogicStateSink.sendOptionalOf(PresetAmountPump());

      await Future(() {});

      nozzle1StreamSink.send(UpDown.up);

      await Future.delayed(Duration(seconds: 1));

      nozzle1StreamSink.send(UpDown.down);

      await Future.delayed(Duration(seconds: 3));

      await disconnectListeners();
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

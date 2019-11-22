import 'package:built_collection/built_collection.dart';
import 'package:optional/optional.dart';
import 'package:quiver/iterables.dart';
import 'package:frappe/frappe.dart';

import '../util.dart';
import '../simulator/pump_engine_simulator_impl.dart';
import '../model.dart';
import '../petrol_pump.dart';

Optional<double> fromLcdMapper(String lcd) =>
    lcd.isNotEmpty ? Optional.of(double.parse(lcd)) : Optional.empty();

abstract class PetrolPumpBloc {
  OptionalValueState<Pump> get pumpLogicState;

  BuiltList<ValueState<double>> get priceSettingStates;

  BuiltList<ValueState<UpDown>> get nozzleStates;

  BuiltList<OptionalValueState<double>> get priceStates;

  OptionalValueState<double> get presetState;

  OptionalValueState<double> get saleCostState;

  OptionalValueState<double> get saleQuantityState;

  ValueState<Delivery> get deliveryState;

  EventStream<Sale> get saleCompleteStream;

  EventStream<Unit> get beepStream;

  void setPumpLogic(Optional<Pump> pump);

  void setPriceSetting(int number, double price);

  void toggleNozzle(int number);

  void pressKey(NumericKey key);

  void clearSale();

  void dispose();
}

class PetrolPumpBlocImpl implements PetrolPumpBloc {
  final OptionalValueStateSink<Pump> _pumpLogicStateSink =
      OptionalValueStateSink<Pump>.empty();
  final EventStreamSink<int> _toggleNozzleStreamSink = EventStreamSink();
  final EventStreamSink<Unit> _clearSaleStreamSink = EventStreamSink();
  final EventStreamSink<NumericKey> _keypadStreamSink = EventStreamSink();
  final BuiltList<ValueStateSink<double>> _priceSettingStateSinks =
      BuiltList.of([
    ValueStateSink<double>(2.149),
    ValueStateSink<double>(2.341),
    ValueStateSink<double>(1.499),
  ]);

  BuiltList<ValueState<double>> _priceSettingStates;
  BuiltList<ValueState<UpDown>> _nozzleStates;
  BuiltList<OptionalValueState<double>> _priceStates;

  BuiltList<ValueStateReference<ValueState<double>>>
      _priceSettingStateReferences;
  BuiltList<ValueStateReference<ValueState<UpDown>>> _nozzleStateReferences;
  BuiltList<ValueStateReference<OptionalValueState<double>>>
      _priceStateReferences;
  ValueStateReference<OptionalValueState<double>> _presetStateReference;
  ValueStateReference<OptionalValueState<double>> _saleCostStateReference;
  ValueStateReference<OptionalValueState<double>> _saleQuantityStateReference;
  EventStreamReference<EventStream<int>> _fuelPulsesStreamReference;
  EventStreamReference<EventStream<Sale>> _saleCompleteStreamReference;
  EventStreamReference<EventStream<Unit>> _beepStreamReference;
  ValueStateReference<ValueState<Delivery>> _deliveryStateReference;

  PumpEngineSimulator _pumpEngineSimulator;

  ListenSubscription _subscription;

  PetrolPumpBlocImpl() {
    runTransaction(() {
      EventStreamLink<int> _fuelPulsesStreamLink = EventStreamLink();

      _fuelPulsesStreamReference = _fuelPulsesStreamLink.stream.toReference();

      _priceSettingStateReferences = BuiltList.of(
          _priceSettingStateSinks.map((sink) => sink.state.toReference()));

      _priceSettingStates = BuiltList.of(
          _priceSettingStateReferences.map((reference) => reference.state));

      _nozzleStateReferences = BuiltList.of(range(1, 4).map((number) {
        final initialState = UpDown.down;

        final nozzleStateRef = ValueStateLink<UpDown>();

        nozzleStateRef.connect(_toggleNozzleStreamSink.stream
            .where((nozzle) => nozzle == number)
            .snapshot(nozzleStateRef.state,
                (_, nozzle) => nozzle == UpDown.up ? UpDown.down : UpDown.up)
            .toState(initialState));

        return nozzleStateRef.state.toReference();
      }));

      _nozzleStates = BuiltList.of(
          _nozzleStateReferences.map((reference) => reference.state));

      final nozzle1Stream = _nozzleStateReferences[0].state.toUpdates();
      final nozzle2Stream = _nozzleStateReferences[1].state.toUpdates();
      final nozzle3Stream = _nozzleStateReferences[2].state.toUpdates();

      final calibrationStateSink = ValueStateSink<double>(0.001);

      final outputsState = _pumpLogicStateSink.state.map((pump) {
        if (pump.isPresent) {
          return pump.value.create(Inputs.fromDefault(
            (builder) => builder
              ..nozzle1Stream = nozzle1Stream
              ..nozzle2Stream = nozzle2Stream
              ..nozzle3Stream = nozzle3Stream
              ..keypadStream = _keypadStreamSink.stream
              ..fuelPulsesStream = _fuelPulsesStreamLink.stream
              ..calibrationState = calibrationStateSink.state
              ..price1State = _priceSettingStateSinks[0].state
              ..price2State = _priceSettingStateSinks[1].state
              ..price3State = _priceSettingStateSinks[2].state
              ..clearSaleStream = _clearSaleStreamSink.stream,
          ));
        } else {
          return Outputs.fromDefault();
        }
      });

      final outputs = Outputs((builder) => builder
        ..deliveryState = outputsState
            .switchMapState((outputs) => outputs.deliveryState)
            .distinct()
        ..saleCostLcdState = outputsState
            .switchMapState((outputs) => outputs.saleCostLcdState)
            .distinct()
        ..presetLcdState = outputsState
            .switchMapState((outputs) => outputs.presetLcdState)
            .distinct()
        ..saleQuantityLcdState = outputsState
            .switchMapState((outputs) => outputs.saleQuantityLcdState)
            .distinct()
        ..priceLcd1State = outputsState
            .switchMapState((outputs) => outputs.priceLcd1State)
            .distinct()
        ..priceLcd2State = outputsState
            .switchMapState((outputs) => outputs.priceLcd2State)
            .distinct()
        ..priceLcd3State = outputsState
            .switchMapState((outputs) => outputs.priceLcd3State)
            .distinct()
        ..beepStream =
            outputsState.switchMapStream((outputs) => outputs.beepStream)
        ..saleCompleteStream = outputsState
            .switchMapStream((outputs) => outputs.saleCompleteStream));

      _pumpEngineSimulator =
          PumpEngineSimulatorImpl(deliveryState: outputs.deliveryState);
      _fuelPulsesStreamLink.connect(_pumpEngineSimulator.fuelPulsesStream);

      _priceStateReferences = BuiltList.of([
        outputs.priceLcd1State
            .map(fromLcdMapper)
            .asOptional<double>()
            .toReference(),
        outputs.priceLcd2State
            .map(fromLcdMapper)
            .asOptional<double>()
            .toReference(),
        outputs.priceLcd3State
            .map(fromLcdMapper)
            .asOptional<double>()
            .toReference(),
      ]);

      _priceStates = BuiltList.of(
          _priceStateReferences.map((reference) => reference.state));

      _presetStateReference = outputs.presetLcdState
          .map(fromLcdMapper)
          .asOptional<double>()
          .toReference();

      _saleCostStateReference = outputs.saleCostLcdState
          .map(fromLcdMapper)
          .asOptional<double>()
          .toReference();

      _saleQuantityStateReference = outputs.saleQuantityLcdState
          .map(fromLcdMapper)
          .asOptional<double>()
          .toReference();

      _saleCompleteStreamReference = outputs.saleCompleteStream.toReference();

      _beepStreamReference = outputs.beepStream.toReference();

      _deliveryStateReference = outputs.deliveryState.toReference();

      _subscription = ListenSubscription()
        ..append(outputs.saleCostLcdState.listen(print));
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _fuelPulsesStreamReference.dispose();
    _priceSettingStateReferences.dispose();
    _nozzleStateReferences.dispose();
    _priceStateReferences.dispose();
    _presetStateReference.dispose();
    _saleCostStateReference.dispose();
    _saleQuantityStateReference.dispose();
    _saleCompleteStreamReference.dispose();
    _deliveryStateReference.dispose();
    _beepStreamReference.dispose();
    _pumpLogicStateSink.close();
    _toggleNozzleStreamSink.close();
    _pumpEngineSimulator.dispose();
  }

  @override
  OptionalValueState<Pump> get pumpLogicState => _pumpLogicStateSink.state;

  @override
  BuiltList<ValueState<double>> get priceSettingStates => _priceSettingStates;

  @override
  BuiltList<ValueState<UpDown>> get nozzleStates => _nozzleStates;

  @override
  BuiltList<OptionalValueState<double>> get priceStates => _priceStates;

  @override
  OptionalValueState<double> get presetState => _presetStateReference.state;

  @override
  OptionalValueState<double> get saleCostState => _saleCostStateReference.state;

  @override
  OptionalValueState<double> get saleQuantityState =>
      _saleQuantityStateReference.state;

  @override
  EventStream<Sale> get saleCompleteStream =>
      _saleCompleteStreamReference.stream;

  @override
  EventStream<Unit> get beepStream => _beepStreamReference.stream;

  @override
  ValueState<Delivery> get deliveryState => _deliveryStateReference.state;

  @override
  void toggleNozzle(int number) {
    print('toggleNozzle(number: $number)');

    _toggleNozzleStreamSink.send(number);
  }

  @override
  void pressKey(NumericKey key) {
    print('pressKey(key: $key)');

    _keypadStreamSink.send(key);
  }

  @override
  void setPumpLogic(Optional<Pump> pump) {
    print('setPumpLogic(pump: $pump)');

    _pumpLogicStateSink.send(pump);
  }

  @override
  void setPriceSetting(int number, double price) {
    print('setPriceSetting(number: $number, price: $price)');

    _priceSettingStateSinks[number - 1].send(price);
  }

  @override
  void clearSale() {
    print('clearSale()');

    _clearSaleStreamSink.send(unit);
  }
}

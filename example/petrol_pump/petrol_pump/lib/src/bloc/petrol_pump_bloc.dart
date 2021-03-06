import 'package:built_collection/built_collection.dart';
import 'package:optional/optional.dart';
import 'package:quiver/iterables.dart';
import 'package:frappe/frappe.dart';

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

  final _references = FrappeReferenceCollector();

  ListenSubscription _subscriptions;

  BuiltList<ValueState<double>> _priceSettingStates;
  BuiltList<ValueState<UpDown>> _nozzleStates;
  BuiltList<OptionalValueState<double>> _priceStates;
  OptionalValueState<double> _presetState;
  OptionalValueState<double> _saleCostState;
  OptionalValueState<double> _saleQuantityState;
  EventStream<Sale> _saleCompleteStream;
  EventStream<Unit> _beepStream;
  ValueState<Delivery> _deliveryState;

  PumpEngineSimulator _pumpEngineSimulator;

  PetrolPumpBlocImpl() {
    runTransaction(() {
      final _fuelPulsesStreamLink = EventStreamLink<int>();

      _references.add(_fuelPulsesStreamLink.stream);

      _priceSettingStates = BuiltList.of(
          _priceSettingStateSinks.map((sink) => _references.add(sink.state)));

      _nozzleStates = BuiltList.of(range(1, 4).map((number) {
        final initialState = UpDown.down;

        final nozzleStateRef = ValueStateLink<UpDown>();

        nozzleStateRef.connect(_toggleNozzleStreamSink.stream
            .where((nozzle) => nozzle == number)
            .snapshot(nozzleStateRef.state,
                (_, nozzle) => nozzle == UpDown.up ? UpDown.down : UpDown.up)
            .toState(initialState));

        return _references.add(nozzleStateRef.state);
      }));

      final nozzle1Stream = _nozzleStates[0].toUpdates();
      final nozzle2Stream = _nozzleStates[1].toUpdates();
      final nozzle3Stream = _nozzleStates[2].toUpdates();

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

      _priceStates = BuiltList.of([
        _references.add(
            outputs.priceLcd1State.map(fromLcdMapper).asOptional<double>()),
        _references.add(
            outputs.priceLcd2State.map(fromLcdMapper).asOptional<double>()),
        _references.add(
            outputs.priceLcd3State.map(fromLcdMapper).asOptional<double>()),
      ]);

      _presetState = _references
          .add(outputs.presetLcdState.map(fromLcdMapper).asOptional<double>());

      _saleCostState = _references.add(
          outputs.saleCostLcdState.map(fromLcdMapper).asOptional<double>());

      _saleQuantityState = _references.add(
          outputs.saleQuantityLcdState.map(fromLcdMapper).asOptional<double>());

      _saleCompleteStream = _references.add(outputs.saleCompleteStream);

      _beepStream = _references.add(outputs.beepStream);

      _deliveryState = _references.add(outputs.deliveryState);

      _subscriptions = ListenSubscription()
        ..append(outputs.saleCostLcdState.listen(print));
    });
  }

  @override
  void dispose() {
    _subscriptions.cancel();
    _references.dispose();
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
  OptionalValueState<double> get presetState => _presetState;

  @override
  OptionalValueState<double> get saleCostState => _saleCostState;

  @override
  OptionalValueState<double> get saleQuantityState => _saleQuantityState;

  @override
  EventStream<Sale> get saleCompleteStream => _saleCompleteStream;

  @override
  EventStream<Unit> get beepStream => _beepStream;

  @override
  ValueState<Delivery> get deliveryState => _deliveryState;

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

import 'package:frappe/frappe.dart';

import '../simulator/pump_engine_simulator_impl.dart';
import '../model.dart';
import '../petrol_pump.dart';

/// Converts an LCD display string to a nullable double.
///
/// Returns `null` for empty strings (no value displayed), otherwise
/// parses the numeric text.
double? _fromLcdMapper(String lcd) =>
    lcd.isNotEmpty ? double.parse(lcd) : null;

/// The petrol pump business logic coordinator.
///
/// Exposes reactive outputs for the UI and imperative methods for user
/// actions. The active pump logic can be swapped at runtime via
/// [setPumpLogic].
abstract class PetrolPumpBloc {
  /// The currently selected pump logic algorithm, or `null` if none.
  ValueState<Pump?> get pumpLogicState;

  /// Editable price settings for each fuel type (indexed 0-2).
  List<ValueState<double>> get priceSettingStates;

  /// Current up/down position of each nozzle (indexed 0-2).
  List<ValueState<UpDown>> get nozzleStates;

  /// Per-unit price displayed for each fuel type, or `null` when blank.
  List<ValueState<double?>> get priceStates;

  /// Preset dollar amount entered via the keypad, or `null` when blank.
  ValueState<double?> get presetState;

  /// Running cost of the current sale, or `null` when no sale is active.
  ValueState<double?> get saleCostState;

  /// Running quantity of the current sale, or `null` when no sale is active.
  ValueState<double?> get saleQuantityState;

  /// Current fuel delivery speed.
  ValueState<Delivery> get deliveryState;

  /// Fires with the completed [Sale] when fueling finishes.
  EventStream<Sale> get saleCompleteStream;

  /// Fires when the pump should emit a beep sound.
  EventStream<Unit> get beepStream;

  /// Sets or clears the active pump logic algorithm.
  void setPumpLogic(Pump? pump);

  /// Updates the price setting for fuel type [number] (1-based).
  void setPriceSetting(int number, double price);

  /// Toggles the nozzle identified by [number] (1-based) between up and down.
  void toggleNozzle(int number);

  /// Sends a keypad key press into the reactive graph.
  void pressKey(NumericKey key);

  /// Signals the POS terminal to clear the completed sale.
  void clearSale();

  /// Releases all resources held by this bloc.
  void dispose();
}

/// Default implementation of [PetrolPumpBloc].
///
/// Wires up all reactive inputs, simulators, and outputs in a single
/// transaction during construction. The pump logic can be swapped at
/// runtime; all output states are derived via [switchMapState] so they
/// automatically track the active logic.
class PetrolPumpBlocImpl implements PetrolPumpBloc {
  late final ValueStateSink<Pump?> _pumpLogicStateSink;
  late final EventStreamSink<int> _toggleNozzleStreamSink;
  late final EventStreamSink<Unit> _clearSaleStreamSink;
  late final EventStreamSink<NumericKey> _keypadStreamSink;
  late final List<ValueStateSink<double>> _priceSettingStateSinks;

  final _references = FrappeReferenceCollector();

  late ListenSubscription _subscriptions;

  late List<ValueState<double>> _priceSettingStates;
  late List<ValueState<UpDown>> _nozzleStates;
  late List<ValueState<double?>> _priceStates;
  late ValueState<double?> _presetState;
  late ValueState<double?> _saleCostState;
  late ValueState<double?> _saleQuantityState;
  late EventStream<Sale> _saleCompleteStream;
  late EventStream<Unit> _beepStream;
  late ValueState<Delivery> _deliveryState;

  late PumpEngineSimulator _pumpEngineSimulator;

  /// Creates the bloc and wires up the entire reactive graph.
  ///
  /// All sinks, links, nozzle states, and output switchMaps are
  /// constructed within a single transaction to ensure atomic setup.
  PetrolPumpBlocImpl() {
    runTransaction(() {
      _pumpLogicStateSink = ValueStateSink<Pump?>(null);
      _toggleNozzleStreamSink = EventStreamSink();
      _clearSaleStreamSink = EventStreamSink();
      _keypadStreamSink = EventStreamSink();
      _priceSettingStateSinks = [
        ValueStateSink<double>(2.149),
        ValueStateSink<double>(2.341),
        ValueStateSink<double>(1.499),
      ];

      final fuelPulsesStreamLink = EventStreamLink<int>();
      _references.add(fuelPulsesStreamLink.stream);

      _priceSettingStates = _priceSettingStateSinks
          .map((sink) => _references.add(sink.state))
          .toList();

      // Create 3 nozzle toggle states with cyclic feedback.
      // Each nozzle uses a ValueStateLink for forward-declaration: the
      // toggle stream snapshots the nozzle's own current value to flip it,
      // creating a self-referential cycle that the link resolves.
      _nozzleStates = List.generate(3, (i) {
        final number = i + 1;
        final nozzleStateRef = ValueStateLink<UpDown>();

        nozzleStateRef.connect(_toggleNozzleStreamSink.stream
            .where((nozzle) => nozzle == number)
            .snapshot(nozzleStateRef.state,
                (_, nozzle) => nozzle == UpDown.up ? UpDown.down : UpDown.up)
            .toState(UpDown.down));

        return _references.add(nozzleStateRef.state);
      });

      // These derived streams live across transactions (captured in the map
      // closure below, evaluated when setPumpLogic fires). They must be
      // referenced to prevent onUnreferenced from disconnecting them
      // from their source states between the creation and evaluation.
      final nozzle1Stream = _references.add(_nozzleStates[0].toUpdates());
      final nozzle2Stream = _references.add(_nozzleStates[1].toUpdates());
      final nozzle3Stream = _references.add(_nozzleStates[2].toUpdates());

      final calibrationStateSink = ValueStateSink<double>(0.001);
      _references.add(calibrationStateSink.state);

      // Map the selected pump logic to outputs via switchMapState.
      final outputsState = _pumpLogicStateSink.state.map((pump) {
        if (pump != null) {
          return pump.create(Inputs.defaults(
            nozzle1Stream: nozzle1Stream,
            nozzle2Stream: nozzle2Stream,
            nozzle3Stream: nozzle3Stream,
            keypadStream: _keypadStreamSink.stream,
            fuelPulsesStream: fuelPulsesStreamLink.stream,
            calibrationState: calibrationStateSink.state,
            price1State: _priceSettingStateSinks[0].state,
            price2State: _priceSettingStateSinks[1].state,
            price3State: _priceSettingStateSinks[2].state,
            clearSaleStream: _clearSaleStreamSink.stream,
          ));
        } else {
          return Outputs.defaults();
        }
      });

      // Switch each output field through the dynamic pump logic.
      // switchMapState/switchMapStream re-subscribes to the inner state
      // whenever the pump logic changes, so swapping algorithms at runtime
      // seamlessly redirects all output bindings.
      final outputs = Outputs(
        deliveryState: outputsState
            .switchMapState((outputs) => outputs.deliveryState)
            .distinct(),
        saleCostLcdState: outputsState
            .switchMapState((outputs) => outputs.saleCostLcdState)
            .distinct(),
        presetLcdState: outputsState
            .switchMapState((outputs) => outputs.presetLcdState)
            .distinct(),
        saleQuantityLcdState: outputsState
            .switchMapState((outputs) => outputs.saleQuantityLcdState)
            .distinct(),
        priceLcd1State: outputsState
            .switchMapState((outputs) => outputs.priceLcd1State)
            .distinct(),
        priceLcd2State: outputsState
            .switchMapState((outputs) => outputs.priceLcd2State)
            .distinct(),
        priceLcd3State: outputsState
            .switchMapState((outputs) => outputs.priceLcd3State)
            .distinct(),
        beepStream:
            outputsState.switchMapStream((outputs) => outputs.beepStream),
        saleCompleteStream: outputsState
            .switchMapStream((outputs) => outputs.saleCompleteStream),
      );

      _pumpEngineSimulator =
          PumpEngineSimulatorImpl(deliveryState: outputs.deliveryState);
      fuelPulsesStreamLink.connect(_pumpEngineSimulator.fuelPulsesStream);

      _priceStates = [
        _references.add(outputs.priceLcd1State.map(_fromLcdMapper)),
        _references.add(outputs.priceLcd2State.map(_fromLcdMapper)),
        _references.add(outputs.priceLcd3State.map(_fromLcdMapper)),
      ];

      _presetState =
          _references.add(outputs.presetLcdState.map(_fromLcdMapper));
      _saleCostState =
          _references.add(outputs.saleCostLcdState.map(_fromLcdMapper));
      _saleQuantityState =
          _references.add(outputs.saleQuantityLcdState.map(_fromLcdMapper));

      _saleCompleteStream = _references.add(outputs.saleCompleteStream);
      _beepStream = _references.add(outputs.beepStream);
      _deliveryState = _references.add(outputs.deliveryState);

      _subscriptions = outputs.saleCostLcdState.listen(print);
    });
  }

  @override
  void dispose() {
    _subscriptions.cancel();
    _references.dispose();
    _pumpEngineSimulator.dispose();
  }

  @override
  ValueState<Pump?> get pumpLogicState => _pumpLogicStateSink.state;

  @override
  List<ValueState<double>> get priceSettingStates => _priceSettingStates;

  @override
  List<ValueState<UpDown>> get nozzleStates => _nozzleStates;

  @override
  List<ValueState<double?>> get priceStates => _priceStates;

  @override
  ValueState<double?> get presetState => _presetState;

  @override
  ValueState<double?> get saleCostState => _saleCostState;

  @override
  ValueState<double?> get saleQuantityState => _saleQuantityState;

  @override
  EventStream<Sale> get saleCompleteStream => _saleCompleteStream;

  @override
  EventStream<Unit> get beepStream => _beepStream;

  @override
  ValueState<Delivery> get deliveryState => _deliveryState;

  @override
  void toggleNozzle(int number) {
    _toggleNozzleStreamSink.send(number);
  }

  @override
  void pressKey(NumericKey key) {
    _keypadStreamSink.send(key);
  }

  @override
  void setPumpLogic(Pump? pump) {
    _pumpLogicStateSink.send(pump);
  }

  @override
  void setPriceSetting(int number, double price) {
    _priceSettingStateSinks[number - 1].send(price);
  }

  @override
  void clearSale() {
    _clearSaleStreamSink.send(unit);
  }
}

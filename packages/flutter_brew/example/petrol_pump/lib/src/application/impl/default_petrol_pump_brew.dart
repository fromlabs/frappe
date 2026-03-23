import 'package:brew/brew.dart';
import 'package:frappe/frappe.dart';

import '../../domain/models.dart';
import '../../domain/port/pump.dart';
import '../../domain/port/pump_engine.dart';
import '../../infrastructure/pump_engine_simulator.dart';
import '../petrol_pump.dart';

/// Converts an LCD display string to a nullable double.
///
/// Returns `null` for empty strings (no value displayed), otherwise
/// parses the numeric text.
double? _fromLcdMapper(String lcd) =>
    lcd.isNotEmpty ? double.parse(lcd) : null;

/// Default implementation of [PetrolPumpBrew].
///
/// Wires up all reactive inputs, simulators, and outputs in a single
/// transaction during [onBind]. The pump logic can be swapped at runtime;
/// all output states are derived via [switchMapState] so they automatically
/// track the active logic.
class DefaultPetrolPumpBrew extends BaseBrew implements PetrolPumpBrew {
  @override
  late final ValueState<Pump?> pumpLogicState;

  @override
  late final List<ValueState<double>> priceSettingStates;

  @override
  late final List<ValueState<UpDown>> nozzleStates;

  @override
  late final List<ValueState<double?>> priceStates;

  @override
  late final ValueState<double?> presetState;

  @override
  late final ValueState<double?> saleCostState;

  @override
  late final ValueState<double?> saleQuantityState;

  @override
  late final ValueState<Delivery> deliveryState;

  @override
  late final EventStream<Sale> saleCompleteStream;

  @override
  late final EventStream<Unit> beepStream;

  late final ValueStateSink<Pump?> _pumpLogicSink;
  late final EventStreamSink<int> _toggleNozzleSink;
  late final EventStreamSink<Unit> _clearSaleSink;
  late final EventStreamSink<NumericKey> _keypadSink;
  late final List<ValueStateSink<double>> _priceSettingSinks;

  late final PumpEngine _pumpEngine;
  late final ListenSubscription _debugSubscription;

  @override
  void onBind() {
    runTransaction(() {
      // Create sinks — collectStreamSink/collectStateSink auto-registers
      // the underlying stream/state for disposal.
      _pumpLogicSink = collectStateSink<Pump?>(null);
      _toggleNozzleSink = collectStreamSink<int>();
      _clearSaleSink = collectStreamSink<Unit>();
      _keypadSink = collectStreamSink<NumericKey>();
      _priceSettingSinks = [
        collectStateSink<double>(2.149),
        collectStateSink<double>(2.341),
        collectStateSink<double>(1.499),
      ];

      final fuelPulsesLink = collectStreamLink<int>();
      final calibrationSink = collectStateSink<double>(0.001);

      pumpLogicState = _pumpLogicSink.state;
      priceSettingStates =
          _priceSettingSinks.map((s) => s.state).toList();

      // Nozzle toggle states with cyclic feedback: each nozzle snapshots
      // its own current value to flip it on toggle.
      nozzleStates = List.generate(3, (i) {
        return collect(ValueState.loop<UpDown>((self, connect) {
          connect(_toggleNozzleSink.stream
              .where((n) => n == i + 1)
              .snapshot(self,
                  (_, cur) => cur == UpDown.up ? UpDown.down : UpDown.up)
              .toState(UpDown.down));
        }));
      });

      // Build shared inputs — sinks are already collected, only toUpdates()
      // derived streams need explicit collection.
      final inputs = Inputs(
        nozzle1Stream: collect(nozzleStates[0].toUpdates()),
        nozzle2Stream: collect(nozzleStates[1].toUpdates()),
        nozzle3Stream: collect(nozzleStates[2].toUpdates()),
        keypadStream: _keypadSink.stream,
        fuelPulsesStream: fuelPulsesLink.stream,
        calibrationState: calibrationSink.state,
        price1State: _priceSettingSinks[0].state,
        price2State: _priceSettingSinks[1].state,
        price3State: _priceSettingSinks[2].state,
        clearSaleStream: _clearSaleSink.stream,
      );

      // Map the selected pump logic to outputs via switchMapState.
      // Swapping algorithms at runtime seamlessly redirects all output bindings.
      final outputsState = _pumpLogicSink.state.map((pump) =>
          pump?.create(inputs) ?? Outputs.defaults());
      final outputs = Outputs.switchFrom(outputsState);

      // Simulator: pump engine generates pulses based on delivery speed.
      _pumpEngine = DefaultPumpEngine(
        deliveryState: outputs.deliveryState,
      );
      fuelPulsesLink.connect(_pumpEngine.fuelPulsesStream);

      // Collect all output states for UI consumption.
      deliveryState = collect(outputs.deliveryState);
      beepStream = collect(outputs.beepStream);
      saleCompleteStream = collect(outputs.saleCompleteStream);

      // Map LCD strings to nullable doubles for UI display.
      priceStates = [
        collect(outputs.priceLcd1State.map(_fromLcdMapper)),
        collect(outputs.priceLcd2State.map(_fromLcdMapper)),
        collect(outputs.priceLcd3State.map(_fromLcdMapper)),
      ];
      presetState = collect(outputs.presetLcdState.map(_fromLcdMapper));
      saleCostState = collect(outputs.saleCostLcdState.map(_fromLcdMapper));
      saleQuantityState =
          collect(outputs.saleQuantityLcdState.map(_fromLcdMapper));

      _debugSubscription = outputs.saleCostLcdState.listen(print);
    });
  }

  @override
  void dispose() {
    _debugSubscription.cancel();
    _pumpEngine.dispose();
    super.dispose();
  }

  @override
  void setPumpLogic(Pump? pump) => _pumpLogicSink.send(pump);

  @override
  void setPriceSetting(int number, double price) =>
      _priceSettingSinks[number - 1].send(price);

  @override
  void toggleNozzle(int number) => _toggleNozzleSink.send(number);

  @override
  void pressKey(NumericKey key) => _keypadSink.send(key);

  @override
  void clearSale() => _clearSaleSink.send(unit);
}

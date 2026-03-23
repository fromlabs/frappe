import 'package:brew/brew.dart';
import 'package:frappe/frappe.dart';

import '../domain/models.dart';
import '../domain/port/pump.dart';

/// The petrol pump business logic contract for the UI layer.
///
/// Extends [Brew] for lifecycle management via `BrewProvider`, but does
/// not expose any implementation details (collect, onBind). The UI
/// depends only on reactive outputs and imperative action methods.
abstract class PetrolPumpBrew extends Brew {
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
}

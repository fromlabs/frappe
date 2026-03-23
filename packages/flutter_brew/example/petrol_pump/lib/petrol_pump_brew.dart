/// Petrol Pump FRP example — Brew edition with hexagonal architecture.
///
/// A conversion of the Sodium FRP book's petrol pump example,
/// demonstrating functional reactive programming with frappe and brew.
library;

// Domain — models.
export 'src/domain/model/delivery.dart';
export 'src/domain/model/fuel.dart';
export 'src/domain/model/inputs.dart';
export 'src/domain/model/numeric_key.dart';
export 'src/domain/model/outputs.dart';
export 'src/domain/model/sale.dart';
export 'src/domain/model/up_down.dart';

// Domain — ports.
export 'src/domain/port/pump.dart';
export 'src/domain/port/pump_engine.dart';
export 'src/domain/port/pos_terminal.dart';

// Domain — logic.
export 'src/domain/logic/accumulate.dart';
export 'src/domain/logic/fill.dart';
export 'src/domain/logic/keypad.dart';
export 'src/domain/logic/lifecycle.dart';
export 'src/domain/logic/notify_point_of_sale.dart';
export 'src/domain/logic/preset.dart';
export 'src/domain/logic/price_lcd.dart';

// Application — pump implementations.
export 'src/application/pump/accumulate_pulses_pump.dart';
export 'src/application/pump/clear_sale_pump.dart';
export 'src/application/pump/keypad_pump.dart';
export 'src/application/pump/lifecycle_pump.dart';
export 'src/application/pump/preset_amount_pump.dart';
export 'src/application/pump/show_dollars_pump.dart';

// Application — brew orchestrator.
export 'src/application/petrol_pump_brew.dart';
export 'src/application/impl/default_petrol_pump_brew.dart';

// Infrastructure.
export 'src/infrastructure/pump_engine_simulator.dart';
export 'src/infrastructure/pos_simulator.dart';

// Utilities.
export 'src/util.dart';

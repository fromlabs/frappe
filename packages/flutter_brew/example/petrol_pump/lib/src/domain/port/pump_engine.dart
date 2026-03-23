import 'package:frappe/frappe.dart';

/// A pump engine simulator that produces fuel pulses.
abstract class PumpEngine implements Disposable {
  /// Stream of fuel pulse counts emitted at a fixed tick rate.
  EventStream<int> get fuelPulsesStream;
}

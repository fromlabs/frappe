import 'package:frappe/frappe.dart';

import 'model.dart';

typedef Outputs createPump(Inputs inputs);

abstract class Pump {
  Outputs create(Inputs inputs);
}

abstract class PosSimulator implements Disposable {
  EventStream<Unit> get clearSaleStream;
}

abstract class PumpEngineSimulator implements Disposable {
  EventStream<int> get fuelPulsesStream;
}

abstract class BasePump implements Pump {
  @override
  String toString() => runtimeType.toString();
}

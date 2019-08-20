import 'dart:async';

import 'package:frappe/frappe.dart';

import 'model.dart';

typedef Outputs createPump(Inputs inputs);

abstract class Pump {
  Outputs create(Inputs inputs);

  void dispose();
}

abstract class PosSimulator implements Disposable {
  EventStream<Unit> get clearSaleStream;
}

abstract class PumpEngineSimulator implements Disposable {
  EventStream<int> get fuelPulsesStream;
}

abstract class BasePump extends BaseObserver implements Pump {
  @override
  String toString() => runtimeType.toString();
}

abstract class BaseObserver {
  final List<StreamSubscription> _subscriptions = [];

  void addSubscription(StreamSubscription subscription) =>
      _subscriptions.add(subscription);

  void dispose() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
  }
}

import 'package:frappe/frappe.dart';

import '../model.dart';
import '../petrol_pump.dart';
import '../util.dart';

/// Simulates a pump engine that generates fuel pulses based on delivery speed.
class PumpEngineSimulatorImpl implements PumpEngineSimulator {
  final ValueState<Delivery> _deliveryState;

  final EventStreamSink<int> _fuelPulsesStreamSink = EventStreamSink();
  final EventStreamSink<Unit> _disposeStreamSink = EventStreamSink();

  PumpEngineSimulatorImpl({required ValueState<Delivery> deliveryState})
      : _deliveryState = deliveryState {
    _start();
  }

  @override
  EventStream<int> get fuelPulsesStream => _fuelPulsesStreamSink.stream;

  @override
  void dispose() {
    _disposeStreamSink.send(unit);
  }

  Future<void> _start() async {
    final tickerTimer = PeriodicTimer(const Duration(milliseconds: 200));

    late ListenSubscription subscription;

    try {
      final disposePendingState =
          _disposeStreamSink.stream.mapTo(true).toState(false);

      subscription = tickerTimer.stream
          .gate(disposePendingState.map((pending) => !pending))
          .listen((_) async {
        // Determine pulse count based on current delivery speed.
        final pulses = switch (_deliveryState.getValue()) {
          Delivery.fast1 || Delivery.fast2 || Delivery.fast3 => 40,
          Delivery.slow1 || Delivery.slow2 || Delivery.slow3 => 2,
          Delivery.off => 0,
        };

        if (pulses > 0 && !_fuelPulsesStreamSink.isClosed) {
          await Future<void>(() {});
          if (!_fuelPulsesStreamSink.isClosed) {
            _fuelPulsesStreamSink.send(pulses);
          }
        }
      });

      await _disposeStreamSink.stream.first();
    } finally {
      subscription.cancel();
      tickerTimer.dispose();
    }
  }
}

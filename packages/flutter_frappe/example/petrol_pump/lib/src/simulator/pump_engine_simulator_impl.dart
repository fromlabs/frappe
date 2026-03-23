import 'package:frappe/frappe.dart';

import '../model.dart';
import '../petrol_pump.dart';
import '../util.dart';

/// Simulates a pump engine that generates fuel pulses based on delivery speed.
///
/// A periodic timer ticks at a fixed rate and emits a pulse count
/// proportional to the current [Delivery] speed (fast = 40, slow = 2,
/// off = 0). Dispose stops the timer via a dispose-signal stream.
class PumpEngineSimulatorImpl implements PumpEngineSimulator {
  final ValueState<Delivery> _deliveryState;

  final EventStreamSink<int> _fuelPulsesStreamSink = EventStreamSink();
  final EventStreamSink<Unit> _disposeStreamSink = EventStreamSink();

  /// Creates a pump engine simulator driven by [deliveryState].
  ///
  /// Starts the internal periodic timer immediately upon construction.
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

  /// Starts the periodic pulse generation loop.
  ///
  /// Runs until [dispose] is called, at which point the dispose stream
  /// fires, the gate closes, and the finally block cleans up resources.
  Future<void> _start() async {
    // Tick every 200ms to simulate engine rotation speed.
    final tickerTimer = PeriodicTimer(const Duration(milliseconds: 200));

    late ListenSubscription subscription;

    try {
      // Track whether dispose has been requested so the gate can block
      // further ticks from producing pulses.
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
          // Yield to the event loop so the transaction from the timer tick
          // completes before we start a new one with the pulse event.
          await Future<void>(() {});
          if (!_fuelPulsesStreamSink.isClosed) {
            _fuelPulsesStreamSink.send(pulses);
          }
        }
      });

      // Block until dispose is signaled, keeping _start alive.
      await _disposeStreamSink.stream.first();
    } finally {
      subscription.cancel();
      tickerTimer.dispose();
    }
  }
}

import 'dart:async';

import 'package:frappe/frappe.dart';

import '../domain/models.dart';
import '../domain/port/pump_engine.dart';

/// A periodic timer that emits [Unit] events at a fixed interval.
class _PeriodicTimer {
  /// The interval between ticks.
  final Duration period;

  final EventStreamSink<Unit> _timerStreamSink = EventStreamSink();
  StreamSubscription<dynamic>? _timerSubscription;

  /// Creates a periodic timer that starts ticking immediately at [period].
  _PeriodicTimer(this.period) {
    _timerSubscription =
        Stream.periodic(period).listen((_) => _timerStreamSink.send(unit));
  }

  /// The event stream of timer ticks.
  EventStream<Unit> get stream => _timerStreamSink.stream;

  /// Stops the timer.
  void dispose() {
    _timerSubscription?.cancel();
    _timerSubscription = null;
  }
}

/// Convenience extension for converting [EventStream] to a [Future].
extension _EventStreamFuture<E> on EventStream<E> {
  /// Returns a [Future] that completes with the first event.
  Future<E> first() async {
    final completer = Completer<E>();
    listenOnce(completer.complete);
    return completer.future;
  }
}

/// Simulates a pump engine that generates fuel pulses based on delivery speed.
///
/// A periodic timer ticks at a fixed rate and emits a pulse count
/// proportional to the current [Delivery] speed (fast = 40, slow = 2,
/// off = 0). Dispose stops the timer via a dispose-signal stream.
class DefaultPumpEngine implements PumpEngine {
  final ValueState<Delivery> _deliveryState;

  final EventStreamSink<int> _fuelPulsesStreamSink = EventStreamSink();
  final EventStreamSink<Unit> _disposeStreamSink = EventStreamSink();

  /// Creates a pump engine simulator driven by [deliveryState].
  ///
  /// Starts the internal periodic timer immediately upon construction.
  DefaultPumpEngine({required ValueState<Delivery> deliveryState})
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
    final tickerTimer = _PeriodicTimer(const Duration(milliseconds: 200));

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

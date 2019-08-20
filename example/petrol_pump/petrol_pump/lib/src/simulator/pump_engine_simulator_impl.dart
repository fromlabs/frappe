import 'dart:async';

import 'package:meta/meta.dart';
import 'package:frappe/frappe.dart';

import '../model.dart';
import '../petrol_pump.dart';

class PumpEngineSimulatorImpl implements PumpEngineSimulator {
  Future<void> _stopFuture;

  final ValueState<Delivery> _deliveryState;

  final EventStreamSink<int> _fuelPulsesStreamSink = EventStreamSink();
  final EventStreamSink<Unit> _disposeStreamSink = EventStreamSink();

  PumpEngineSimulatorImpl({@required ValueState<Delivery> deliveryState})
      : _deliveryState = deliveryState {
    _stopFuture = _start();
  }

  @override
  EventStream<int> get fuelPulsesStream => _fuelPulsesStreamSink.stream;

  @override
  Future<void> dispose() async {
    _disposeStreamSink.send(unit);

    await _stopFuture;

    await _fuelPulsesStreamSink.close();
    await _disposeStreamSink.close();
  }

  Future<void> _start() async {
    // connect to delivery state
    var subscription = _deliveryState.listen(null);

    try {
      final disposePendingState =
          _disposeStreamSink.stream.mapTo(true).toState(false);

      EventStream<Unit> tickStream = createEventStreamFromStream(
              Stream.periodic(Duration(milliseconds: 200)).asBroadcastStream())
          .mapTo(unit);

      subscription = subscription.append(tickStream
          .gate(disposePendingState.map((pending) => !pending))
          .listen((_) {
        int pulses;
        switch (_deliveryState.current) {
          case Delivery.fast1:
          case Delivery.fast2:
          case Delivery.fast3:
            pulses = 40;
            break;
          case Delivery.slow1:
          case Delivery.slow2:
          case Delivery.slow3:
            pulses = 2;
            break;
          case Delivery.off:
            pulses = 0;
            break;
        }

        if (pulses > 0) {
          _fuelPulsesStreamSink.send(pulses);
        }
      }));

      await _disposeStreamSink.stream.legacyStream.first;
    } finally {
      await subscription.cancel();
    }
  }
}

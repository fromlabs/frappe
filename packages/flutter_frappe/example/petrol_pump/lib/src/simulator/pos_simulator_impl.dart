import 'package:frappe/frappe.dart';

import '../model.dart';
import '../petrol_pump.dart';
import '../util.dart';

/// Simulates a point-of-sale terminal that automatically clears sales
/// after a short delay.
class PosSimulatorImpl implements PosSimulator {
  final EventStream<Sale> _saleCompleteStream;

  final EventStreamSink<Unit> _clearSaleStreamSink = EventStreamSink();
  final EventStreamSink<Unit> _disposeStreamSink = EventStreamSink();

  PosSimulatorImpl({required EventStream<Sale> saleCompleteStream})
      : _saleCompleteStream = saleCompleteStream {
    _start();
  }

  @override
  EventStream<Unit> get clearSaleStream => _clearSaleStreamSink.stream;

  @override
  void dispose() {
    _disposeStreamSink.send(unit);
  }

  Future<void> _start() async {
    late ListenSubscription subscription;

    try {
      subscription = _saleCompleteStream.listen((sale) async {
        // Simulate POS processing delay.
        await Future<void>.delayed(const Duration(seconds: 2));
        _clearSaleStreamSink.send(unit);
      });

      final salePendingState = _saleCompleteStream
          .mapTo(true)
          .orElse(_clearSaleStreamSink.stream.mapTo(false))
          .toState(false);

      final disposePendingState =
          _disposeStreamSink.stream.mapTo(true).toState(false);

      // Wait until dispose is requested AND no sale is pending.
      final stopStream = _disposeStreamSink.stream
          .gate(salePendingState.map((pending) => !pending))
          .orElse(_clearSaleStreamSink.stream.gate(disposePendingState));

      await stopStream.first();
    } finally {
      subscription.cancel();
    }
  }
}

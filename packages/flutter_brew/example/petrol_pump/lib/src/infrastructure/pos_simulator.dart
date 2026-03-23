import 'dart:async';

import 'package:frappe/frappe.dart';

import '../domain/models.dart';
import '../domain/port/pos_terminal.dart';

/// Simulates a point-of-sale terminal that automatically clears sales
/// after a short delay.
///
/// When a sale completes, the simulator waits 2 seconds (mimicking POS
/// processing) and then fires a clear-sale event. Dispose waits for any
/// pending sale to be cleared before shutting down.
class DefaultPosTerminal implements PosTerminal {
  final EventStream<Sale> _saleCompleteStream;

  final EventStreamSink<Unit> _clearSaleStreamSink = EventStreamSink();
  final EventStreamSink<Unit> _disposeStreamSink = EventStreamSink();

  /// Creates a POS simulator that listens to [saleCompleteStream].
  ///
  /// Starts listening immediately upon construction.
  DefaultPosTerminal({required EventStream<Sale> saleCompleteStream})
      : _saleCompleteStream = saleCompleteStream {
    _start();
  }

  @override
  EventStream<Unit> get clearSaleStream => _clearSaleStreamSink.stream;

  @override
  void dispose() {
    _disposeStreamSink.send(unit);
  }

  /// Starts the sale-listening loop.
  ///
  /// Runs until [dispose] is called and no sale is pending, ensuring
  /// every completed sale is properly cleared before shutdown.
  Future<void> _start() async {
    late ListenSubscription subscription;

    try {
      subscription = _saleCompleteStream.listen((sale) async {
        // Simulate POS processing delay.
        await Future<void>.delayed(const Duration(seconds: 2));
        _clearSaleStreamSink.send(unit);
      });

      // Track whether a sale is in-flight (received but not yet cleared).
      final salePendingState = _saleCompleteStream
          .mapTo(true)
          .orElse(_clearSaleStreamSink.stream.mapTo(false))
          .toState(false);

      final disposePendingState =
          _disposeStreamSink.stream.mapTo(true).toState(false);

      // Stop condition: dispose requested AND no sale pending.
      final stopStream = _disposeStreamSink.stream
          .gate(salePendingState.map((pending) => !pending))
          .orElse(_clearSaleStreamSink.stream.gate(disposePendingState));

      final completer = Completer<void>();
      stopStream.listenOnce((_) => completer.complete());
      await completer.future;
    } finally {
      subscription.cancel();
    }
  }
}

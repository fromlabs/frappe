import 'package:meta/meta.dart';
import 'package:frappe/frappe.dart';
import 'package:petrol_pump/src/util.dart';

import '../model.dart';
import '../petrol_pump.dart';

class PosSimulatorImpl implements PosSimulator {
  Future<void> _stopFuture;

  final EventStream<Sale> _saleCompleteStream;

  final EventStreamSink<Unit> _clearSaleStreamSink = EventStreamSink();
  final EventStreamSink<Unit> _disposeStreamSink = EventStreamSink();

  PosSimulatorImpl({@required EventStream<Sale> saleCompleteStream})
      : _saleCompleteStream = saleCompleteStream {
    _stopFuture = _start();
  }

  @override
  EventStream<Unit> get clearSaleStream => _clearSaleStreamSink.stream;

  @override
  Future<void> dispose() async {
    _disposeStreamSink.send(unit);

    await _stopFuture;

    await _clearSaleStreamSink.close();
    await _disposeStreamSink.close();
  }

  Future<void> _start() async {
    ListenSubscription subscription;

    try {
      subscription = _saleCompleteStream.listen((sale) async {
        await Future.delayed(const Duration(seconds: 2));

        _clearSaleStreamSink.send(unit);
      });

      final ValueState<bool> salePendingState = _saleCompleteStream
          .mapTo(true)
          .orElse(_clearSaleStreamSink.stream.mapTo(false))
          .toState(false);

      final disposePendingState =
          _disposeStreamSink.stream.mapTo(true).toState(false);

      final stopStream = _disposeStreamSink.stream
          .gate(salePendingState.map((pending) => !pending))
          .orElse(_clearSaleStreamSink.stream.gate(disposePendingState));

      await toLegacyStream(stopStream).first;
    } finally {
      await subscription.cancel();
    }
  }
}

import 'dart:async';

import 'package:frappe/frappe.dart';

/// Convenience extensions on [EventStream].
extension PetrolPumpEventStreamExtension<E> on EventStream<E> {
  /// Converts this event stream into a legacy Dart [Stream].
  Stream<E> toLegacyStream() {
    late StreamController<E> controller;
    late ListenSubscription subscription;

    controller = StreamController<E>.broadcast(onListen: () {
      subscription = listen(controller.add);
    }, onCancel: () async {
      subscription.cancel();
      await controller.close();
    });

    return controller.stream;
  }

  /// Returns a [Future] that completes with the first event.
  Future<E> first() async {
    final completer = Completer<E>();
    listenOnce((e) {
      completer.complete(e);
    });
    return completer.future;
  }
}

/// Convenience extensions on [FrappeReference] iterables.
extension FrappeReferenceIterable<FR extends FrappeReference> on Iterable<FR> {
  /// Disposes all references in this iterable.
  void dispose() => forEach((reference) => reference.dispose());
}

/// A periodic timer that emits [Unit] events at a fixed interval.
class PeriodicTimer {
  /// The interval between ticks.
  final Duration period;

  final EventStreamSink<Unit> _timerStreamSink = EventStreamSink();
  StreamSubscription<dynamic>? _timerSubscription;

  /// Creates a periodic timer that starts ticking immediately at [period].
  PeriodicTimer(this.period) {
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

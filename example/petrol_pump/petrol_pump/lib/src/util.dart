import 'dart:async';

import 'package:frappe/frappe.dart';

extension FrappeReferenceIterable<FR extends FrappeReference> on Iterable<FR> {
  void dispose() => forEach((reference) => reference.dispose());
}

extension ExtendedEventStream<E> on EventStream<E> {
  Stream<E> toLegacyStream() {
    if (!isInTransaction) {
      throw StateError('Required explicit transaction');
    }

    StreamController<E> controller;
    ListenSubscription subscription;

    controller = StreamController<E>.broadcast(onListen: () {
      subscription = listen(controller.add);
    }, onCancel: () async {
      subscription.cancel();

      await controller.close();
    });

    return controller.stream;
  }

  Future<E> first() async {
    final completer = Completer<E>();
    listenOnce((e) {
      completer.complete(e);
    });
    return completer.future;
  }
}

class PeriodicTimer {
  final Duration period;

  final EventStreamSink<Unit> _timerStreamSink = EventStreamSink();

  StreamSubscription _timerSubscription;

  PeriodicTimer(this.period) {
    _timerSubscription =
        Stream.periodic(period).listen((_) => _timerStreamSink.send(unit));
  }

  EventStream<Unit> get stream => _timerStreamSink.stream;

  Future<void> dispose() async {
    await _timerSubscription.cancel();
    await _timerStreamSink.close();
  }
}

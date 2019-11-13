import 'dart:async';

import 'package:frappe/frappe.dart';

extension ExtendedEventStream<E> on EventStream<E> {
  Stream<E> toLegacyStream() {
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
}

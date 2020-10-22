import 'dart:async';

import 'package:frappe/src/disposable.dart';

class StreamSubscriptionDisposable implements Disposable {
  final StreamSubscription _streamSubscription;

  StreamSubscriptionDisposable(this._streamSubscription);

  @override
  Future<void> dispose() => _streamSubscription.cancel();
}

class StreamControllerDisposable implements Disposable {
  final StreamController _streamController;

  StreamControllerDisposable(this._streamController);

  @override
  Future<void> dispose() => _streamController.close();
}

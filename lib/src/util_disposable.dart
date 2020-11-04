import 'dart:async';

import 'package:frappe/src/disposable.dart';

extension StreamSubscriptionDisposeSupport on StreamSubscription {
  StreamSubscriptionDisposable toDisposable() =>
      StreamSubscriptionDisposable(this);
}

extension StreamControllerDisposeSupport on StreamController {
  StreamControllerDisposable toDisposable() => StreamControllerDisposable(this);
}

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

import 'dart:async';

import 'disposable.dart';
import 'listen_subscription.dart';

/// Collects [Disposable] objects for batch disposal.
class DisposableCollector implements Disposable {
  final List<Disposable> _disposables = [];

  /// Adds a disposable and returns it.
  T add<T extends Disposable>(T disposable) {
    _disposables.add(disposable);
    return disposable;
  }

  @override
  Future<void> dispose() async {
    for (final disposable in _disposables) {
      await disposable.dispose();
    }
    _disposables.clear();
  }
}

/// Extension to convert a [StreamSubscription] to a [Disposable].
extension StreamSubscriptionDisposableExtension<T> on StreamSubscription<T> {
  Disposable toDisposable() => _StreamSubscriptionDisposable(this);
}

/// Extension to convert a [StreamController] to a [Disposable].
extension StreamControllerDisposableExtension<T> on StreamController<T> {
  Disposable toDisposable() => _StreamControllerDisposable(this);
}

/// Extension to convert a [ListenSubscription] to a [Disposable].
extension ListenSubscriptionDisposableExtension on ListenSubscription {
  Disposable toDisposable() => _ListenSubscriptionDisposable(this);
}

class _StreamSubscriptionDisposable implements Disposable {
  final StreamSubscription _subscription;
  _StreamSubscriptionDisposable(this._subscription);

  @override
  Future<void> dispose() => _subscription.cancel();
}

class _StreamControllerDisposable implements Disposable {
  final StreamController _controller;
  _StreamControllerDisposable(this._controller);

  @override
  Future<void> dispose() => _controller.close();
}

class _ListenSubscriptionDisposable implements Disposable {
  final ListenSubscription _subscription;
  _ListenSubscriptionDisposable(this._subscription);

  @override
  void dispose() => _subscription.cancel();
}

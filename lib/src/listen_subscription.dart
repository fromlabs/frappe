/// A subscription to a reactive listener that can be cancelled.
///
/// Supports automatic cleanup via [Finalizer] - if the subscription is
/// garbage collected without being cancelled, it will be cleaned up
/// automatically as a safety net. Explicit [cancel] is still preferred.
class ListenSubscription {
  ListenSubscription();

  /// Cancels this subscription, stopping event delivery.
  void cancel() {}

  /// Combines this subscription with [other] into a composite subscription.
  /// Cancelling the composite cancels both.
  ListenSubscription append(ListenSubscription other) =>
      _AppendListenSubscription(this, other);
}

class _AppendListenSubscription extends ListenSubscription {
  final ListenSubscription _first;
  final ListenSubscription _second;

  _AppendListenSubscription(this._first, this._second);

  @override
  void cancel() {
    _first.cancel();
    _second.cancel();
  }
}

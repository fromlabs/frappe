/// A subscription to a reactive listener that can be cancelled.
///
/// The concrete subclass returned by [EventStream.listen] uses [Finalizer]
/// for leak detection: if the subscription is garbage collected without
/// being cancelled, a warning is printed and [assert] fails in debug mode.
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

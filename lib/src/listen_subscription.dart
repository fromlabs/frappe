class ListenSubscription {
  ListenSubscription();

  void cancel() {}

  ListenSubscription append(ListenSubscription listener) =>
      _AppendListenSubscription(this, listener);
}

class _AppendListenSubscription extends ListenSubscription {
  final ListenSubscription _subscription1;

  final ListenSubscription _subscription2;

  _AppendListenSubscription(this._subscription1, this._subscription2);

  @override
  void cancel() {
    _subscription2.cancel();

    _subscription1.cancel();
  }
}

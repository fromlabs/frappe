import 'dart:async';

import 'internal_util.dart';

class ListenSubscription {
  final _StreamSubscriptionCanceler _canceler;

  ListenSubscription(StreamSubscription streamSubscription)
      : this._(_StreamSubscriptionCanceler(streamSubscription));

  ListenSubscription._(this._canceler);

  Future<void> cancel() => _canceler.cancel();

  ListenSubscription append(ListenSubscription listener) =>
      ListenSubscription._(_canceler.appendCanceler(listener._canceler));
}

class _StreamSubscriptionCanceler {
  final List<StreamSubscription> _streamSubscriptions;

  _StreamSubscriptionCanceler(StreamSubscription streamSubscription)
      : this._([streamSubscription]);

  _StreamSubscriptionCanceler._(
      Iterable<StreamSubscription> streamSubscriptions)
      : _streamSubscriptions = toUnmodifiableList(streamSubscriptions);

  _StreamSubscriptionCanceler appendSubscription(
          StreamSubscription subscription) =>
      _StreamSubscriptionCanceler._([
        ..._streamSubscriptions,
        subscription,
      ]);

  _StreamSubscriptionCanceler appendCanceler(
          _StreamSubscriptionCanceler canceler) =>
      _StreamSubscriptionCanceler._([
        ..._streamSubscriptions,
        ...canceler._streamSubscriptions,
      ]);

  Future<void> cancel() => Future.wait(
      _streamSubscriptions.map((subscrition) => subscrition.cancel()));
}

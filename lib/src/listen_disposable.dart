import 'package:frappe/src/disposable.dart';
import 'package:frappe/src/listen_subscription.dart';

extension ListenSubscriptionDisposeSupport on ListenSubscription {
  ListenCancelerDisposable toDisposable() => ListenCancelerDisposable(this);
}

class ListenCancelerDisposable implements Disposable {
  final ListenSubscription _listenCanceler;

  ListenCancelerDisposable(this._listenCanceler);

  @override
  void dispose() => _listenCanceler.cancel();
}

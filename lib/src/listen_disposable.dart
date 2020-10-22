import 'package:frappe/src/disposable.dart';
import 'package:frappe/src/listen_subscription.dart';

class ListenCancelerDisposable implements Disposable {
  final ListenSubscription _listenCanceler;

  ListenCancelerDisposable(this._listenCanceler);

  @override
  void dispose() => _listenCanceler.cancel();
}

import 'dart:async';

import 'package:frappe/src/disposable.dart';

class DisposableCollector implements Disposable {
  final _disposables = <Disposable>[];

  T add<T extends Disposable>(T disposable) {
    _disposables.add(disposable);

    return disposable;
  }

  @override
  Future<void> dispose() => Future.wait(_disposables.reversed
      .map<FutureOr>((disposable) => disposable.dispose())
      .whereType<Future>());
}

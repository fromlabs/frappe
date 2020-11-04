import 'dart:async';

import 'package:frappe/src/disposable.dart';
import 'package:frappe/src/event_stream.dart';
import 'package:frappe/src/value_state.dart';

extension EventStreamSinkDisposeSupport on EventStreamSink {
  EventStreamSinkDisposable toDisposable() => EventStreamSinkDisposable(this);
}

extension ValueStateSinkDisposeSupport on ValueStateSink {
  ValueStateSinkDisposable toDisposable() => ValueStateSinkDisposable(this);
}

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

class EventStreamSinkDisposable implements Disposable {
  final EventStreamSink _eventStreamSink;

  EventStreamSinkDisposable(this._eventStreamSink);

  @override
  void dispose() => _eventStreamSink.close();
}

class ValueStateSinkDisposable implements Disposable {
  final ValueStateSink _valueStateSink;

  ValueStateSinkDisposable(this._valueStateSink);

  @override
  void dispose() => _valueStateSink.close();
}

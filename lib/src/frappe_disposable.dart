import 'dart:async';

import 'package:frappe/src/disposable.dart';
import 'package:frappe/src/event_stream.dart';
import 'package:frappe/src/value_state.dart';

class DisposableCollector implements Disposable {
  final _disposables = <Disposable>[];

  @override
  Future<void> dispose() => Future.wait(_disposables
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

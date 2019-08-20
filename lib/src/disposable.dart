import 'dart:async';

import 'value_state_sink.dart';
import 'event_stream_sink.dart';
import 'listen_subscription.dart';

abstract class Disposable {
  FutureOr<void> dispose();
}

class EventStreamSinkDisposable implements Disposable {
  final EventStreamSink _eventStreamSink;

  EventStreamSinkDisposable(this._eventStreamSink);

  @override
  FutureOr<void> dispose() => _eventStreamSink?.close();
}

class ValueStateSinkDisposable implements Disposable {
  final ValueStateSink _valueStateSink;

  ValueStateSinkDisposable(this._valueStateSink);

  @override
  FutureOr<void> dispose() => _valueStateSink?.close();
}

class StreamSubscriptionDisposable implements Disposable {
  final StreamSubscription _streamSubscription;

  StreamSubscriptionDisposable(this._streamSubscription);

  @override
  FutureOr<void> dispose() => _streamSubscription?.cancel();
}

class StreamControllerDisposable implements Disposable {
  final StreamController _streamController;

  StreamControllerDisposable(this._streamController);

  @override
  FutureOr<void> dispose() => _streamController?.close();
}

class ListenCancelerDisposable implements Disposable {
  final ListenSubscription _listenCanceler;

  ListenCancelerDisposable(this._listenCanceler);

  @override
  FutureOr<void> dispose() => _listenCanceler?.cancel();
}

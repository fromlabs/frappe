import 'dart:async';

import 'package:optional/optional.dart';

import 'broadcast_stream.dart';
import 'event_stream.dart';

class EventStreamSink<E> {
  final EventStream<E> stream;

  EventStreamSink()
      : this._(createEventStreamFromBroadcastStream<E>(
            SinkBroadcastStream<E>(keepLastData: false)));

  EventStreamSink._(this.stream);

  bool get isClosed => _controllerStream.isClosed;

  Future<void> close() => _controllerStream.close();

  void send(E event) => _controllerStream.send(event);

  void sendError(error, [StackTrace stackTrace]) =>
      _controllerStream.sendError(error, stackTrace);

  SinkBroadcastStream<E> get _controllerStream => stream.legacyStream;
}

class OptionalEventStreamSink<E> extends EventStreamSink<Optional<E>> {
  OptionalEventStreamSink()
      : super._(createOptionalEventStreamFromBroadcastStream<E>(
            SinkBroadcastStream<Optional<E>>(keepLastData: false)));

  @override
  OptionalEventStream<E> get stream => super.stream;

  void sendOptionalEmpty() => send(Optional<E>.empty());

  void sendOptionalOf(E event) => send(Optional<E>.of(event));
}

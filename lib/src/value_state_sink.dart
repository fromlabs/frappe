import 'dart:async';

import 'package:optional/optional.dart';

import 'value_state.dart';
import 'broadcast_stream.dart';

class ValueStateSink<V> {
  final ValueState<V> state;

  ValueStateSink(V initValue)
      : this._(createValueStateFromBroadcastStream<V>(
            SinkBroadcastStream<V>(keepLastData: true, initData: initValue)));

  ValueStateSink._(this.state);

  bool get isClosed => _controllerStream.isClosed;

  Future<void> close() => _controllerStream.close();

  void send(V value) => _controllerStream.send(value);

  void sendError(error, [StackTrace stackTrace]) =>
      _controllerStream.sendError(error, stackTrace);

  SinkBroadcastStream<V> get _controllerStream => state.legacyStream;
}

class OptionalValueStateSink<V> extends ValueStateSink<Optional<V>> {
  OptionalValueStateSink(Optional<V> initValue)
      : super._(createOptionalValueStateFromBroadcastStream<V>(
            SinkBroadcastStream<Optional<V>>(
                keepLastData: true, initData: initValue)));

  OptionalValueStateSink.empty() : this(Optional.empty());

  OptionalValueStateSink.of(V initValue) : this(Optional.of(initValue));

  @override
  OptionalValueState<V> get state => super.state;

  void sendOptionalEmpty() => send(Optional<V>.empty());

  void sendOptionalOf(V value) => send(Optional<V>.of(value));
}

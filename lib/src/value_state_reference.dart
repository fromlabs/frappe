import 'package:optional/optional.dart';

import 'broadcast_stream.dart';
import 'value_state.dart';

class ValueStateReference<V> {
  final ValueState<V> state;

  ValueStateReference(V initValue)
      : this._(createValueStateFromBroadcastStream<V>(
            ReferenceBroadcastStream<V>(
                keepLastData: true, initData: initValue)));

  ValueStateReference._(this.state);

  bool get isLinked => _referenceStream.isLinked;

  void link(ValueState<V> state) => _referenceStream.link(state.legacyStream);

  ReferenceBroadcastStream<V> get _referenceStream => state.legacyStream;
}

class OptionalValueStateReference<V> extends ValueStateReference<Optional<V>> {
  OptionalValueStateReference(Optional<V> initValue)
      : super._(createOptionalValueStateFromBroadcastStream<V>(
            ReferenceBroadcastStream<Optional<V>>(
                keepLastData: true, initData: initValue)));

  OptionalValueStateReference.empty() : this(Optional.empty());

  OptionalValueStateReference.of(V initValue) : this(Optional.of(initValue));

  @override
  OptionalValueState<V> get state => super.state;

  @override
  void link(covariant OptionalValueState<V> state) => super.link(state);
}

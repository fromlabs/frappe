import 'package:optional/optional.dart';

import 'value_state.dart';

class ValueStateReference<V> {
  ValueStateReference() {
    // TODO implementare
    throw UnimplementedError();
  }

  // TODO implementare
  ValueState<V> get state => throw UnimplementedError();

  // TODO implementare
  bool get isLinked => throw UnimplementedError();

  // TODO implementare
  void link(ValueState<V> state) => throw UnimplementedError();
}

class OptionalValueStateReference<V> extends ValueStateReference<Optional<V>> {
  OptionalValueStateReference() {
    // TODO implementare
    throw UnimplementedError();
  }

  @override
  OptionalValueState<V> get state => super.state;

  @override
  void link(covariant OptionalValueState<V> state) => super.link(state);
}

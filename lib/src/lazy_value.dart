import 'typedefs.dart';

/// A lazily-evaluated value that caches its result after first access.
sealed class LazyValue<V> {
  const LazyValue._();

  /// Creates a [LazyValue] that already has a value.
  factory LazyValue.value(V value) = _EagerLazyValue<V>;

  /// Creates a [LazyValue] that computes its value on first access.
  factory LazyValue.provide(ValueProvider<V> provider) =
      _DeferredLazyValue<V>;

  /// Combines multiple [LazyValue]s using a combiner function.
  static LazyValue<VR> combines<VR>(
      Iterable<LazyValue> lazyValues, Combiners<VR> combiner) {
    return LazyValue.provide(
        () => combiner(lazyValues.map((lazy) => lazy.get())));
  }

  /// Whether this lazy value has been evaluated.
  bool get hasValue;

  /// Gets the value, computing it if necessary.
  V get();

  /// Maps the value through a transformation function.
  LazyValue<VR> map<VR>(Mapper<V, VR> mapper);
}

final class _EagerLazyValue<V> extends LazyValue<V> {
  final V _value;

  _EagerLazyValue(this._value) : super._();

  @override
  bool get hasValue => true;

  @override
  V get() => _value;

  @override
  LazyValue<VR> map<VR>(Mapper<V, VR> mapper) =>
      LazyValue.value(mapper(_value));
}

final class _DeferredLazyValue<V> extends LazyValue<V> {
  final ValueProvider<V> _provider;
  bool _evaluated = false;
  late V _value;

  _DeferredLazyValue(this._provider) : super._();

  @override
  bool get hasValue => _evaluated;

  @override
  V get() {
    if (!_evaluated) {
      _value = _provider();
      _evaluated = true;
    }
    return _value;
  }

  @override
  LazyValue<VR> map<VR>(Mapper<V, VR> mapper) =>
      LazyValue.provide(() => mapper(get()));
}

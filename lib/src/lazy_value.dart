import 'package:frappe/src/node.dart';
import 'package:frappe/src/typedef.dart';

abstract class LazyValue<V> {
  static LazyValue<VR> combines<VR>(
          Iterable<LazyValue> lazyValues, Combiners<VR> combiner) =>
      _ProvideLazyValue(
          () => combiner(lazyValues.map((lazyValue) => lazyValue.get())));

  factory LazyValue.value(V value) => _LazyValue(value);

  factory LazyValue.provide(ValueProvider<V> provider) =>
      _ProvideLazyValue(provider);

  bool get hasValue;

  V get();

  LazyValue<VR> map<VR>(Mapper<V, VR> mapper);
}

class _LazyValue<V> implements LazyValue<V> {
  @override
  final bool hasValue = true;
  final V _value;

  _LazyValue(V value) : _value = value;

  @override
  V get() => _value;

  @override
  LazyValue<VR> map<VR>(Mapper<V, VR> mapper) => _LazyValue(mapper(get()));
}

class _ProvideLazyValue<V> implements LazyValue<V> {
  final ValueProvider<V> _provider;
  @override
  bool hasValue = false;
  late final V _value;

  _ProvideLazyValue(this._provider);

  @override
  V get() => Transaction.runRequired((_) {
        if (!hasValue) {
          _value = _provider();
          hasValue = true;
        }

        return _value;
      });

  @override
  LazyValue<VR> map<VR>(Mapper<V, VR> mapper) =>
      Transaction.runRequired((_) => _ProvideLazyValue(() => mapper(get())));
}

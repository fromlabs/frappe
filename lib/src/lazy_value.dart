import 'package:frappe/src/node.dart';
import 'package:frappe/src/typedef.dart';

// FIXME roby: rivedere con 3 classi ad hoc
class LazyValue<V> {
  final ValueProvider<V>? _provider;
  bool hasValue = false;
  V? _value;

  LazyValue(V value)
      : _provider = null,
        hasValue = true,
        _value = value;

  LazyValue.undefined()
      : _provider = (() => throw StateError('Lazy value undefined'));

  LazyValue.provide(this._provider);

  static LazyValue<VR> combines<VR>(
          Iterable<LazyValue> lazyValues, Combiners<VR> combiner) =>
      LazyValue.provide(
          () => combiner(lazyValues.map((lazyValue) => lazyValue.get())));

  V get() => Transaction.runRequired((_) {
        if (hasValue) {
          return _value as V;
        } else {
          _value = _provider!.call();
          hasValue = true;
          return _value as V;
        }
      });

  LazyValue<VR> map<VR>(Mapper<V, VR> mapper) =>
      Transaction.runRequired((_) => LazyValue.provide(() => mapper(get())));
/*
  LazyValue<Optional<VV>> _castOptional<VV>() =>
      this as LazyValue<Optional<VV>>;
*/
}

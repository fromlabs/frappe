import 'tuple.dart';

/// A zero-argument function returning [T].
typedef Runner<T> = T Function();

/// Folds an event [V] with accumulated state [S] into a new state.
typedef Accumulator<V, S> = S Function(V value, S state);

/// Transforms an event [E] with state [S] into a new event [ER] and updated state.
typedef Collector<E, S, ER> = Tuple2<ER, S> Function(E data, S state);

/// Transforms a value of type [F] into type [T].
typedef Mapper<F, T> = T Function(F from);

/// Resolves two simultaneous values of type [E] into one.
typedef Merger<E> = E Function(E left, E right);

/// Combines an iterable of values into a single result [VR].
typedef Combiners<VR> = VR Function(Iterable values);

/// Combines two values into a single result.
typedef Combiner2<V1, V2, VR> = VR Function(V1 value1, V2 value2);

/// Combines three values into a single result.
typedef Combiner3<V1, V2, V3, VR> = VR Function(
    V1 value1, V2 value2, V3 value3);

/// Combines four values into a single result.
typedef Combiner4<V1, V2, V3, V4, VR> = VR Function(
    V1 value1, V2 value2, V3 value3, V4 value4);

/// Combines five values into a single result.
typedef Combiner5<V1, V2, V3, V4, V5, VR> = VR Function(
    V1 value1, V2 value2, V3 value3, V4 value4, V5 value5);

/// Tests whether a value satisfies a condition.
typedef Filter<V> = bool Function(V value);

/// Lazily provides a value of type [V].
typedef ValueProvider<V> = V Function();

/// Tests two values for equality.
typedef Equalizer<V> = bool Function(V value1, V value2);

/// A zero-argument void callback.
typedef Handler = void Function();

/// A callback that receives a value of type [V].
typedef ValueHandler<V> = void Function(V value);

/// Handles errors that occur at the boundary of the reactive graph
/// (publish and closing phases of a transaction).
typedef ErrorHandler = void Function(Object error, StackTrace stackTrace);

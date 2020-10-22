import 'package:frappe/src/tuple.dart';

typedef Runner<T> = T Function();
typedef Accumulator<V, S> = S Function(V value, S state);
typedef Collector<E, S, ER> = Tuple2<ER, S> Function(E data, S state);
typedef Mapper<F, T> = T Function(F from);
typedef Merger<E> = E Function(E left, E right);
typedef Combiners<VR> = VR Function(Iterable values);
typedef Combiner2<V1, V2, VR> = VR Function(V1 value1, V2 value2);
typedef Combiner3<V1, V2, V3, VR> = VR Function(
    V1 value1, V2 value2, V3 value3);
typedef Combiner4<V1, V2, V3, V4, VR> = VR Function(
    V1 value1, V2 value2, V3 value3, V4 value4);
typedef Combiner5<V1, V2, V3, V4, V5, VR> = VR Function(
    V1 value1, V2 value2, V3 value3, V4 value4, V5 value5);
typedef Filter<V> = bool Function(V value);
typedef ValueProvider<V> = V Function();
typedef Equalizer<V> = bool Function(V value1, V value2);

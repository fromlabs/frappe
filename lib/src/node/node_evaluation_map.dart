import 'package:frappe/src/node/node_evaluation.dart';
import 'package:frappe/src/node/node_evaluation_collection.dart';

class NodeEvaluationMap extends NodeEvaluationCollection {
  final Map<dynamic, NodeEvaluation> evaluations;

  NodeEvaluationMap(
      Iterable<MapEntry<dynamic, NodeEvaluation>> evaluationEntries)
      : evaluations = Map.fromEntries(evaluationEntries),
        super(evaluationEntries
            .map((entry) => entry.value)
            .every((evaluation) => evaluation.isEvaluated));

  // NodeEvaluation get evaluation => get(defaultEvaluationKey);

  // NodeEvaluation operator [](key) => get(key);

  NodeEvaluation<V> get<V>([key = defaultEvaluationKey]) =>
      (evaluations[key] ?? NodeEvaluation<V>.not()) as NodeEvaluation<V>;
}

import 'package:frappe/src/node/node_evaluation.dart';
import 'package:frappe/src/node/node_evaluation_collection.dart';

class NodeEvaluationMap extends NodeEvaluationCollection {
  final Map<dynamic, NodeEvaluation?> _evaluations;

  NodeEvaluationMap(
      Iterable<MapEntry<dynamic, NodeEvaluation?>> evaluationEntries)
      : _evaluations = Map.fromEntries(evaluationEntries),
        super(evaluationEntries
            .map((entry) => entry.value)
            .every((evaluation) => evaluation?.isEvaluated ?? false));

  NodeEvaluation<V> get<V>([key = defaultEvaluationKey]) =>
      (_evaluations[key] ?? NodeEvaluation<V>.not()) as NodeEvaluation<V>;
}

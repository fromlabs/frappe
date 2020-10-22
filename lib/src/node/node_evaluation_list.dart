import 'package:frappe/src/node/node_evaluation.dart';
import 'package:frappe/src/node/node_evaluation_collection.dart';

class NodeEvaluationList extends NodeEvaluationCollection {
  final List<NodeEvaluation> evaluations;

  NodeEvaluationList(
      Iterable<MapEntry<dynamic, NodeEvaluation>> evaluationEntries)
      : evaluations = evaluationEntries.map((entry) => entry.value).toList(),
        super(evaluationEntries
            .map((entry) => entry.value)
            .every((evaluation) => evaluation.isEvaluated));
}

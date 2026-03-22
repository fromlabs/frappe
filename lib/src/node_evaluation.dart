const String defaultEvaluationKey = 'default';

/// Result of evaluating a [Node]. Either contains a value or indicates
/// the node was not evaluated in this transaction.
sealed class NodeEvaluation<S> {
  const NodeEvaluation._();

  /// Creates an evaluation result containing [value].
  factory NodeEvaluation(S value) = Evaluated<S>;

  /// Creates a result indicating the node was not evaluated.
  factory NodeEvaluation.not() => NotEvaluated<S>();

  bool get isEvaluated;
  bool get isNotEvaluated => !isEvaluated;

  /// The evaluated value. Throws [StateError] if not evaluated.
  S get value;
}

/// A node evaluation that contains a value.
final class Evaluated<S> extends NodeEvaluation<S> {
  @override
  final S value;

  const Evaluated(this.value) : super._();

  @override
  bool get isEvaluated => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Evaluated<S> && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Evaluated($value)';
}

/// A node evaluation indicating no value was produced.
final class NotEvaluated<S> extends NodeEvaluation<S> {
  const NotEvaluated() : super._();

  @override
  bool get isEvaluated => false;

  @override
  S get value => throw StateError('Node was not evaluated');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NotEvaluated;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'NotEvaluated';
}

/// Collection of input evaluations for a node.
abstract class NodeEvaluationCollection {
  final bool allInputsEvaluated;

  NodeEvaluationCollection(this.allInputsEvaluated);
}

/// Input evaluations accessed by key.
class NodeEvaluationMap extends NodeEvaluationCollection {
  final Map<dynamic, NodeEvaluation?> _evaluations;

  NodeEvaluationMap(
      Iterable<MapEntry<dynamic, NodeEvaluation?>> evaluationEntries)
      : _evaluations = Map.fromEntries(evaluationEntries),
        super(evaluationEntries.every(
            (entry) => entry.value != null && entry.value!.isEvaluated));

  NodeEvaluation<V> get<V>([dynamic key = defaultEvaluationKey]) {
    final evaluation = _evaluations[key];
    if (evaluation == null) return NodeEvaluation<V>.not();
    return evaluation as NodeEvaluation<V>;
  }
}

/// Input evaluations accessed by index.
class NodeEvaluationList extends NodeEvaluationCollection {
  final List<NodeEvaluation?> evaluations;

  NodeEvaluationList(
      Iterable<MapEntry<dynamic, NodeEvaluation?>> evaluationEntries)
      : evaluations = evaluationEntries.map((e) => e.value).toList(),
        super(evaluationEntries.every(
            (entry) => entry.value != null && entry.value!.isEvaluated));
}

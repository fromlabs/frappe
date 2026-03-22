/// The key used by [KeyNode] when no explicit key is provided.
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

/// A [NodeEvaluation] that holds a successfully produced value.
final class Evaluated<S> extends NodeEvaluation<S> {
  @override
  final S value;

  /// Creates an evaluation carrying [value].
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

/// A [NodeEvaluation] indicating the node did not produce a value
/// in this transaction.
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

/// Base class for the collection of input evaluations passed to a node's
/// evaluator function during a transaction.
///
/// Subclasses provide either key-based ([NodeEvaluationMap]) or index-based
/// ([NodeEvaluationList]) access to the upstream evaluation results.
abstract class NodeEvaluationCollection {
  /// Whether every input produced an [Evaluated] value in this transaction.
  final bool allInputsEvaluated;

  NodeEvaluationCollection(this.allInputsEvaluated);
}

/// Input evaluations accessed by named key, used by [KeyNode].
class NodeEvaluationMap extends NodeEvaluationCollection {
  final Map<dynamic, NodeEvaluation?> _evaluations;

  NodeEvaluationMap(
      Iterable<MapEntry<dynamic, NodeEvaluation?>> evaluationEntries)
      : _evaluations = Map.fromEntries(evaluationEntries),
        // An input counts as evaluated only when its entry is non-null (the
        // source participated in this transaction) AND it produced a value.
        super(evaluationEntries
            .every((entry) => entry.value != null && entry.value!.isEvaluated));

  /// Returns the evaluation for [key], or [NotEvaluated] if absent.
  NodeEvaluation<V> get<V>([dynamic key = defaultEvaluationKey]) {
    final evaluation = _evaluations[key];
    if (evaluation == null) return NodeEvaluation<V>.not();
    return evaluation as NodeEvaluation<V>;
  }
}

/// Input evaluations accessed by positional index, used by [IndexNode].
class NodeEvaluationList extends NodeEvaluationCollection {
  /// The ordered list of input evaluations, one per linked source.
  final List<NodeEvaluation?> evaluations;

  NodeEvaluationList(
      Iterable<MapEntry<dynamic, NodeEvaluation?>> evaluationEntries)
      : evaluations = evaluationEntries.map((e) => e.value).toList(),
        // Same two-part check as NodeEvaluationMap: the source must have
        // participated (non-null) and produced a concrete value.
        super(evaluationEntries
            .every((entry) => entry.value != null && entry.value!.isEvaluated));
}

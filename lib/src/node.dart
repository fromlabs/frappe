import 'node_evaluation.dart';
import 'reactive_scope.dart';
import 'reference.dart';
import 'transaction.dart';
import 'typedefs.dart';

typedef KeyNodeEvaluator<V> = NodeEvaluation<V> Function(
    NodeEvaluationMap inputs);
typedef IndexNodeEvaluator<V> = NodeEvaluation<V> Function(
    NodeEvaluationList inputs);

/// How a node decides when to evaluate.
enum EvaluationType {
  /// Evaluate every transaction regardless of input changes.
  always,

  /// Evaluate only when all inputs have values.
  allInputs,

  /// Evaluate when at least one input has a value.
  almostOneInput,

  /// Never evaluate (used for source/sink nodes).
  never,
}

/// A node in the reactive computation graph.
///
/// Nodes form a directed acyclic graph (DAG) where source nodes feed
/// values to target nodes. During a transaction, nodes are evaluated
/// in topological order based on their [evaluationPriority].
abstract class Node<S> extends Referenceable {
  final int id;
  final String debugLabel;
  final ReactiveScope _scope;

  final Map<dynamic, HostedReference<Node>> sourceReferences = Map.identity();
  final Map<Node, Set> targetNodes = Map.identity();

  EvaluationType _evaluationType;
  late int _evaluationPriority;

  late ValueHandler<S> commitHandler;
  late ValueHandler<S> publishHandler;
  late Handler unreferencedHandler;

  Node({
    String? debugLabel,
    required EvaluationType evaluationType,
    ValueHandler<S>? commitHandler,
    ValueHandler<S>? publishHandler,
    Handler? unreferencedHandler,
  })  : _scope = ReactiveScope.current,
        id = ReactiveScope.current.nodeIdCounter++,
        debugLabel =
            '${debugLabel ?? 'node'}:${ReactiveScope.current.nodeIdCounter}',
        _evaluationType = evaluationType {
    this.commitHandler = commitHandler ?? (S value) {};
    this.publishHandler = publishHandler ?? (S value) {};
    this.unreferencedHandler = unreferencedHandler ?? (() {});
    _evaluationPriority = 1;

    Transaction.onNodeAdded(this);
  }

  EvaluationType get evaluationType => _evaluationType;

  set evaluationType(EvaluationType evaluationType) {
    if (evaluationType != _evaluationType) {
      final old = _evaluationType;
      _evaluationType = evaluationType;
      Transaction.onEvaluationTypeUpdated(this, evaluationType, old);
    }
  }

  int get evaluationPriority => _evaluationPriority;

  bool get isLinked => sourceReferences.isNotEmpty;

  NodeEvaluationCollection createEvaluationInputs(
      Iterable<MapEntry<dynamic, NodeEvaluation?>> inputEntries);

  @override
  void onUnreferenced() {
    unreferencedHandler();
    Transaction.onNodeRemoved(this);
    super.onUnreferenced();
  }

  NodeEvaluation<S> evaluate(covariant NodeEvaluationCollection inputs);

  void commit(S value) => commitHandler(value);
  void publish(S value) => publishHandler(value);

  @override
  String toString() =>
      '[$debugLabel:$runtimeType:$_evaluationType:$_evaluationPriority]';

  void _linkSource(dynamic key, Node source) {
    assert(key != null);
    if (!isReferenced) {
      throw ArgumentError('Unreferenced target node: $this');
    }
    if (!source.isReferenced) {
      throw ArgumentError('Unreferenced source node: $source');
    }
    source._checkCycle(this);

    final sourceReference = reference(source);
    if (sourceReferences.isEmpty) {
      _scope.targetNodes.add(this);
    }
    sourceReferences[key] = sourceReference;
    source._linkTarget(this, key);
  }

  void _unlinkSource(dynamic key) {
    final sourceReference = sourceReferences.remove(key);
    if (sourceReference != null) {
      if (sourceReferences.isEmpty) {
        _scope.targetNodes.remove(this);
      }
      sourceReference.dispose();
      sourceReference.value._unlinkTarget(this, key);
    }
  }

  void _linkTarget(Node target, key) {
    if (targetNodes.isEmpty) {
      _scope.sourceNodes.add(this);
    }
    targetNodes.putIfAbsent(target, () => Set.identity()).add(key);
    _propagatePriority(target._evaluationPriority);
  }

  void _unlinkTarget(Node target, key) {
    final keys = targetNodes[target];
    if (keys != null) {
      keys.remove(key);
      if (keys.isEmpty) {
        targetNodes.remove(target);
        if (targetNodes.isEmpty) {
          _scope.sourceNodes.remove(this);
        }
      }
      _propagatePriority(-target._evaluationPriority);
    }
  }

  void _checkCycle(Node ascendant) {
    if (ascendant != this) {
      for (final sourceReference in sourceReferences.values) {
        sourceReference.value._checkCycle(ascendant);
      }
    } else {
      throw ArgumentError('Cycle detected in node link');
    }
  }

  void _propagatePriority(int evaluationPriority) {
    if (evaluationPriority > 0) {
      _evaluationPriority += evaluationPriority;
      for (final sourceReference in sourceReferences.values) {
        sourceReference.value._propagatePriority(evaluationPriority);
      }
    }
  }
}

/// A [Node] whose inputs are accessed by key.
class KeyNode<S> extends Node<S> {
  final KeyNodeEvaluator<S> _evaluateHandler;

  KeyNode({
    super.debugLabel,
    super.evaluationType = EvaluationType.allInputs,
    KeyNodeEvaluator<S>? evaluateHandler,
    super.commitHandler,
    super.publishHandler,
    super.unreferencedHandler,
  }) : _evaluateHandler = evaluateHandler ?? _missingEvaluateHandler;

  static NodeEvaluation<S> _missingEvaluateHandler<S>(
          NodeEvaluationMap inputs) =>
      throw StateError('Missing evaluate handler');

  bool isLinkedKey({dynamic key = defaultEvaluationKey}) =>
      sourceReferences.containsKey(key);

  void link(Node source, {dynamic key = defaultEvaluationKey}) =>
      _linkSource(key, source);

  void unlink({dynamic key = defaultEvaluationKey}) => _unlinkSource(key);

  @override
  void onUnreferenced() {
    for (final key in sourceReferences.keys.toList()) {
      _unlinkSource(key);
    }
    super.onUnreferenced();
  }

  @override
  NodeEvaluationMap createEvaluationInputs(
          Iterable<MapEntry<dynamic, NodeEvaluation?>> inputEntries) =>
      NodeEvaluationMap(inputEntries);

  @override
  NodeEvaluation<S> evaluate(NodeEvaluationMap inputs) =>
      _evaluateHandler(inputs);
}

/// A [Node] whose inputs are accessed by index.
class IndexNode<S> extends Node<S> {
  final IndexNodeEvaluator<S> _evaluateHandler;

  IndexNode({
    super.debugLabel,
    super.evaluationType = EvaluationType.allInputs,
    IndexNodeEvaluator<S>? evaluateHandler,
    super.commitHandler,
    super.publishHandler,
    super.unreferencedHandler,
  }) : _evaluateHandler = evaluateHandler ?? _missingEvaluateHandler;

  static NodeEvaluation<S> _missingEvaluateHandler<S>(
          NodeEvaluationList inputs) =>
      throw StateError('Missing evaluate handler');

  void link(Iterable<Node> sources) {
    var index = 0;
    for (final source in sources) {
      _linkSource(index++, source);
    }
  }

  void unlink() {
    for (final key in sourceReferences.keys.toList()) {
      _unlinkSource(key);
    }
  }

  @override
  void onUnreferenced() {
    unlink();
    super.onUnreferenced();
  }

  @override
  NodeEvaluationList createEvaluationInputs(
          Iterable<MapEntry<dynamic, NodeEvaluation?>> inputEntries) =>
      NodeEvaluationList(inputEntries);

  @override
  NodeEvaluation<S> evaluate(NodeEvaluationList inputs) =>
      _evaluateHandler(inputs);
}

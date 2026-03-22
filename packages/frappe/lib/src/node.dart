import 'node_evaluation.dart';
import 'frappe_scope.dart';
import 'reference.dart';
import 'transaction.dart';
import 'typedefs.dart';

/// Evaluator function for a [KeyNode], receiving inputs keyed by name.
typedef KeyNodeEvaluator<V> = NodeEvaluation<V> Function(
    NodeEvaluationMap inputs);

/// Evaluator function for an [IndexNode], receiving inputs keyed by index.
typedef IndexNodeEvaluator<V> = NodeEvaluation<V> Function(
    NodeEvaluationList inputs);

/// How a node decides when to evaluate.
enum EvaluationType {
  /// Evaluate every transaction regardless of input changes.
  always,

  /// Evaluate only when all inputs have values.
  allInputs,

  /// Evaluate when at least one input has a value.
  atLeastOneInput,

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
  final FrappeScope _scope;

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
  })  : _scope = FrappeScope.current,
        id = FrappeScope.current.nodeIdCounter++,
        // nodeIdCounter was post-incremented when assigning id, so
        // (nodeIdCounter - 1) equals the id value assigned above.
        debugLabel =
            '${debugLabel ?? 'node'}:${FrappeScope.current.nodeIdCounter - 1}',
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
    // No check on source.isReferenced: the HostedReference created below
    // will make the source alive through the target's ownership chain.
    // Sink nodes (EvaluationType.never) are typically unreferenced at this
    // point — they have no external FrappeReference, only the Dart object
    // (EventStreamSink/ValueStateSink) holds them. Requiring explicit
    // referencing of every sink stream was an over-constraint.
    // §8.3: nodes from different scopes must not link — isolation guarantee.
    if (source._scope != _scope) {
      throw ArgumentError(
          'Cannot link nodes from different scopes: '
          'target $this and source $source belong to different FrappeScopes');
    }
    source._checkCycle(this);

    final sourceReference = reference(source);
    // Register this node in the scope's target set on first link so the
    // transaction knows it participates in evaluation. Remove on last unlink.
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
    _deferOrRunPriorityUpdate(target._evaluationPriority);
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
      _deferOrRunPriorityUpdate(-target._evaluationPriority);
    }
  }

  // Walks up the source chain from this node to verify that [ascendant]
  // does not appear among its transitive sources. If it does, linking
  // would create a cycle in the DAG.
  void _checkCycle(Node ascendant) {
    if (ascendant != this) {
      for (final sourceReference in sourceReferences.values) {
        sourceReference.value._checkCycle(ascendant);
      }
    } else {
      throw ArgumentError('Cycle detected in node link');
    }
  }

  // During evaluation, defer priority propagation to avoid mutating
  // priorities while the pending-nodes list is being drained. Outside
  // evaluation (opened, closing, or no transaction), run immediately.
  void _deferOrRunPriorityUpdate(int delta) {
    final tx = Transaction.currentTransaction;
    if (tx != null && tx.phase == TransactionPhase.evaluation) {
      tx.deferPriorityUpdate(() => _propagatePriority(delta));
    } else {
      _propagatePriority(delta);
    }
  }

  // Priority accumulates upward toward sources so that upstream nodes are
  // always evaluated before their dependants. Only positive deltas propagate:
  // when a target unlinks, its negative delta stops at zero to avoid
  // underflowing priorities on shared upstream nodes.
  void _propagatePriority(int evaluationPriority) {
    if (evaluationPriority > 0) {
      _evaluationPriority += evaluationPriority;
      for (final sourceReference in sourceReferences.values) {
        sourceReference.value._propagatePriority(evaluationPriority);
      }
    }
  }
}

/// A [Node] whose source inputs are identified by named keys.
///
/// Most operators use [KeyNode] with [defaultEvaluationKey] for a single
/// input, or custom keys when multiple distinct inputs are needed
/// (e.g. `snapshot`).
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

  /// Whether a source is currently linked under [key].
  bool isLinkedKey({dynamic key = defaultEvaluationKey}) =>
      sourceReferences.containsKey(key);

  /// Links [source] as an input under [key], establishing a DAG edge.
  void link(Node source, {dynamic key = defaultEvaluationKey}) =>
      _linkSource(key, source);

  /// Unlinks the source currently bound to [key].
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

/// A [Node] whose source inputs are identified by integer index.
///
/// Used by the `combines` operator where multiple homogeneous inputs
/// are accessed positionally rather than by name.
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

  /// Links all [sources] as inputs, assigning each a sequential index.
  void link(Iterable<Node> sources) {
    var index = 0;
    for (final source in sources) {
      _linkSource(index++, source);
    }
  }

  /// Unlinks all currently linked source inputs.
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

import 'package:frappe/src/node.dart';

import '../reference.dart';

import 'node_evaluation_collection.dart';
import 'node_evaluation_list.dart';
import 'node_evaluation_map.dart';
import 'node_evaluation.dart';

typedef NodeHandler<V> = void Function(Node<V> node);
typedef NodeValueUpdatedHandler<V> = void Function(
    Node node, V newValue, V oldValue);
typedef ValueHandler<V> = void Function(V value);
typedef OverrideValueHandler<V> = void Function(
    ValueHandler<V> superCommit, V value);
typedef NodeEvaluator<V> = NodeEvaluation<V> Function(
    Map<dynamic, NodeEvaluation> inputs);
typedef KeyNodeEvaluator<V> = NodeEvaluation<V> Function(
    NodeEvaluationMap inputs);
typedef IndexNodeEvaluator<V> = NodeEvaluation<V> Function(
    NodeEvaluationList inputs);

enum EvaluationType { always, allInputs, almostOneInput, never }

final nodeGraph = _NodeGraph();

void cleanAllNodesUnlinked() => nodeGraph.cleanAllNodesUnlinked();

void assertAllNodesUnlinked() => nodeGraph.assertAllNodesUnlinked();

class _NodeGraph {
  final Set<Node> _globalTargetNodes = Set.identity();
  final Set<Node> _globalSourceNodes = Set.identity();

  NodeHandler onNodeAddedHandler = (_) {};
  NodeHandler onNodeRemovedHandler = (_) {};
  NodeValueUpdatedHandler<EvaluationType> onEvaluationTypeUpdatedHandler =
      (_, __, ___) {};

  void cleanAllNodesUnlinked() {
    _globalSourceNodes.clear();
    _globalTargetNodes.clear();
  }

  void assertAllNodesUnlinked() {
    if (_globalSourceNodes.isNotEmpty || _globalTargetNodes.isNotEmpty) {
      print('Source nodes: ${_globalSourceNodes}');
      print('Target nodes: ${_globalTargetNodes}');

      throw AssertionError('Not all nodes unlinked');
    }
  }

  void addTargetNode(Node node) {
    _globalTargetNodes.add(node);
  }

  void removeTargetNode(Node node) {
    _globalTargetNodes.remove(node);
  }

  void addSourceNode(Node node) {
    _globalSourceNodes.add(node);
  }

  void removeSourceNode(Node node) {
    _globalSourceNodes.remove(node);
  }

  NodeEvaluation<S> evaluate<S>(
          Node<S> node, NodeEvaluationCollection inputs) =>
      node._evaluate(inputs);

  void commit<S>(Node<S> node, S value) => node._commit(value);

  void publish<S>(Node<S> node, S value) => node._publish(value);

  void overrideCommitHandler<S>(
      Node<S> node, OverrideValueHandler<S> overrideCommitHandler) {
    final superCommitHandler = node._commitHandler;

    node._commitHandler =
        (S value) => overrideCommitHandler(superCommitHandler, value);
  }

  void onNodeAdded(Node node) => onNodeAddedHandler(node);

  void onNodeRemoved(Node node) => onNodeRemovedHandler(node);

  void onEvaluationTypeUpdated(Node node, EvaluationType newEvaluationType,
          EvaluationType oldEvaluationType) =>
      onEvaluationTypeUpdatedHandler(
          node, newEvaluationType, oldEvaluationType);
}

abstract class Node<S> extends Referenceable {
  static int _nodeId = 0;

  final String debugLabel;

  final Map<dynamic, HostedReference<Node>> sourceReferences = Map.identity();

  final Map<Node, Set> targetNodes = Map.identity();

  EvaluationType _evaluationType;

  int _evaluationPriority;

  ValueHandler<S> _commitHandler;

  ValueHandler<S> _publishHandler;

  Node({
    String debugLabel,
    EvaluationType evaluationType,
    ValueHandler<S> commitHandler,
    ValueHandler<S> publishHandler,
  })  : debugLabel = '${debugLabel ?? 'node'}:${_nodeId++}',
        _evaluationType = evaluationType {
    _commitHandler = commitHandler ?? (S value) {};
    _publishHandler = publishHandler ?? (S value) {};
    _evaluationPriority = 1;

    nodeGraph.onNodeAdded(this);
  }

  EvaluationType get evaluationType => _evaluationType;

  set evaluationType(EvaluationType evaluationType) {
    if (evaluationType != _evaluationType) {
      final oldEvaluationType = _evaluationType;

      _evaluationType = evaluationType;

      nodeGraph.onEvaluationTypeUpdated(
          this, evaluationType, oldEvaluationType);
    }
  }

  int get evaluationPriority => _evaluationPriority;

  bool get isLinked => sourceReferences.isNotEmpty;

  NodeEvaluationCollection createEvaluationInputs(
      Iterable<MapEntry<dynamic, NodeEvaluation>> inputEntries);

  @override
  void onUnreferenced() {
    nodeGraph.onNodeRemoved(this);

    super.onUnreferenced();
  }

  @override
  String toString() =>
      '[$debugLabel:$runtimeType:$_evaluationType:$_evaluationPriority]';

  void _linkSource(key, Node source) {
    assert(key != null);

    if (isUnreferenced) {
      throw ArgumentError('Unreferenced target node');
    } else if (source.isUnreferenced) {
      throw ArgumentError('Unreferenced source node');
    }

    source._checkCycle(this);
    final sourceReference = reference(source);
    if (sourceReferences.isEmpty) {
      nodeGraph.addTargetNode(this);
    }
    sourceReferences[key] = sourceReference;
    source._linkTarget(this, key);
  }

  void _unlinkSource(key) {
    final sourceReference = sourceReferences.remove(key);
    if (sourceReference != null) {
      if (sourceReferences.isEmpty) {
        nodeGraph.removeTargetNode(this);
      }
      sourceReference.dispose();
      sourceReference.value._unlinkTarget(this, key);
    }
  }

  void _linkTarget(Node target, key) {
    if (targetNodes.isEmpty) {
      nodeGraph.addSourceNode(this);
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
          nodeGraph.removeSourceNode(this);
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
      throw ArgumentError('Cycle node link');
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

  NodeEvaluation<S> _evaluate(covariant NodeEvaluationCollection inputs);

  void _commit(S value) => _commitHandler(value);

  void _publish(S value) => _publishHandler(value);
}

class IndexNode<S> extends Node<S> {
  final IndexNodeEvaluator<S> _evaluateHandler;

  IndexNode({
    String debugLabel,
    EvaluationType evaluationType = EvaluationType.allInputs,
    IndexNodeEvaluator<S> evaluateHandler,
    ValueHandler<S> commitHandler,
    ValueHandler<S> publishHandler,
  })  : _evaluateHandler = evaluateHandler,
        super(
          debugLabel: debugLabel,
          evaluationType: evaluationType,
          commitHandler: commitHandler,
          publishHandler: publishHandler,
        );

  void link(Iterable<Node> sources) {
    if (isLinked) {
      throw StateError('Sources already linked');
    }

    for (final source in sources) {
      _linkSource(sourceReferences.length, source);
    }
  }

  void unlink() {
    while (isLinked) {
      _unlinkSource(sourceReferences.keys.last);
    }
  }

  @override
  void onUnreferenced() {
    unlink();

    super.onUnreferenced();
  }

  @override
  NodeEvaluationList createEvaluationInputs(
          Iterable<MapEntry<dynamic, NodeEvaluation>> inputEntries) =>
      NodeEvaluationList(inputEntries.map((entry) => entry.value != null
          ? entry
          : MapEntry(entry.key, NodeEvaluation<S>.not())));

  @override
  NodeEvaluation<S> _evaluate(NodeEvaluationList inputs) =>
      _evaluateHandler(inputs);
}

class KeyNode<S> extends Node<S> {
  final KeyNodeEvaluator<S> _evaluateHandler;

  KeyNode({
    String debugLabel,
    EvaluationType evaluationType = EvaluationType.allInputs,
    KeyNodeEvaluator<S> evaluateHandler,
    ValueHandler<S> commitHandler,
    ValueHandler<S> publishHandler,
  })  : _evaluateHandler = evaluateHandler,
        super(
          debugLabel: debugLabel,
          evaluationType: evaluationType,
          commitHandler: commitHandler,
          publishHandler: publishHandler,
        );

  bool isLinkedKey({key}) =>
      sourceReferences.containsKey(key ?? defaultEvaluationKey);

  void link(Node source, {key}) {
    if (isLinkedKey(key: key)) {
      throw StateError('Source on $key already linked');
    }

    _linkSource(key ?? defaultEvaluationKey, source);
  }

  void unlink({key}) => _unlinkSource(key ?? defaultEvaluationKey);

  @override
  void onUnreferenced() {
    while (isLinked) {
      unlink(key: sourceReferences.keys.last);
    }

    super.onUnreferenced();
  }

  @override
  NodeEvaluationMap createEvaluationInputs(
          Iterable<MapEntry<dynamic, NodeEvaluation>> inputEntries) =>
      NodeEvaluationMap(inputEntries.map((entry) => entry.value != null
          ? entry
          : MapEntry(entry.key, NodeEvaluation<S>.not())));

  @override
  NodeEvaluation<S> _evaluate(NodeEvaluationMap inputs) =>
      _evaluateHandler(inputs);
}

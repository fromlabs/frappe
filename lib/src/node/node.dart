import 'package:frappe/src/node/node_evaluation.dart';
import 'package:frappe/src/node/node_evaluation_collection.dart';
import 'package:frappe/src/node/node_evaluation_list.dart';
import 'package:frappe/src/node/node_evaluation_map.dart';
import 'package:frappe/src/node/transaction.dart';
import 'package:frappe/src/reference.dart';

typedef Handler = void Function();
typedef ValueHandler<V> = void Function(V value);
typedef NodeEvaluator<V> = NodeEvaluation<V> Function(
    Map<dynamic, NodeEvaluation> inputs);
typedef KeyNodeEvaluator<V> = NodeEvaluation<V> Function(
    NodeEvaluationMap inputs);
typedef IndexNodeEvaluator<V> = NodeEvaluation<V> Function(
    NodeEvaluationList inputs);

enum EvaluationType { always, allInputs, almostOneInput, never }

abstract class Node<S> extends Referenceable {
  static int _nodeId = 0;
  static final Set<Node> _globalTargetNodes = Set.identity();
  static final Set<Node> _globalSourceNodes = Set.identity();

  static void cleanState() {
    _globalSourceNodes.clear();
    _globalTargetNodes.clear();
  }

  static void assertCleanState() {
    if (_globalSourceNodes.isNotEmpty || _globalTargetNodes.isNotEmpty) {
      print('Source nodes: $_globalSourceNodes');
      print('Target nodes: $_globalTargetNodes');

      throw AssertionError('Not all nodes unlinked');
    }
  }

  final int id;

  final String debugLabel;

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
  })  : id = _nodeId++,
        debugLabel = '${debugLabel ?? 'node'}:$_nodeId',
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
      final oldEvaluationType = _evaluationType;

      _evaluationType = evaluationType;

      Transaction.onEvaluationTypeUpdated(
          this, evaluationType, oldEvaluationType);
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

  void _linkSource(key, Node source) {
    assert(key != null);

    if (!isReferenced) {
      throw ArgumentError('Unreferenced target node');
    } else if (!source.isReferenced) {
      throw ArgumentError('Unreferenced source node');
    }

    source._checkCycle(this);
    final sourceReference = reference(source);
    if (sourceReferences.isEmpty) {
      _globalTargetNodes.add(this);
    }
    sourceReferences[key] = sourceReference;
    source._linkTarget(this, key);
  }

  void _unlinkSource(key) {
    final sourceReference = sourceReferences.remove(key);
    if (sourceReference != null) {
      if (sourceReferences.isEmpty) {
        _globalTargetNodes.remove(this);
      }
      sourceReference.dispose();
      sourceReference.value._unlinkTarget(this, key);
    }
  }

  void _linkTarget(Node target, key) {
    if (targetNodes.isEmpty) {
      _globalSourceNodes.add(this);
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
          _globalSourceNodes.remove(this);
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
}

class IndexNode<S> extends Node<S> {
  final IndexNodeEvaluator<S> _evaluateHandler;

  IndexNode({
    String? debugLabel,
    EvaluationType evaluationType = EvaluationType.allInputs,
    IndexNodeEvaluator<S>? evaluateHandler,
    ValueHandler<S>? commitHandler,
    ValueHandler<S>? publishHandler,
  })  : _evaluateHandler = evaluateHandler ?? _missingEvaluateHandler,
        super(
          debugLabel: debugLabel,
          evaluationType: evaluationType,
          commitHandler: commitHandler,
          publishHandler: publishHandler,
        );

  static NodeEvaluation<S> _missingEvaluateHandler<S>(
      NodeEvaluationList inputs) {
    throw UnsupportedError('Missing evaluation handler');
  }

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
    Transaction.onUnreferencedInterceptor(this, () {
      unlink();

      super.onUnreferenced();
    });
  }

  @override
  NodeEvaluationList createEvaluationInputs(
          Iterable<MapEntry<dynamic, NodeEvaluation?>> inputEntries) =>
      NodeEvaluationList(inputEntries);

  @override
  NodeEvaluation<S> evaluate(NodeEvaluationList inputs) =>
      _evaluateHandler(inputs);
}

class KeyNode<S> extends Node<S> {
  final KeyNodeEvaluator<S> _evaluateHandler;

  KeyNode({
    String? debugLabel,
    EvaluationType evaluationType = EvaluationType.allInputs,
    KeyNodeEvaluator<S>? evaluateHandler,
    ValueHandler<S>? commitHandler,
    ValueHandler<S>? publishHandler,
  })  : _evaluateHandler = evaluateHandler ?? _missingEvaluateHandler,
        super(
          debugLabel: debugLabel,
          evaluationType: evaluationType,
          commitHandler: commitHandler,
          publishHandler: publishHandler,
        );

  static NodeEvaluation<S> _missingEvaluateHandler<S>(
      NodeEvaluationMap inputs) {
    throw UnsupportedError('Missing evaluation handler');
  }

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
    Transaction.onUnreferencedInterceptor(this, () {
      while (isLinked) {
        unlink(key: sourceReferences.keys.last);
      }

      super.onUnreferenced();
    });
  }

  @override
  NodeEvaluationMap createEvaluationInputs(
          Iterable<MapEntry<dynamic, NodeEvaluation?>> inputEntries) =>
      NodeEvaluationMap(inputEntries);

  @override
  NodeEvaluation<S> evaluate(NodeEvaluationMap inputs) =>
      _evaluateHandler(inputs);
}

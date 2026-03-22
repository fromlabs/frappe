import 'dart:async';

import 'disposable.dart';
import 'node.dart';
import 'reference.dart';
import 'transaction.dart';
import 'typedefs.dart';

/// An isolated reactive scope that contains all FRP state.
///
/// Eliminates global mutable state by scoping all nodes, references, and
/// transactions to a [ReactiveScope] instance. The scope is propagated
/// via Dart [Zone]s, making it transparently available to all FRP operations.
///
/// ```dart
/// final scope = ReactiveScope();
/// scope.run(() {
///   runTransaction(() {
///     final sink = EventStreamSink<int>();
///     // ...
///   });
/// });
/// scope.dispose();
/// ```
class ReactiveScope implements Disposable {
  static final _zoneKey = Object();

  /// Gets the current [ReactiveScope] from the active zone.
  ///
  /// Throws [StateError] if no scope is active.
  static ReactiveScope get current {
    final scope = Zone.current[_zoneKey] as ReactiveScope?;
    if (scope == null) {
      throw StateError(
          'No ReactiveScope in current zone. Use scope.run(() { ... })');
    }
    return scope;
  }

  /// Returns the current [ReactiveScope] if one exists, otherwise null.
  static ReactiveScope? get currentOrNull =>
      Zone.current[_zoneKey] as ReactiveScope?;

  // --- State containers (replaces all global mutable state) ---

  /// Reference tracking: maps each referenceable to its active references.
  final Map<Referenceable, Set<Reference>> references = Map.identity();

  /// Nodes that always evaluate in every transaction.
  final Set<Node> alwaysNodes = Set.identity();

  /// Nodes with closing-phase transaction handlers (listeners).
  final Map<Node, TransactionHandler> listenNodes = Map.identity();

  /// Nodes that are currently linked as targets.
  final Set<Node> targetNodes = Set.identity();

  /// Nodes that are currently linked as sources.
  final Set<Node> sourceNodes = Set.identity();

  /// Auto-incrementing node ID counter.
  int nodeIdCounter = 0;

  bool _isDisposed = false;

  /// Whether this scope has been disposed.
  bool get isDisposed => _isDisposed;

  /// Runs [runner] within this scope's zone.
  T run<T>(T Function() runner) {
    _checkDisposed();
    return runZoned(runner, zoneValues: {_zoneKey: this});
  }

  /// Whether a transaction is currently active in this scope's zone.
  bool get isInTransaction => Transaction.currentTransaction != null;

  /// Runs [runner] within a new transaction in this scope.
  T runTransaction<T>(Runner<T> runner) {
    _checkDisposed();
    return run(() => Transaction.run((tx) => runner()));
  }

  /// Cleans all state in this scope.
  void cleanState() {
    references.clear();
    alwaysNodes.clear();
    listenNodes.clear();
    targetNodes.clear();
    sourceNodes.clear();
    nodeIdCounter = 0;
  }

  /// Asserts that all state has been properly cleaned up.
  void assertCleanState() {
    if (references.isNotEmpty) {
      print('Dangling references: $references');
      throw AssertionError('Not all values unreferenced');
    }
    if (listenNodes.isNotEmpty) {
      print('Dangling listen nodes: $listenNodes');
      throw AssertionError('Not all listen nodes removed');
    }
    if (targetNodes.isNotEmpty || sourceNodes.isNotEmpty) {
      print('Source nodes: $sourceNodes');
      print('Target nodes: $targetNodes');
      throw AssertionError('Not all nodes unlinked');
    }
  }

  @override
  void dispose() {
    _checkDisposed();
    assertCleanState();
    _isDisposed = true;
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('ReactiveScope is disposed');
    }
  }
}

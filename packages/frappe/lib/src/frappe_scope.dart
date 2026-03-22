import 'dart:async';

import 'disposable.dart';
import 'node.dart';
import 'reference.dart';
import 'transaction.dart';
import 'typedefs.dart';

/// Debug token for tracking user-facing references (FrappeReference,
/// ListenSubscription). Holds metadata for leak diagnostics without
/// retaining the actual reference object (which must remain GC-eligible).
class LeakTrackingToken {
  /// Descriptive type, e.g. `FrappeReference<EventStream<int>>`.
  final String type;

  /// The [Node.debugLabel] at creation time.
  final String nodeLabel;

  /// Stack trace captured at creation, only in assert mode (null otherwise).
  final StackTrace? creationTrace;

  LeakTrackingToken(this.type, this.nodeLabel, [this.creationTrace]);

  @override
  String toString() => '[$type] node=$nodeLabel';
}

/// An isolated reactive scope that contains all FRP state.
///
/// Eliminates global mutable state by scoping all nodes, references, and
/// transactions to a [FrappeScope] instance. The scope is propagated
/// via Dart [Zone]s, making it transparently available to all FRP operations.
///
/// A root scope is always available, so explicit scope creation is only
/// needed for isolation (e.g., testing, parallel contexts).
///
/// ```dart
/// // Simple usage — root scope is implicit:
/// runTransaction(() {
///   final sink = EventStreamSink<int>();
///   sink.send(42);
/// });
///
/// // Isolated scope for testing:
/// final scope = FrappeScope();
/// scope.run(() {
///   runTransaction(() { ... });
///   scope.assertCleanState();
/// });
/// scope.dispose();
/// ```
class FrappeScope implements Disposable {
  static final _zoneKey = Object();

  /// Root scope, always available as fallback.
  static final FrappeScope _root = FrappeScope._internal();

  /// Default error handler: delegates to the current zone's uncaught error
  /// handler. With [runZonedGuarded], errors are caught there. Without a
  /// guarded zone, the root zone schedules an async re-throw (standard Dart
  /// behavior for uncaught errors).
  static void defaultErrorHandler(Object error, StackTrace stackTrace) {
    Zone.current.handleUncaughtError(error, stackTrace);
  }

  /// Gets the root scope.
  static FrappeScope get root => _root;

  /// Gets the current [FrappeScope] from the active zone,
  /// falling back to the root scope.
  static FrappeScope get current =>
      (Zone.current[_zoneKey] as FrappeScope?) ?? _root;

  /// Returns the current [FrappeScope] from the zone if one exists,
  /// otherwise null. Does not fall back to the root scope.
  static FrappeScope? get currentOrNull =>
      Zone.current[_zoneKey] as FrappeScope?;

  /// Called when the [Finalizer] detects that a user-facing reference was
  /// garbage collected without being explicitly disposed/cancelled.
  ///
  /// Reports the leak as an uncaught error to the current zone, ensuring
  /// visibility in both debug and release mode. Since finalizers run outside
  /// the reactive graph, this does not affect transaction evaluation.
  static void onLeakDetected(LeakTrackingToken token) {
    final message = StringBuffer()
      ..writeln('=== LEAK DETECTED ===')
      ..writeln('  ${token.type} was garbage collected without being disposed.')
      ..writeln('  Node: ${token.nodeLabel}');
    if (token.creationTrace != null) {
      message.writeln('  Created at:');
      for (final line
          in token.creationTrace.toString().split('\n').take(8)) {
        message.writeln('    $line');
      }
    }
    message.writeln('=====================');
    Zone.current.handleUncaughtError(
      StateError(message.toString()),
      token.creationTrace ?? StackTrace.current,
    );
  }

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

  /// Tracks active user-facing references for leak diagnostics.
  /// Tokens are registered at creation and removed at disposal.
  final Set<LeakTrackingToken> activeUserReferences = Set.identity();

  /// Auto-incrementing node ID counter.
  int nodeIdCounter = 0;

  final ErrorHandler _onError;

  bool _isDisposed = false;

  /// Creates a new isolated scope.
  ///
  /// If [onError] is provided, it handles errors from listener callbacks
  /// and closing handlers during transactions. Defaults to
  /// [defaultErrorHandler], which delegates to the current zone.
  FrappeScope({ErrorHandler? onError})
      : _onError = onError ?? defaultErrorHandler;

  FrappeScope._internal() : _onError = defaultErrorHandler;

  /// Whether this scope has been disposed.
  bool get isDisposed => _isDisposed;

  /// Reports a boundary error from within a transaction (publish or closing
  /// phase). Delegates to the [onError] handler provided at construction.
  void reportError(Object error, StackTrace stackTrace) {
    _onError(error, stackTrace);
  }

  /// Runs [runner] within this scope's zone.
  T run<T>(T Function() runner) {
    _checkDisposed();
    return runZoned(runner, zoneValues: {_zoneKey: this});
  }

  /// Whether a transaction is currently active in this scope's zone.
  bool get isInTransaction => Transaction.currentTransaction != null;

  /// Cleans all state in this scope.
  void cleanState() {
    references.clear();
    alwaysNodes.clear();
    listenNodes.clear();
    targetNodes.clear();
    sourceNodes.clear();
    activeUserReferences.clear();
    nodeIdCounter = 0;
  }

  /// Asserts that all state has been properly cleaned up.
  ///
  /// Produces a structured diagnostic report listing every leaked resource
  /// with its type, node label, and creation stack trace (in assert mode).
  void assertCleanState() {
    final errors = StringBuffer();

    if (references.isNotEmpty) {
      errors.writeln(
          '=== DANGLING REFERENCES (${references.length} referenceable(s)) ===');
      for (final entry in references.entries) {
        final referenceable = entry.key;
        final refs = entry.value;
        final label = referenceable is Node
            ? referenceable.debugLabel
            : '${referenceable.runtimeType}';
        errors.writeln('  $label: ${refs.length} reference(s)');
      }
    }

    if (activeUserReferences.isNotEmpty) {
      errors.writeln(
          '=== UNDISPOSED USER REFERENCES (${activeUserReferences.length}) ===');
      for (final token in activeUserReferences) {
        errors.writeln('  ${token.type} node=${token.nodeLabel}');
        if (token.creationTrace != null) {
          errors.writeln('    Created at:');
          for (final line
              in token.creationTrace.toString().split('\n').take(5)) {
            errors.writeln('      $line');
          }
        }
      }
    }

    if (listenNodes.isNotEmpty) {
      errors.writeln(
          '=== DANGLING LISTEN NODES (${listenNodes.length}) ===');
      for (final node in listenNodes.keys) {
        errors.writeln('  ${node.debugLabel}');
      }
    }

    if (targetNodes.isNotEmpty || sourceNodes.isNotEmpty) {
      errors.writeln('=== UNLINKED NODES ===');
      if (sourceNodes.isNotEmpty) {
        errors.writeln('  Source nodes (${sourceNodes.length}):');
        for (final node in sourceNodes) {
          errors.writeln('    ${node.debugLabel}');
        }
      }
      if (targetNodes.isNotEmpty) {
        errors.writeln('  Target nodes (${targetNodes.length}):');
        for (final node in targetNodes) {
          errors.writeln('    ${node.debugLabel}');
        }
      }
    }

    if (errors.isNotEmpty) {
      throw AssertionError('Clean state assertion failed:\n$errors');
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
      throw StateError('FrappeScope is disposed');
    }
  }
}

/// Runs [runner] within a transaction, using the current scope.
///
/// If already in a transaction, reuses it. Otherwise creates a new one.
T runTransaction<T>(T Function() runner) {
  return Transaction.run((tx) => runner());
}

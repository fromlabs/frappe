import 'disposable.dart';
import 'event_stream.dart';
import 'frappe_scope.dart';
import 'node.dart';
import 'reference.dart';
import 'value_state.dart';

/// Provides [toReference] on [EventStream] for creating a [FrappeReference]
/// that keeps the stream's underlying node alive.
extension EventStreamReferenceExtension<E> on EventStream<E> {
  FrappeReference<EventStream<E>> toReference() =>
      FrappeReference._(this, node);
}

/// Provides [toReference] on [ValueState] for creating a [FrappeReference]
/// that keeps the state's underlying node alive.
extension ValueStateReferenceExtension<V> on ValueState<V> {
  FrappeReference<ValueState<V>> toReference() => FrappeReference._(this, node);
}

/// Collects [FrappeReference]s for batch disposal.
class FrappeReferenceCollector implements Disposable {
  final List<FrappeReference> _references = [];

  /// Adds a frappe object and returns it, creating a reference internally.
  FO add<FO>(FO frappeObject) {
    late final FrappeReference ref;
    // Dynamic type dispatch is needed because toReference() is defined
    // as separate extensions on EventStream and ValueState, so the
    // generic FO type alone cannot resolve which extension to call.
    if (frappeObject is EventStream) {
      ref = frappeObject.toReference();
    } else if (frappeObject is ValueState) {
      ref = frappeObject.toReference();
    } else {
      throw ArgumentError(
          'Unsupported FrappeObject type: ${frappeObject.runtimeType}');
    }
    _references.add(ref);
    return frappeObject;
  }

  /// Disposes all collected [FrappeReference]s and clears the list.
  @override
  void dispose() {
    for (final ref in _references) {
      ref.dispose();
    }
    _references.clear();
  }
}

/// A user-facing reference that keeps a reactive object alive.
///
/// Uses [Finalizer] for leak detection: if the reference is garbage
/// collected without being disposed, a [StateError] is reported to the
/// current zone's uncaught error handler.
class FrappeReference<FO> implements Disposable {
  // Leak detector: if the user forgets to call dispose(), the Dart GC will
  // eventually collect this FrappeReference. The Finalizer reports the leak
  // with diagnostic info instead of silently cleaning up.
  static final _finalizer = Finalizer<LeakTrackingToken>((token) {
    FrappeScope.onLeakDetected(token);
  });

  final FO object;
  final Reference<Node> _reference;
  final LeakTrackingToken _token;
  final FrappeScope _scope;

  FrappeReference._(this.object, Node node)
      : _reference = Reference(node),
        _token = _createToken(node),
        _scope = FrappeScope.current {
    _scope.activeUserReferences.add(_token);
    _finalizer.attach(this, _token, detach: this);
  }

  static LeakTrackingToken _createToken(Node node) {
    StackTrace? trace;
    assert(() {
      trace = StackTrace.current;
      return true;
    }());
    return LeakTrackingToken(
        'FrappeReference<${node.runtimeType}>', node.debugLabel, trace);
  }

  bool get isDisposed => _reference.isDisposed;

  @override
  void dispose() {
    _finalizer.detach(this);
    if (!_scope.isDisposed) {
      _scope.activeUserReferences.remove(_token);
    }
    _reference.dispose();
  }
}

import 'disposable.dart';
import 'event_stream.dart';
import 'node.dart';
import 'reference.dart';
import 'value_state.dart';

/// Extension to create a [FrappeReference] from an [EventStream].
extension EventStreamReferenceExtension<E> on EventStream<E> {
  FrappeReference<EventStream<E>> toReference() =>
      FrappeReference._(this, node);
}

/// Extension to create a [FrappeReference] from a [ValueState].
extension ValueStateReferenceExtension<V> on ValueState<V> {
  FrappeReference<ValueState<V>> toReference() =>
      FrappeReference._(this, node);
}

/// Collects [FrappeReference]s for batch disposal.
class FrappeReferenceCollector implements Disposable {
  final List<FrappeReference> _references = [];

  /// Adds a frappe object and returns it, creating a reference internally.
  FO add<FO>(FO frappeObject) {
    late final FrappeReference ref;
    if (frappeObject is EventStream) {
      ref = frappeObject.toReference();
    } else if (frappeObject is ValueState) {
      ref = frappeObject.toReference();
    } else {
      throw ArgumentError('Unsupported FrappeObject type: ${frappeObject.runtimeType}');
    }
    _references.add(ref);
    return frappeObject;
  }

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
/// Supports automatic cleanup via [Finalizer]. If the reference is
/// garbage collected without being disposed, cleanup happens automatically.
class FrappeReference<FO> implements Disposable {
  static final _finalizer = Finalizer<Reference>((ref) {
    if (!ref.isDisposed) {
      try {
        ref.dispose();
      } catch (_) {
        // Scope may be disposed during GC
      }
    }
  });

  final FO object;
  final Reference<Node> _reference;

  FrappeReference._(this.object, Node node)
      : _reference = Reference(node) {
    _finalizer.attach(this, _reference, detach: this);
  }

  bool get isDisposed => _reference.isDisposed;

  @override
  void dispose() {
    _finalizer.detach(this);
    _reference.dispose();
  }
}

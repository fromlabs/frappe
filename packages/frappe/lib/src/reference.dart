import 'disposable.dart';
import 'frappe_scope.dart';

/// A group of [Reference]s that can be disposed together.
class ReferenceGroup implements Disposable {
  final Set<Reference> _references = Set.identity();
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  /// Creates a new [Reference] to [referenceable], adds it to this group,
  /// and returns it.
  Reference<R> reference<R extends Referenceable>(R referenceable) =>
      add(Reference(referenceable));

  /// Adds an existing [reference] to this group and returns it.
  ///
  /// The reference will be disposed when this group is disposed.
  R add<R extends Reference>(R reference) {
    _checkDisposed();
    _references.add(reference);
    return reference;
  }

  /// Removes a [reference] from this group without disposing it.
  ///
  /// Use this when transferring ownership of a reference elsewhere.
  void remove(Reference reference) {
    _checkDisposed();
    _references.remove(reference);
  }

  @override
  void dispose() {
    _checkDisposed();
    _isDisposed = true;
    while (_references.isNotEmpty) {
      final last = _references.last;
      _references.remove(last);
      last.dispose();
    }
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('ReferenceGroup is disposed');
    }
  }
}

/// A reference to a [Referenceable] object that keeps it alive.
///
/// Reference counting determines object lifetime. When all references
/// to a [Referenceable] are disposed, [Referenceable.onUnreferenced] is called.
class Reference<R extends Referenceable> implements Disposable {
  final R value;
  final FrappeScope _scope;
  bool _isDisposed = false;

  Reference(this.value) : _scope = FrappeScope.current {
    ArgumentError.checkNotNull(value, 'value');
    _registerReference();
  }

  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _checkDisposed();
    _isDisposed = true;
    _unregisterReference();
  }

  @override
  String toString() => '#$value';

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Reference is disposed');
    }
  }

  void _registerReference() {
    _scope.references.putIfAbsent(value, () => Set.identity()).add(this);
    value._refresh(_scope);
  }

  void _unregisterReference() {
    final references = _scope.references[value];
    if (references != null) {
      references.remove(this);
      if (references.isEmpty) {
        _scope.references.remove(value);
      }
    }
    value._refresh(_scope);
  }
}

/// A [Reference] owned by a host [Referenceable], creating a parent-child
/// ownership chain.
///
/// Unlike a standalone [Reference], a hosted reference does not keep its
/// target alive on its own — the target is only considered alive if the
/// host itself is transitively referenced by at least one non-hosted
/// [Reference]. When the host loses all references, its hosted references
/// are disposed as part of cleanup.
class HostedReference<R extends Referenceable> extends Reference<R> {
  final Referenceable _host;

  HostedReference(this._host, R value) : super(value) {
    if (!_host.isReferenced) {
      throw ArgumentError('Unreferenced host');
    }
  }

  @override
  String toString() => '#$_host.$value';

  @override
  void _unregisterReference() {
    // Remove from host's group first, so the host's group state is
    // consistent before super._unregisterReference triggers _refresh
    // on the target (which may cascade further cleanup).
    _host._removeHostedReference(this);
    super._unregisterReference();
  }
}

/// Mixin for objects that participate in reference counting.
///
/// A [Referenceable] is considered "alive" as long as at least one
/// non-hosted [Reference] transitively points to it. When the last
/// such reference is disposed, [onUnreferenced] is called.
abstract class Referenceable {
  final ReferenceGroup _hostedGroup = ReferenceGroup();
  bool _isReferenced = false;

  /// Whether this object has any active references.
  bool get isReferenced => _isReferenced;

  /// Creates a [HostedReference] from this object to [value], establishing
  /// a parent-child ownership link.
  ///
  /// The [value] stays alive as long as this object is transitively
  /// referenced by at least one non-hosted [Reference]. When this object
  /// becomes unreferenced, the hosted reference is disposed automatically.
  HostedReference<R> reference<R extends Referenceable>(R value) {
    _hostedGroup._checkDisposed();
    return _hostedGroup.add(HostedReference(this, value));
  }

  /// Called when this object loses all references.
  void onUnreferenced() {
    if (!_hostedGroup.isDisposed) {
      _hostedGroup.dispose();
    }
  }

  void _removeHostedReference(HostedReference reference) {
    if (!_hostedGroup.isDisposed) {
      _hostedGroup.remove(reference);
    }
  }

  // Called after every reference registration/unregistration to
  // recompute liveness. If no transitive non-hosted reference chain
  // reaches this object, it is considered dead and onUnreferenced()
  // triggers cleanup (disposing hosted references, unlinking nodes, etc.).
  void _refresh(FrappeScope scope) {
    _isReferenced = _checkReferenced(this, scope, Set.identity());
    if (!_isReferenced) {
      onUnreferenced();
    }
  }

  // Depth-first traversal through hosted reference chains to determine
  // if [referenceable] is transitively kept alive.
  //
  // For each reference pointing to [referenceable]:
  //   - If it is a plain Reference (non-hosted), the object is alive.
  //   - If it is a HostedReference, we recurse into its host to check
  //     whether the host itself is alive. The [visited] set prevents
  //     infinite loops in case of circular hosted chains.
  bool _checkReferenced(
      Referenceable referenceable, FrappeScope scope, Set<Reference> visited) {
    final references = scope.references[referenceable];
    if (references != null && references.isNotEmpty) {
      for (final reference in references) {
        if (reference is HostedReference) {
          if (!visited.contains(reference)) {
            visited.add(reference);
            // Recurse into the host to see if it has a non-hosted root.
            if (_checkReferenced(reference._host, scope, visited)) {
              return true;
            }
          }
        } else {
          // A non-hosted reference means the object is directly kept alive.
          return true;
        }
      }
    }
    return false;
  }
}

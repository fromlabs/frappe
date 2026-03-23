import 'dart:async';

import 'package:frappe/frappe.dart';

/// Convenience extensions on [EventStream].
extension EventStreamFutureExtension<E> on EventStream<E> {
  /// Returns a [Future] that completes with the first event.
  Future<E> first() async {
    final completer = Completer<E>();
    listenOnce(completer.complete);
    return completer.future;
  }
}

/// Convenience extensions on [FrappeReference] iterables.
extension FrappeReferenceIterable<FR extends FrappeReference> on Iterable<FR> {
  /// Disposes all references in this iterable.
  void dispose() => forEach((reference) => reference.dispose());
}

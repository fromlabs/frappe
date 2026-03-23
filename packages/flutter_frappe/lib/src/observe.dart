import 'package:flutter/widgets.dart';
import 'package:frappe/frappe.dart';

/// A widget that rebuilds whenever a [ValueState] changes.
///
/// Subscribes to [state] on mount and resubscribes automatically
/// if the state instance changes between widget updates.
class Observe<V> extends StatefulWidget {
  const Observe({
    super.key,
    required this.state,
    required this.builder,
  });

  /// The reactive state to observe.
  final ValueState<V> state;

  /// Builder called with the current value whenever it changes.
  final Widget Function(BuildContext context, V value) builder;

  @override
  State<Observe<V>> createState() => _ObserveState<V>();
}

/// Mutable state for [Observe].
///
/// Manages the subscription lifecycle: subscribes on [initState], resubscribes
/// when the [ValueState] instance changes in [didUpdateWidget], and cancels the
/// subscription on [dispose].
class _ObserveState<V> extends State<Observe<V>> {
  late V _value;
  ListenSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(Observe<V> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resubscribe when the state instance changes to track the new source.
    if (oldWidget.state != widget.state) {
      _unsubscribe();
      _subscribe();
    }
  }

  /// Reads the current value and starts listening for future updates.
  void _subscribe() {
    _value = widget.state.getValue();
    // Errors thrown inside this listener are caught by
    // Transaction._publishValue's per-handler try-catch and routed to
    // FrappeScope.reportError — they won't crash the widget tree.
    // The mounted guard is belt-and-suspenders: the subscription is
    // cancelled in dispose(), but we check anyway to be safe against
    // framework-level edge cases (e.g. a listener firing during a
    // disposal sequence).
    _subscription = widget.state.listen((value) {
      if (mounted) {
        setState(() => _value = value);
      }
    });
  }

  /// Cancels the active subscription and clears the reference.
  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

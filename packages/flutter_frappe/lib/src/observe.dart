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

  void _subscribe() {
    _value = widget.state.getValue();
    _subscription = widget.state.listen((value) {
      setState(() => _value = value);
    });
  }

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

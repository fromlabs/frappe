import 'package:flutter/widgets.dart';
import 'package:frappe/frappe.dart';

typedef StateWidgetBuilder<S> = Widget Function(BuildContext context, S value);

class ValueStateBuilder<S> extends StatefulWidget {
  final ValueState<S> _state;
  final StateWidgetBuilder<S> _builder;

  const ValueStateBuilder({
    required ValueState<S> state,
    required StateWidgetBuilder<S> builder,
    Key? key,
  })  : _state = state,
        _builder = builder,
        super(key: key);

  @override
  _ValueStateBuilderState<S> createState() => _ValueStateBuilderState<S>();

  Widget _build(BuildContext context, S state) => _builder(context, state);
}

class _ValueStateBuilderState<S> extends State<ValueStateBuilder<S>> {
  ListenSubscription? _listenCanceler;

  @override
  void initState() {
    super.initState();

    _subscribe();
  }

  @override
  void didUpdateWidget(ValueStateBuilder<S> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget._state != oldWidget._state) {
      _unsubscribe();

      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget._build(context, widget._state.getValue());

  void _subscribe() {
    _listenCanceler = runTransaction(
        () => widget._state.toUpdates().listen((state) => setState(() {})));
  }

  void _unsubscribe() {
    _listenCanceler?.cancel();
    _listenCanceler = null;
  }
}

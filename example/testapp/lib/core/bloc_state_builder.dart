import 'package:flutter/widgets.dart';
import 'package:frappe/frappe.dart';
import 'package:testapp/core/frappe_bloc.dart';

typedef ValueStateWidgetBuilder<S> = Widget Function(
    BuildContext context, S state);

class BlocStateBuilder<S> extends StatefulWidget {
  final ValueState<S> _state;
  final ValueStateWidgetBuilder<S> _builder;

  BlocStateBuilder({
    required Bloc<S> bloc,
    required ValueStateWidgetBuilder<S> builder,
    Key? key,
  })  : _state = bloc.state,
        _builder = builder,
        super(key: key);

  @override
  _BlocStateBuilderState<S> createState() => _BlocStateBuilderState<S>();

  Widget _build(BuildContext context, S state) => _builder(context, state);
}

class _BlocStateBuilderState<S> extends State<BlocStateBuilder<S>> {
  ListenSubscription? _listenCanceler;

  @override
  void initState() {
    super.initState();

    _subscribe();
  }

  @override
  void didUpdateWidget(BlocStateBuilder<S> oldWidget) {
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

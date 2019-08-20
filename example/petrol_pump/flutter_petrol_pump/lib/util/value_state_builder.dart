import 'package:flutter/widgets.dart';
import 'package:optional/optional.dart';
import 'package:frappe/frappe.dart';
import 'package:meta/meta.dart';

typedef StateWidgetBuilder<S> = Widget Function(BuildContext context, S value);

typedef OptionalStateWidgetBuilder<S> = Widget Function(
    BuildContext context, Optional<S> value);

class ValueStateBuilder<S> extends StatefulWidget {
  final ValueState<S> _state;
  final StateWidgetBuilder<S> _builder;

  const ValueStateBuilder({
    @required ValueState<S> state,
    @required StateWidgetBuilder<S> builder,
    Key key,
  })  : _state = state,
        _builder = builder,
        super(key: key);

  @override
  _ValueStateBuilderState<S> createState() => _ValueStateBuilderState<S>();

  Widget _build(BuildContext context, S state) => _builder(context, state);
}

class _ValueStateBuilderState<S> extends State<ValueStateBuilder<S>> {
  ListenSubscription _listenCanceler;

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
      widget._build(context, widget._state.current);

  void _subscribe() {
    _listenCanceler = widget._state.listen((state) => setState(() {}));
  }

  void _unsubscribe() {
    _listenCanceler?.cancel();
    _listenCanceler = null;
  }
}

class OptionalValueStateBuilder<S> extends StatefulWidget {
  final OptionalValueState<S> _state;
  final OptionalStateWidgetBuilder<S> _builder;

  const OptionalValueStateBuilder({
    @required OptionalValueState<S> state,
    @required OptionalStateWidgetBuilder<S> builder,
    Key key,
  })  : _state = state,
        _builder = builder,
        super(key: key);

  @override
  _OptionalValueStateBuilderState<S> createState() =>
      _OptionalValueStateBuilderState<S>();

  Widget _build(BuildContext context, Optional<S> state) =>
      _builder(context, state);
}

class _OptionalValueStateBuilderState<S>
    extends State<OptionalValueStateBuilder<S>> {
  ListenSubscription _listenCanceler;

  @override
  void initState() {
    super.initState();

    _subscribe();
  }

  @override
  void didUpdateWidget(OptionalValueStateBuilder<S> oldWidget) {
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
      widget._build(context, widget._state.current);

  void _subscribe() {
    _listenCanceler = widget._state.listen((state) => setState(() {}));
  }

  void _unsubscribe() {
    _listenCanceler?.cancel();
    _listenCanceler = null;
  }
}

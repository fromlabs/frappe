import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:frappe/frappe.dart';
import 'package:testapp/core/frappe_bloc.dart';

typedef BlocFactory<B extends Bloc> = B Function();
typedef BlocWidgetBuilder<B extends Bloc> = Widget Function(
    BuildContext context, B bloc);
typedef BlocStateWidgetBuilder<S> = Widget Function(
    BuildContext context, S state);

class GlobalBlocKey<B extends Bloc> {
  final GlobalKey<_BlocProviderState<B>> key =
      GlobalKey<_BlocProviderState<B>>();

  B get currentBloc => BlocProvider.by(this);
}

class BlocProviderError<B extends Bloc> extends Error {
  BlocProviderError();

  @override
  String toString() => '''Error: Could not find the correct Bloc.
    
To fix, please:
          
  * Provide types to BlocProvider<$B>
  * Provide types to BlocInject<$B> 
  * Provide types to BlocProvider.of<$B>() 
  * Always use package imports. Ex: `import 'package:my_app/my_bloc.dart';''';
}

class BlocProvider<B extends Bloc> extends StatefulWidget {
  final BlocFactory<B> _factory;

  final BlocWidgetBuilder<B> _builder;

  final bool _disposeBlocOnDestroy;

  const BlocProvider({
    required BlocFactory<B> factory,
    required BlocWidgetBuilder<B> builder,
    Key? key,
  })  : _factory = factory,
        _builder = builder,
        _disposeBlocOnDestroy = true,
        super(key: key);

  BlocProvider.instance({
    required final B bloc,
    required BlocWidgetBuilder<B> builder,
    Key? key,
  })  : _factory = (() => bloc),
        _builder = builder,
        _disposeBlocOnDestroy = false,
        super(key: key);

  @override
  _BlocProviderState createState() => _BlocProviderState<B>();

  static B of<B extends Bloc>(
    BuildContext context,
  ) {
    final inheritedBloc = context
        .getElementForInheritedWidgetOfExactType<_InheritedBloc<B>>()
        ?.widget;

    if (inheritedBloc is _InheritedBloc<B>) {
      return inheritedBloc._bloc;
    } else {
      throw BlocProviderError<B>();
    }
  }

  static B by<B extends Bloc>(GlobalBlocKey<B> blocKey) =>
      blocKey.key.currentState!._bloc;
}

class _BlocProviderState<B extends Bloc> extends State<BlocProvider<B>> {
  late B _bloc;

  @override
  void initState() {
    super.initState();

    _createBloc();
  }

  @override
  void dispose() {
    _destroyBloc();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _InheritedBloc(_bloc, widget._builder(context, _bloc));

  void _createBloc() {
    _bloc = widget._factory();
  }

  void _destroyBloc() {
    final Object bloc = _bloc;
    if (bloc is Disposable && widget._disposeBlocOnDestroy) {
      bloc.dispose();
    }
  }
}

class _InheritedBloc<B extends Bloc> extends InheritedWidget {
  final B _bloc;

  const _InheritedBloc(B bloc, Widget child)
      : _bloc = bloc,
        super(child: child);

  @override
  bool updateShouldNotify(_InheritedBloc<B> oldWidget) => false;
}

class BlocInject<B extends Bloc> extends StatelessWidget {
  final BlocWidgetBuilder<B> _builder;

  const BlocInject({
    required BlocWidgetBuilder<B> builder,
    Key? key,
  })  : _builder = builder,
        super(key: key);

  @override
  Widget build(BuildContext context) =>
      _builder(context, BlocProvider.of<B>(context));
}

import 'package:flutter/widgets.dart';
import 'package:brew/brew.dart';

/// Provides a [Brew] instance to the widget tree via [InheritedWidget].
///
/// Creates the brew lazily on first build and disposes it automatically
/// when the provider is removed from the tree.
class BrewProvider<B extends Brew> extends StatefulWidget {
  const BrewProvider({
    super.key,
    required this.create,
    required this.child,
  });

  /// Factory function that creates the [Brew] instance.
  final B Function() create;

  /// The widget subtree that can access this brew via [of].
  final Widget child;

  /// Retrieves the nearest [Brew] of type [B] from the widget tree.
  static B of<B extends Brew>(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<_BrewInherited<B>>();
    assert(provider != null, 'No BrewProvider<$B> found in context');
    return provider!.brew;
  }

  @override
  State<BrewProvider<B>> createState() => _BrewProviderState<B>();
}

class _BrewProviderState<B extends Brew> extends State<BrewProvider<B>> {
  late final B brew = widget.create();

  @override
  void dispose() {
    brew.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BrewInherited<B>(
      brew: brew,
      child: widget.child,
    );
  }
}

class _BrewInherited<B extends Brew> extends InheritedWidget {
  const _BrewInherited({
    required this.brew,
    required super.child,
  });

  final B brew;

  @override
  bool updateShouldNotify(_BrewInherited<B> oldWidget) => false;
}

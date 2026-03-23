import '../models.dart';

/// Function signature for creating pump [Outputs] from [Inputs].
typedef CreatePump = Outputs Function(Inputs inputs);

/// Abstract pump logic that transforms [Inputs] into [Outputs].
abstract class Pump {
  /// Builds the reactive output graph from the given [inputs].
  Outputs create(Inputs inputs);
}

/// Base class for pump logic implementations.
abstract class BasePump implements Pump {
  @override
  String toString() => runtimeType.toString();
}

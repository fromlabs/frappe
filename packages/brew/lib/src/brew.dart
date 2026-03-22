import 'package:frappe/frappe.dart';

/// Base class for reactive business logic units.
///
/// Subclass [Brew] and implement [onBind] to set up reactive streams
/// and states. Use [collect] to register them for automatic disposal.
abstract class Brew {
  Brew() {
    onBind();
  }

  /// Called during construction to initialize reactive streams and states.
  void onBind();

  final FrappeReferenceCollector _collector = FrappeReferenceCollector();

  /// Registers a reactive object for automatic disposal and returns it.
  FO collect<FO>(FO frappeObject) => _collector.add(frappeObject);

  /// Disposes all collected reactive objects.
  void dispose() {
    _collector.dispose();
  }
}

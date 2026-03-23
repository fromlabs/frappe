import 'package:frappe/frappe.dart';

/// A point-of-sale simulator that produces clear-sale events.
abstract class PosTerminal implements Disposable {
  /// Fires when the POS terminal has finished processing and clears the sale.
  EventStream<Unit> get clearSaleStream;
}

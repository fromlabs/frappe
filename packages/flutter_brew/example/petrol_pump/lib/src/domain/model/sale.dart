import 'fuel.dart';

/// A completed fuel sale.
class Sale {
  /// The type of fuel dispensed.
  final Fuel fuel;

  /// The per-unit price at which fuel was sold.
  final double price;

  /// The quantity of fuel dispensed (in liters).
  final double quantity;

  /// The total cost of the sale (price * quantity).
  final double cost;

  const Sale({
    required this.fuel,
    required this.price,
    required this.quantity,
    required this.cost,
  });

  @override
  String toString() =>
      'Sale(fuel: $fuel, price: $price, quantity: $quantity, cost: $cost)';
}

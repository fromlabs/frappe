import 'package:frappe/frappe.dart';

import '../logic/fill.dart';
import '../logic/lifecycle.dart';
import '../model.dart';

/// Manages the point-of-sale notification lifecycle:
/// tracks fill state, fuel flowing, and emits sale-complete events.
class NotifyPointOfSale {
  /// Which fuel is shown on the display; persists until the sale is cleared.
  final ValueState<Fuel?> fillActiveState;

  /// Which fuel is physically flowing; cleared immediately when the nozzle is set down.
  final ValueState<Fuel?> fuelFlowingState;

  /// Fires with the [Fuel] type when a fill is allowed to begin.
  final EventStream<Fuel> startStream;

  /// Fires when the active fill ends (nozzle set down while filling).
  final EventStream<Unit> endStream;

  /// Fires when the sale is cleared at the point of sale (triggers a beep).
  final EventStream<Unit> beepStream;

  /// Emits a [Sale] record when a fill completes, capturing the final totals.
  final EventStream<Sale> saleCompleteStream;

  factory NotifyPointOfSale({
    required Lifecycle lifecycle,
    required Fill fill,
    required EventStream<Unit> clearSaleStream,
  }) {
    // startStream/endStream are derived inside the loop but exposed as outputs.
    late EventStream<Fuel> startStream;
    late EventStream<Unit> endStream;

    // Phase transitions: idle -> filling -> pos -> idle.
    // The returned ValueState is not used directly -- the loop only establishes
    // the cycle so that startStream/endStream are gated by the phase.
    ValueState.loop<_Phase>((self) {
      // Only allow start when idle.
      startStream = lifecycle.startStream
          .gate(self.map((phase) => phase == _Phase.idle));

      // Only allow end when filling.
      endStream = lifecycle.endStream
          .gate(self.map((phase) => phase == _Phase.filling))
          .mapToUnit();

      return startStream.mapTo(_Phase.filling).orElses([
        endStream.mapTo(_Phase.pos),
        clearSaleStream.mapTo(_Phase.idle),
      ]).toState(_Phase.idle);
    });

    // Fuel flowing: set on start, cleared on end.
    final fuelFlowingState = startStream
        .map<Fuel?>((e) => e)
        .orElse(endStream.mapTo<Fuel?>(null))
        .toState(null);

    // Fill active: set on start, cleared on clear-sale (not just end).
    final fillActiveState = startStream
        .map<Fuel?>((e) => e)
        .orElse(clearSaleStream.mapTo<Fuel?>(null))
        .toState(null);

    // Build the sale snapshot and emit when the fill ends.
    final saleCompleteStream = endStream
        .snapshot<Sale?, Sale?>(
            fuelFlowingState.combine3<double, double, double, Sale?>(
                fill.priceState,
                fill.dollarsDeliveredState,
                fill.litersDeliveredState,
                (fuelFlowing, price, dollarsDelivered, litersDelivered) =>
                    fuelFlowing != null
                        ? Sale(
                            fuel: fuelFlowing,
                            price: price,
                            quantity: litersDelivered,
                            cost: dollarsDelivered,
                          )
                        : null),
            (_, sale) => sale)
        .mapWhereNotNull();

    return NotifyPointOfSale._(
      fillActiveState: fillActiveState,
      fuelFlowingState: fuelFlowingState,
      startStream: startStream,
      endStream: endStream,
      beepStream: clearSaleStream,
      saleCompleteStream: saleCompleteStream,
    );
  }

  /// References all reactive fields via [collector], keeping them alive
  /// until the collector is disposed. Returns `this` for chaining.
  NotifyPointOfSale hold(FrappeReferenceCollector collector) {
    collector
      ..add(fillActiveState)
      ..add(fuelFlowingState)
      ..add(startStream)
      ..add(endStream)
      ..add(beepStream)
      ..add(saleCompleteStream);
    return this;
  }

  NotifyPointOfSale._({
    required this.fillActiveState,
    required this.fuelFlowingState,
    required this.startStream,
    required this.endStream,
    required this.beepStream,
    required this.saleCompleteStream,
  });
}

enum _Phase {
  /// No active fill; the pump is ready for a new customer.
  idle,

  /// Fuel is being dispensed; the nozzle is lifted.
  filling,

  /// Fill complete; waiting for the point-of-sale to clear the transaction.
  pos,
}

import 'package:meta/meta.dart';
import 'package:optional/optional.dart';
import 'package:frappe/frappe.dart';
import '../logic/fill.dart';
import '../logic/lifecycle.dart';
import '../model.dart';

class NotifyPointOfSale {
  final OptionalValueState<Fuel> fillActiveState;
  final OptionalValueState<Fuel> fuelFlowingState;
  final EventStream<Fuel> startStream;
  final EventStream<Unit> endStream;
  final EventStream<Unit> beepStream;
  final EventStream<Sale> saleCompleteStream;

  factory NotifyPointOfSale({
    @required Lifecycle lifecycle,
    @required Fill fill,
    @required EventStream<Unit> clearSaleStream,
  }) {
    final phaseStateRef = ValueStateLink();

    final startStream = lifecycle.startStream
        .gate(phaseStateRef.state.map((phase) => phase == _Phase.idle));

    final endStream = lifecycle.endStream
        .gate(phaseStateRef.state.map((phase) => phase == _Phase.filling))
        .mapTo(unit);

    phaseStateRef.connect(startStream.mapTo(_Phase.filling).orElses([
      endStream.mapTo(_Phase.pos),
      clearSaleStream.mapTo(_Phase.idle)
    ]).toState(_Phase.idle));

    final fuelFlowingState = startStream
        .mapToOptionalOf()
        .orElse(endStream.mapToOptionalEmpty<Fuel>())
        .toState(Optional.empty())
        .asOptional<Fuel>();

    final fillActiveState = startStream
        .mapToOptionalOf()
        .orElse(clearSaleStream.mapToOptionalEmpty<Fuel>())
        .toState(Optional.empty())
        .asOptional<Fuel>();

    final saleCompleteStream = endStream
        .snapshot<Optional<Sale>, Optional<Sale>>(
            fuelFlowingState.combine3<double, double, double, Optional<Sale>>(
                fill.priceState,
                fill.dollarsDeliveredState,
                fill.litersDeliveredState,
                (fuelFlowing, price, dollarsDelivered, litersDelivered) =>
                    fuelFlowing.isPresent
                        ? Optional.of(Sale((builder) => builder
                          ..fuel = fuelFlowing.value
                          ..price = price
                          ..quantity = litersDelivered
                          ..cost = dollarsDelivered))
                        : Optional<Sale>.empty()),
            (_, sale) => sale)
        .asOptional<Sale>()
        .mapWhereOptional();

    return NotifyPointOfSale._(
      fillActiveState: fillActiveState,
      fuelFlowingState: fuelFlowingState,
      startStream: startStream,
      endStream: endStream,
      beepStream: clearSaleStream,
      saleCompleteStream: saleCompleteStream,
    );
  }
  NotifyPointOfSale._({
    this.fillActiveState,
    this.fuelFlowingState,
    this.startStream,
    this.endStream,
    this.beepStream,
    this.saleCompleteStream,
  });
}

enum _Phase { idle, filling, pos }

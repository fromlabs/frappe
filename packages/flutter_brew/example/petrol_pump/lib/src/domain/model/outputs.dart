import 'package:frappe/frappe.dart';

import 'delivery.dart';
import 'sale.dart';

/// Reactive outputs from the pump logic.
class Outputs {
  /// Current fuel delivery speed.
  final ValueState<Delivery> deliveryState;

  /// Text shown on the preset dollar amount LCD.
  final ValueState<String> presetLcdState;

  /// Text shown on the sale cost LCD.
  final ValueState<String> saleCostLcdState;

  /// Text shown on the sale quantity LCD.
  final ValueState<String> saleQuantityLcdState;

  /// Text shown on the fuel type 1 price LCD.
  final ValueState<String> priceLcd1State;

  /// Text shown on the fuel type 2 price LCD.
  final ValueState<String> priceLcd2State;

  /// Text shown on the fuel type 3 price LCD.
  final ValueState<String> priceLcd3State;

  /// Fires when the pump should emit a beep sound.
  final EventStream<Unit> beepStream;

  /// Fires with the completed [Sale] when fueling finishes.
  final EventStream<Sale> saleCompleteStream;

  Outputs({
    required this.deliveryState,
    required this.presetLcdState,
    required this.saleCostLcdState,
    required this.saleQuantityLcdState,
    required this.priceLcd1State,
    required this.priceLcd2State,
    required this.priceLcd3State,
    required this.beepStream,
    required this.saleCompleteStream,
  });

  /// Flattens a state-of-[Outputs] into a single [Outputs] by switch-mapping
  /// each field individually.
  ///
  /// [ValueState] fields use [switchMapState] + [distinct] so the output
  /// only updates when the inner value actually changes.
  /// [EventStream] fields use [switchMapStream] to forward events from
  /// whichever inner [Outputs] is currently active.
  factory Outputs.switchFrom(ValueState<Outputs> outputsState) {
    return Outputs(
      deliveryState: outputsState
          .switchMapState((o) => o.deliveryState)
          .distinct(),
      presetLcdState: outputsState
          .switchMapState((o) => o.presetLcdState)
          .distinct(),
      saleCostLcdState: outputsState
          .switchMapState((o) => o.saleCostLcdState)
          .distinct(),
      saleQuantityLcdState: outputsState
          .switchMapState((o) => o.saleQuantityLcdState)
          .distinct(),
      priceLcd1State: outputsState
          .switchMapState((o) => o.priceLcd1State)
          .distinct(),
      priceLcd2State: outputsState
          .switchMapState((o) => o.priceLcd2State)
          .distinct(),
      priceLcd3State: outputsState
          .switchMapState((o) => o.priceLcd3State)
          .distinct(),
      beepStream:
          outputsState.switchMapStream((o) => o.beepStream),
      saleCompleteStream:
          outputsState.switchMapStream((o) => o.saleCompleteStream),
    );
  }

  /// Creates outputs with default (inert) values.
  ///
  /// Any parameter left null is replaced with an off/empty constant state
  /// or a never-firing stream. Used as a fallback when no pump logic is
  /// selected.
  factory Outputs.defaults({
    ValueState<Delivery>? deliveryState,
    ValueState<String>? presetLcdState,
    ValueState<String>? saleCostLcdState,
    ValueState<String>? saleQuantityLcdState,
    ValueState<String>? priceLcd1State,
    ValueState<String>? priceLcd2State,
    ValueState<String>? priceLcd3State,
    EventStream<Unit>? beepStream,
    EventStream<Sale>? saleCompleteStream,
  }) {
    return Outputs(
      deliveryState: deliveryState ?? ValueState.constant(Delivery.off),
      presetLcdState: presetLcdState ?? ValueState.constant(''),
      saleCostLcdState: saleCostLcdState ?? ValueState.constant(''),
      saleQuantityLcdState: saleQuantityLcdState ?? ValueState.constant(''),
      priceLcd1State: priceLcd1State ?? ValueState.constant(''),
      priceLcd2State: priceLcd2State ?? ValueState.constant(''),
      priceLcd3State: priceLcd3State ?? ValueState.constant(''),
      beepStream: beepStream ?? EventStream.never(),
      saleCompleteStream: saleCompleteStream ?? EventStream.never(),
    );
  }
}

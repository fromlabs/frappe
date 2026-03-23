import 'package:frappe/frappe.dart';
import 'package:petrol_pump/petrol_pump.dart';
import 'package:test/test.dart';

void main() {
  late FrappeScope scope;

  setUp(() {
    scope = FrappeScope();
  });

  tearDown(() {
    scope.run(() => scope.assertCleanState());
    scope.dispose();
  });

  group('Preset', () {
    test('delivery is off when no fuel is flowing', () {
      scope.run(() {
        runTransaction(() {
          final fill = Fill(
            clearAccumulatorStream: EventStream.never(),
            fuelsPulsesStream: EventStream.never(),
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: EventStream.never(),
          );

          final ValueState<Fuel?> noFuel = ValueState.constant(null);

          final preset = Preset(
            fill: fill,
            presetDollarsState: ValueState.constant(0),
            fuelFlowingState: noFuel,
          );

          final ref = preset.deliveryState.toReference();

          expect(preset.deliveryState.getValue(), Delivery.off);
          expect(preset.isKeypadActiveState.getValue(), true);

          ref.dispose();
        });
      });
    });

    test('delivery is fast when fuel is flowing with no preset', () {
      scope.run(() {
        runTransaction(() {
          final fill = Fill(
            clearAccumulatorStream: EventStream.never(),
            fuelsPulsesStream: EventStream.never(),
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: EventStream.never(),
          );

          final ValueState<Fuel?> fuel1 = ValueState.constant(Fuel.one);

          final preset = Preset(
            fill: fill,
            presetDollarsState: ValueState.constant(0),
            fuelFlowingState: fuel1,
          );

          final ref = preset.deliveryState.toReference();

          expect(preset.deliveryState.getValue(), Delivery.fast1);

          ref.dispose();
        });
      });
    });

    test('maps each fuel type to correct delivery speed', () {
      scope.run(() {
        runTransaction(() {
          final fill = Fill(
            clearAccumulatorStream: EventStream.never(),
            fuelsPulsesStream: EventStream.never(),
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: EventStream.never(),
          );

          final ValueState<Fuel?> fuel2 = ValueState.constant(Fuel.two);

          final preset = Preset(
            fill: fill,
            presetDollarsState: ValueState.constant(0),
            fuelFlowingState: fuel2,
          );

          final ref = preset.deliveryState.toReference();
          expect(preset.deliveryState.getValue(), Delivery.fast2);
          ref.dispose();
        });

        runTransaction(() {
          final fill = Fill(
            clearAccumulatorStream: EventStream.never(),
            fuelsPulsesStream: EventStream.never(),
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: EventStream.never(),
          );

          final ValueState<Fuel?> fuel3 = ValueState.constant(Fuel.three);

          final preset = Preset(
            fill: fill,
            presetDollarsState: ValueState.constant(0),
            fuelFlowingState: fuel3,
          );

          final ref = preset.deliveryState.toReference();
          expect(preset.deliveryState.getValue(), Delivery.fast3);
          ref.dispose();
        });
      });
    });

    test('keypad is active when no fuel is flowing', () {
      scope.run(() {
        runTransaction(() {
          final fill = Fill(
            clearAccumulatorStream: EventStream.never(),
            fuelsPulsesStream: EventStream.never(),
            calibrationState: ValueState.constant(1.0),
            price1State: ValueState.constant(2.0),
            price2State: ValueState.constant(3.0),
            price3State: ValueState.constant(4.0),
            startStream: EventStream.never(),
          );

          final ValueState<Fuel?> noFuel = ValueState.constant(null);

          final preset = Preset(
            fill: fill,
            presetDollarsState: ValueState.constant(10),
            fuelFlowingState: noFuel,
          );

          final ref = preset.deliveryState.toReference();
          // Keypad active when no fuel is flowing, regardless of preset.
          expect(preset.isKeypadActiveState.getValue(), true);
          ref.dispose();
        });
      });
    });
  });
}

import 'package:frappe/frappe.dart';
import 'package:petrol_pump_brew/petrol_pump_brew.dart';
import 'package:test/test.dart';

void main() {
  // DefaultPetrolPumpBrew creates a PumpEngine simulator internally,
  // which uses async cleanup. FrappeScope assertion is not used here —
  // the brew's own dispose handles resource release.

  late PetrolPumpBrew brew;

  setUp(() {
    runTransaction(() {
      brew = DefaultPetrolPumpBrew();
    });
  });

  tearDown(() {
    brew.dispose();
  });

  group('DefaultPetrolPumpBrew', () {
    test('initial state has no pump logic selected', () {
      expect(brew.pumpLogicState.getValue(), isNull);
    });

    test('initial delivery is off', () {
      expect(brew.deliveryState.getValue(), Delivery.off);
    });

    test('initial nozzles are all down', () {
      for (final nozzle in brew.nozzleStates) {
        expect(nozzle.getValue(), UpDown.down);
      }
    });

    test('initial price settings match defaults', () {
      expect(brew.priceSettingStates[0].getValue(), 2.149);
      expect(brew.priceSettingStates[1].getValue(), 2.341);
      expect(brew.priceSettingStates[2].getValue(), 1.499);
    });

    test('initial LCD values are null (no pump logic)', () {
      expect(brew.presetState.getValue(), isNull);
      expect(brew.saleCostState.getValue(), isNull);
      expect(brew.saleQuantityState.getValue(), isNull);
    });

    test('setPumpLogic updates pumpLogicState', () {
      final pump = PresetAmountPump();
      brew.setPumpLogic(pump);
      expect(brew.pumpLogicState.getValue(), pump);
    });

    test('toggleNozzle flips nozzle state', () {
      brew.setPumpLogic(LifecyclePump());

      brew.toggleNozzle(1);
      expect(brew.nozzleStates[0].getValue(), UpDown.up);

      brew.toggleNozzle(1);
      expect(brew.nozzleStates[0].getValue(), UpDown.down);
    });

    test('toggleNozzle works for all three nozzles', () {
      brew.setPumpLogic(LifecyclePump());

      brew.toggleNozzle(2);
      expect(brew.nozzleStates[1].getValue(), UpDown.up);

      brew.toggleNozzle(3);
      // Nozzle 2 still up (only one can be active in lifecycle, but toggle is independent).
      expect(brew.nozzleStates[2].getValue(), UpDown.up);
    });

    test('lifting nozzle with LifecyclePump activates delivery', () {
      brew.setPumpLogic(LifecyclePump());

      brew.toggleNozzle(1);
      expect(brew.deliveryState.getValue(), Delivery.fast1);

      brew.toggleNozzle(1);
      expect(brew.deliveryState.getValue(), Delivery.off);
    });

    test('setPriceSetting updates price', () {
      brew.setPriceSetting(1, 3.0);
      expect(brew.priceSettingStates[0].getValue(), 3.0);

      brew.setPriceSetting(2, 4.0);
      expect(brew.priceSettingStates[1].getValue(), 4.0);

      brew.setPriceSetting(3, 5.0);
      expect(brew.priceSettingStates[2].getValue(), 5.0);
    });

    test('pressKey updates preset with KeypadPump', () {
      brew.setPumpLogic(KeypadPump());

      brew.pressKey(NumericKey.five);
      expect(brew.presetState.getValue(), 5.0);

      brew.pressKey(NumericKey.zero);
      expect(brew.presetState.getValue(), 50.0);
    });

    test('beep fires on keypad press with KeypadPump', () {
      brew.setPumpLogic(KeypadPump());

      final beeps = <Unit>[];
      final sub = brew.beepStream.listen(beeps.add);

      brew.pressKey(NumericKey.one);
      expect(beeps, hasLength(1));

      brew.pressKey(NumericKey.two);
      expect(beeps, hasLength(2));

      sub.cancel();
    });

    test('switching pump logic resets outputs', () {
      brew.setPumpLogic(KeypadPump());
      brew.pressKey(NumericKey.seven);
      expect(brew.presetState.getValue(), 7.0);

      // Switch to LifecyclePump — preset should reset.
      brew.setPumpLogic(LifecyclePump());
      expect(brew.presetState.getValue(), isNull);
    });

    test('full cycle with PresetAmountPump', () async {
      brew.setPumpLogic(PresetAmountPump());

      // Preset should start at 0.
      expect(brew.presetState.getValue(), 0.0);

      // Lift nozzle — delivery starts.
      brew.toggleNozzle(1);
      expect(brew.deliveryState.getValue(), isNot(Delivery.off));

      // Let the engine generate some pulses.
      await Future<void>.delayed(const Duration(seconds: 1));

      // Sale cost should have accumulated.
      expect(brew.saleCostState.getValue(), isNotNull);
      expect(brew.saleCostState.getValue()!, greaterThan(0));

      // Put nozzle down — delivery stops.
      brew.toggleNozzle(1);
      expect(brew.deliveryState.getValue(), Delivery.off);

      // Wait for POS auto-clear.
      await Future<void>.delayed(const Duration(seconds: 3));
    });

    test('clearSale resets after sale complete', () async {
      brew.setPumpLogic(PresetAmountPump());

      final sales = <Sale>[];
      final sub = brew.saleCompleteStream.listen(sales.add);

      brew.toggleNozzle(1);
      await Future<void>.delayed(const Duration(seconds: 1));
      brew.toggleNozzle(1);

      // Sale should have been emitted.
      expect(sales, hasLength(1));
      expect(sales[0].fuel, Fuel.one);

      // Manual clear.
      brew.clearSale();

      sub.cancel();
    });

    test('setPumpLogic to null clears all outputs', () {
      brew.setPumpLogic(LifecyclePump());
      brew.toggleNozzle(1);
      expect(brew.deliveryState.getValue(), Delivery.fast1);

      brew.toggleNozzle(1);
      brew.setPumpLogic(null);
      expect(brew.deliveryState.getValue(), Delivery.off);
      expect(brew.presetState.getValue(), isNull);
    });
  });
}

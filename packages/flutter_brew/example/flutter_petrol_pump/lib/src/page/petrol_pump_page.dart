import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_brew/flutter_brew.dart';
import 'package:frappe/frappe.dart';
import 'package:petrol_pump_brew/petrol_pump_brew.dart';

import '../component/pump_nozzle.dart';
import '../widget/lcd.dart';
import '../widget/numeric_pad.dart';

final AudioPlayer _deliveryPlayer = AudioPlayer();
final AudioPlayer _beepPlayer = AudioPlayer();

final _pumps = <Pump?>[
  null,
  LifecyclePump(),
  AccumulatePulsesPump(),
  ShowDollarsPump(),
  KeypadPump(),
  ClearSalePump(),
  PresetAmountPump(),
];

/// The main petrol pump page with LCDs, nozzles, and keypad.
class PetrolPumpPage extends StatefulWidget {
  const PetrolPumpPage({super.key});

  @override
  State<PetrolPumpPage> createState() => _PetrolPumpPageState();
}

class _PetrolPumpPageState extends State<PetrolPumpPage> {
  ListenSubscription? _listenCanceler;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize once; inherited widget lookup is not available in initState.
    if (_listenCanceler != null) return;

    final brew = _lookupBrew(context);

    // Start with the most complete pump logic.
    brew.setPumpLogic(_pumps.last);

    _listenCanceler = brew.beepStream.listen((_) {
      _beepPlayer.play(AssetSource('beep.wav'));
    }).append(brew.deliveryState.listen((delivery) {
      switch (delivery) {
        case Delivery.fast1:
        case Delivery.fast2:
        case Delivery.fast3:
          _deliveryPlayer.setReleaseMode(ReleaseMode.loop);
          _deliveryPlayer.play(AssetSource('fast.wav'));
        case Delivery.slow1:
        case Delivery.slow2:
        case Delivery.slow3:
          _deliveryPlayer.setReleaseMode(ReleaseMode.loop);
          _deliveryPlayer.play(AssetSource('slow.wav'));
        case Delivery.off:
          _deliveryPlayer.stop();
      }
    })).append(brew.saleCompleteStream.listen((sale) async {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Sale complete'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Fuel: ${sale.fuel}'),
                Text('Price: ${sale.price}'),
                Text('Quantity: ${sale.quantity}'),
                Text('Cost: ${sale.cost}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      brew.clearSale();
    }));
  }

  @override
  void dispose() {
    _listenCanceler?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brew = _lookupBrew(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Petrol Pump'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: Row(
        children: <Widget>[
          Expanded(
              flex: 2,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image(image: AssetImage('assets/logo.png')),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(136, 140, 96, 1),
                        border: Border.all(
                          color: Colors.black,
                          width: 2.0,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: Observe<double?>(
                            state: brew.presetState,
                            builder: (context, preset) => Lcd(
                                digitCount: 5,
                                decimalDigitCount: 2,
                                value: preset)),
                      ),
                    ),
                  ),
                  const Text('PRESET'),
                  const Padding(padding: EdgeInsets.all(6.0)),
                  Expanded(
                    flex: 3,
                    child: NumericPad(
                      onNumericKey: brew.pressKey,
                    ),
                  ),
                ],
              )),
          Expanded(
              flex: 3,
              child: Column(
                children: <Widget>[
                  const Padding(padding: EdgeInsets.all(2.0)),
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(136, 140, 96, 1),
                        border: Border.all(
                          color: Colors.black,
                          width: 2.0,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: Observe<double?>(
                            state: brew.saleCostState,
                            builder: (context, saleCost) => Lcd(
                                digitCount: 5,
                                decimalDigitCount: 2,
                                value: saleCost)),
                      ),
                    ),
                  ),
                  const Text('DOLLARS'),
                  const Padding(padding: EdgeInsets.all(2.0)),
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(136, 140, 96, 1),
                        border: Border.all(
                          color: Colors.black,
                          width: 2.0,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: Observe<double?>(
                            state: brew.saleQuantityState,
                            builder: (context, saleQuantity) => Lcd(
                                digitCount: 5,
                                decimalDigitCount: 2,
                                value: saleQuantity)),
                      ),
                    ),
                  ),
                  const Text('LITERS'),
                  const Padding(padding: EdgeInsets.all(2.0)),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: <Widget>[
                        for (var i = 1; i <= 3; i++)
                          Expanded(
                            flex: 1,
                            child: PumpNozzle(number: i),
                          ),
                      ],
                    ),
                  ),
                ],
              )),
        ],
      ),
    );
  }

  PetrolPumpBrew _lookupBrew(BuildContext context) =>
      BrewProvider.of<PetrolPumpBrew>(context);

  void _showSettings(BuildContext context) {
    showDialog<void>(
        context: context,
        builder: (BuildContext context) => const PumpSettingsDialog());
  }
}

/// Dialog for changing pump prices and selecting pump logic.
class PumpSettingsDialog extends StatefulWidget {
  const PumpSettingsDialog({super.key});

  @override
  State<PumpSettingsDialog> createState() => _PumpSettingsDialogState();
}

class _PumpSettingsDialogState extends State<PumpSettingsDialog> {
  List<TextEditingController>? _priceControllers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize once; inherited widget lookup is not available in initState.
    if (_priceControllers != null) return;

    final brew = BrewProvider.of<PetrolPumpBrew>(context);

    _priceControllers = brew.priceSettingStates
        .map((state) =>
            TextEditingController(text: state.getValue().toString()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final brew = BrewProvider.of<PetrolPumpBrew>(context);

    return SimpleDialog(
      contentPadding: const EdgeInsets.all(8.0),
      title: const Text('Pump Settings'),
      children: <Widget>[
        for (var number = 1; number <= 3; number++)
          Row(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text('Price $number'),
              ),
              Expanded(
                child: TextField(
                    controller: _priceControllers![number - 1],
                    onChanged: (price) => brew.setPriceSetting(
                        number, double.parse(price)),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    )),
              ),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(4.0),
              child: Text('Pump logic'),
            ),
            Expanded(
              child: Observe<Pump?>(
                  state: brew.pumpLogicState,
                  builder: (context, pumpLogic) =>
                      DropdownButton<Pump?>(
                        value: pumpLogic,
                        onChanged: (pump) => brew.setPumpLogic(pump),
                        items: _pumps
                            .map<DropdownMenuItem<Pump?>>((pump) =>
                                DropdownMenuItem<Pump?>(
                                  value: pump,
                                  child: Text(pump?.toString() ?? ''),
                                ))
                            .toList(),
                      )),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_frappe/flutter_frappe.dart';
import 'package:flutter_petrol_pump/component/pump.dart';
import 'package:flutter_petrol_pump/widget/lcd.dart';
import 'package:flutter_petrol_pump/widget/numeric_pad.dart';
import 'package:frappe/frappe.dart';
import 'package:petrol_pump/petrol_pump.dart';
import 'package:provider/provider.dart';

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
  void initState() {
    super.initState();

    final bloc = _lookupBloc(context);

    // Start with the most complete pump logic.
    bloc.setPumpLogic(_pumps.last);

    _listenCanceler = bloc.beepStream.listen((_) {
      _beepPlayer.play(AssetSource('beep.wav'));
    }).append(bloc.deliveryState.listen((delivery) {
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
    })).append(bloc.saleCompleteStream.listen((sale) async {
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

      bloc.clearSale();
    }));
  }

  @override
  void dispose() {
    _listenCanceler?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = _lookupBloc(context);

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
                            state: bloc.presetState,
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
                      onNumericKey: bloc.pressKey,
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
                            state: bloc.saleCostState,
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
                            state: bloc.saleQuantityState,
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
                            child: PumpComponent(number: i),
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

  PetrolPumpBloc _lookupBloc(BuildContext context) =>
      Provider.of<PetrolPumpBloc>(context, listen: false);

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
  late List<TextEditingController> _priceControllers;

  @override
  void initState() {
    super.initState();

    final bloc = Provider.of<PetrolPumpBloc>(context, listen: false);

    _priceControllers = bloc.priceSettingStates
        .map((state) =>
            TextEditingController(text: state.getValue().toString()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = Provider.of<PetrolPumpBloc>(context, listen: false);

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
                    controller: _priceControllers[number - 1],
                    onChanged: (price) => bloc.setPriceSetting(
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
                  state: bloc.pumpLogicState,
                  builder: (context, pumpLogic) =>
                      DropdownButton<Pump?>(
                        value: pumpLogic,
                        onChanged: (pump) => bloc.setPumpLogic(pump),
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

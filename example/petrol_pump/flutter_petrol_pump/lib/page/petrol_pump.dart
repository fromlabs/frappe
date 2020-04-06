import 'package:audioplayers/audioplayers.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_petrol_pump/component/pump.dart';
import 'package:flutter_petrol_pump/util/value_state_builder.dart';
import 'package:flutter_petrol_pump/widget/lcd.dart';
import 'package:flutter_petrol_pump/widget/numeric_pad.dart';
import 'package:optional/optional.dart';
import 'package:frappe/frappe.dart';
import 'package:petrol_pump/petrol_pump.dart';
import 'package:provider/provider.dart';
import 'package:quiver/iterables.dart';

import 'package:audioplayers/audio_cache.dart';

final AudioPlayer _deliveryPlayer = AudioPlayer();
final AudioPlayer _beepPlayer = AudioPlayer();
final AudioCache _deliveryCache = AudioCache(fixedPlayer: _deliveryPlayer);
final AudioCache _beepCache = AudioCache(fixedPlayer: _beepPlayer);

final _pumps = <Optional<Pump>>[
  Optional.empty(),
  ...[
    LifecyclePump(),
    AccumulatePulsesPump(),
    ShowDollarsPump(),
    KeypadPump(),
    ClearSalePump(),
    PresetAmountPump(),
  ].map((pump) => Optional.of(pump)),
];

class PetrolPumpPage extends StatefulWidget {
  PetrolPumpPage({Key key}) : super(key: key);

  @override
  _PetrolPumpPageState createState() => _PetrolPumpPageState();
}

class _PetrolPumpPageState extends State<PetrolPumpPage> {
  ListenSubscription _listenCanceler;

  @override
  void initState() {
    super.initState();

    final petrolPumpBloc = _lookupPetrolPumpBloc(context);

    petrolPumpBloc.setPumpLogic(_pumps.last);

    _listenCanceler = petrolPumpBloc.beepStream.listen((_) {
      _beepCache.play('beep.wav');
    }).append(petrolPumpBloc.deliveryState.listen((delivery) {
      switch (delivery) {
        case Delivery.fast1:
        case Delivery.fast2:
        case Delivery.fast3:
          _deliveryCache.loop('fast.wav');
          break;
        case Delivery.slow1:
        case Delivery.slow2:
        case Delivery.slow3:
          _deliveryCache.loop('slow.wav');
          break;
        case Delivery.off:
          _deliveryPlayer.stop();
          break;
        default:
      }
    })).append(petrolPumpBloc.saleCompleteStream.listen((sale) async {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          title: Text('Sale complete'),
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
            FlatButton(
              child: Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );

      petrolPumpBloc.clearSale();
    }));
  }

  @override
  void dispose() {
    _listenCanceler.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petrolPumpBloc = _lookupPetrolPumpBloc(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Petrol Pump'),
        actions: <Widget>[
          // action button
          IconButton(
            icon: Icon(Icons.settings),
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
                        color: Color.fromRGBO(136, 140, 96, 1),
                        border: Border.all(
                          color: Colors.black,
                          width: 2.0,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: OptionalValueStateBuilder<double>(
                            state: petrolPumpBloc.presetState,
                            builder: (context, preset) => Lcd(
                                digitCount: 5,
                                decimalDigitCount: 2,
                                value: preset)),
                      ),
                    ),
                  ),
                  Text('PRESET'),
                  Padding(
                    padding: const EdgeInsets.all(6.0),
                  ),
                  Expanded(
                    flex: 3,
                    child: NumericPad(
                      onNumericKey: petrolPumpBloc.pressKey,
                    ),
                  ),
                ],
              )),
          Expanded(
              flex: 3,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(2.0),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(136, 140, 96, 1),
                        border: Border.all(
                          color: Colors.black,
                          width: 2.0,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: OptionalValueStateBuilder<double>(
                            state: petrolPumpBloc.saleCostState,
                            builder: (context, saleCost) => Lcd(
                                digitCount: 5,
                                decimalDigitCount: 2,
                                value: saleCost)),
                      ),
                    ),
                  ),
                  Text('DOLLARS'),
                  Padding(
                    padding: const EdgeInsets.all(2.0),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(136, 140, 96, 1),
                        border: Border.all(
                          color: Colors.black,
                          width: 2.0,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: OptionalValueStateBuilder<double>(
                            state: petrolPumpBloc.saleQuantityState,
                            builder: (context, saleQuantity) => Lcd(
                                digitCount: 5,
                                decimalDigitCount: 2,
                                value: saleQuantity)),
                      ),
                    ),
                  ),
                  Text('LITERS'),
                  Padding(
                    padding: const EdgeInsets.all(2.0),
                  ),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: <Widget>[
                        for (final i in range(1, 4))
                          Expanded(
                            flex: 1,
                            child: PumpComponent(
                              number: i,
                            ),
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

  PetrolPumpBloc _lookupPetrolPumpBloc(BuildContext context) =>
      Provider.of<PetrolPumpBloc>(context, listen: false);

  void _showSettings(BuildContext context) {
    showDialog<void>(
        context: context,
        builder: (BuildContext context) => PumpSettingsDialog());
  }
}

class PumpSettingsDialog extends StatefulWidget {
  PumpSettingsDialog({Key key}) : super(key: key);

  Pump_SettingStatesDialog createState() => Pump_SettingStatesDialog();
}

class Pump_SettingStatesDialog extends State<PumpSettingsDialog> {
  BuiltList<TextEditingController> _priceControllers;

  @override
  void initState() {
    super.initState();

    final petrolPumpBloc = Provider.of<PetrolPumpBloc>(context, listen: false);

    _priceControllers = BuiltList.of(petrolPumpBloc.priceSettingStates.map(
        (state) => TextEditingController(text: state.getValue.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final petrolPumpBloc = Provider.of<PetrolPumpBloc>(context, listen: false);

    return SimpleDialog(
      contentPadding: const EdgeInsets.all(8.0),
      title: const Text('Pump Settings'),
      children: <Widget>[
        for (final number in range(1, 4))
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
                    onChanged: (price) => petrolPumpBloc.setPriceSetting(
                        number, double.parse(price)),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    )),
              )
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text('Pump logic'),
            ),
            Expanded(
              child: OptionalValueStateBuilder<Pump>(
                  state: petrolPumpBloc.pumpLogicState,
                  builder: (context, pumpLogic) =>
                      DropdownButton<Optional<Pump>>(
                        value: pumpLogic,
                        onChanged: petrolPumpBloc.setPumpLogic,
                        items: _pumps
                            .map<DropdownMenuItem<Optional<Pump>>>((pump) =>
                                DropdownMenuItem<Optional<Pump>>(
                                  value: pump,
                                  child: Text(pump
                                      .map<String>((pump) => pump.toString())
                                      .orElse('')),
                                ))
                            .toList(),
                      )),
            )
          ],
        ),
      ],
    );
  }
}

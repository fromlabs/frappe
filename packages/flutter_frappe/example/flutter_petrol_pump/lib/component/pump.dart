import 'package:flutter/material.dart';
import 'package:flutter_frappe/flutter_frappe.dart';
import 'package:flutter_petrol_pump/widget/lcd.dart';
import 'package:frappe/frappe.dart';
import 'package:petrol_pump/petrol_pump.dart';
import 'package:provider/provider.dart';

/// A single fuel pump nozzle with animated lift and price LCD.
class PumpComponent extends StatefulWidget {
  const PumpComponent({
    super.key,
    required this.number,
  });

  final int number;

  @override
  State<PumpComponent> createState() => _PumpComponentState();
}

class _PumpComponentState extends State<PumpComponent>
    with SingleTickerProviderStateMixin {
  late Animation<double> _animation;
  late AnimationController _animationController;
  late ListenSubscription _listenCanceler;

  @override
  void initState() {
    super.initState();

    final petrolPumpBloc = _lookupBloc(context);

    _animationController = AnimationController(
        duration: const Duration(milliseconds: 100), vsync: this);

    _animation =
        Tween<double>(begin: 0.7, end: 1.0).animate(_animationController)
          ..addListener(() {
            setState(() {});
          });

    // Animate the nozzle up/down based on its toggle state.
    _listenCanceler =
        petrolPumpBloc.nozzleStates[widget.number - 1].listen((nozzle) {
      if (nozzle == UpDown.up) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _listenCanceler.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petrolPumpBloc = _lookupBloc(context);

    return Column(
      children: <Widget>[
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
                  state: petrolPumpBloc.priceStates[widget.number - 1],
                  builder: (context, price) => Lcd(
                        digitCount: 4,
                        decimalDigitCount: 3,
                        value: price,
                      )),
            ),
          ),
        ),
        Text('FUEL ${widget.number}'),
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              InkWell(
                onTap: () => petrolPumpBloc.toggleNozzle(widget.number),
                child: ClipRect(
                    child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _animation.value,
                  child: Image(
                      alignment: Alignment.bottomCenter,
                      fit: BoxFit.fitHeight,
                      width: 90,
                      image:
                          AssetImage('assets/nozzle${widget.number}.png')),
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }

  PetrolPumpBloc _lookupBloc(BuildContext context) =>
      Provider.of<PetrolPumpBloc>(context, listen: false);
}

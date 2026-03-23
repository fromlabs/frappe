import 'package:flutter/material.dart';
import 'package:flutter_brew/flutter_brew.dart';
import 'package:frappe/frappe.dart';
import 'package:petrol_pump_brew/petrol_pump_brew.dart';

import '../widget/lcd.dart';

/// A single fuel pump nozzle with animated lift and price LCD.
class PumpNozzle extends StatefulWidget {
  const PumpNozzle({
    super.key,
    required this.number,
  });

  final int number;

  @override
  State<PumpNozzle> createState() => _PumpNozzleState();
}

class _PumpNozzleState extends State<PumpNozzle>
    with SingleTickerProviderStateMixin {
  late Animation<double> _animation;
  late AnimationController _animationController;
  late ListenSubscription _listenCanceler;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
        duration: const Duration(milliseconds: 100), vsync: this);

    _animation =
        Tween<double>(begin: 0.7, end: 1.0).animate(_animationController)
          ..addListener(() {
            setState(() {});
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only subscribe once; inherited widget lookup is not available in initState.
    if (_initialized) return;
    _initialized = true;

    final brew = BrewProvider.of<PetrolPumpBrew>(context);

    // Animate the nozzle up/down based on its toggle state.
    _listenCanceler =
        brew.nozzleStates[widget.number - 1].listen((nozzle) {
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
    final brew = BrewProvider.of<PetrolPumpBrew>(context);

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
                  state: brew.priceStates[widget.number - 1],
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
                onTap: () => brew.toggleNozzle(widget.number),
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
}

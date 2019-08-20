import 'package:flutter/material.dart';
import 'package:petrol_pump/petrol_pump.dart';
import 'package:quiver/iterables.dart';

typedef NumericKeyCallback = void Function(NumericKey);

class NumericPad extends StatelessWidget {
  const NumericPad({
    Key key,
    @required this.onNumericKey,
  }) : super(key: key);

  final NumericKeyCallback onNumericKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Container(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (final x in range(3))
              Column(
                children: <Widget>[
                  for (final y in range(4))
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: _isDrawButton(x, y)
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.0,
                                      style: BorderStyle.solid,
                                    ),
                                    borderRadius: BorderRadius.circular(5.0),
                                  ),
                                  child: _drawButton(x, y),
                                )
                              : Container(),
                        ),
                      ),
                    )
                ],
              ),
          ],
        ),
      ),
    );
  }

  bool _isDrawButton(int x, int y) => !(x == 0 && y == 3);

  Widget _drawButton(int x, int y) {
    final position = 1 + x + 3 * y;

    NumericKey numericKey;
    String label;
    switch (position) {
      case 1:
        label = '1';
        numericKey = NumericKey.one;
        break;
      case 2:
        label = '2';
        numericKey = NumericKey.two;
        break;
      case 3:
        label = '3';
        numericKey = NumericKey.three;
        break;
      case 4:
        label = '4';
        numericKey = NumericKey.four;
        break;
      case 5:
        label = '5';
        numericKey = NumericKey.five;
        break;
      case 6:
        label = '6';
        numericKey = NumericKey.six;
        break;
      case 7:
        label = '7';
        numericKey = NumericKey.seven;
        break;
      case 8:
        label = '8';
        numericKey = NumericKey.eight;
        break;
      case 9:
        label = '9';
        numericKey = NumericKey.nine;
        break;
      case 10:
        break;
      case 11:
        label = '0';
        numericKey = NumericKey.zero;
        break;
      case 12:
        label = 'C';
        numericKey = NumericKey.clear;
        break;
    }

    return MaterialButton(
      padding: const EdgeInsets.all(4.0),
      child: Text(
        label,
        textAlign: TextAlign.center,
      ),
      onPressed: onNumericKey != null ? () => onNumericKey(numericKey) : null,
    );
  }
}

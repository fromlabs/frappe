import 'package:flutter/material.dart';
import 'package:petrol_pump_brew/petrol_pump_brew.dart';

typedef NumericKeyCallback = void Function(NumericKey);

/// A 3x4 numeric keypad widget (1-9, 0, C).
class NumericPad extends StatelessWidget {
  const NumericPad({
    super.key,
    required this.onNumericKey,
  });

  final NumericKeyCallback onNumericKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (var x = 0; x < 3; x++)
            Column(
              children: <Widget>[
                for (var y = 0; y < 4; y++)
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
                  ),
              ],
            ),
        ],
      ),
    );
  }

  bool _isDrawButton(int x, int y) => !(x == 0 && y == 3);

  Widget _drawButton(int x, int y) {
    final position = 1 + x + 3 * y;

    final (label, numericKey) = switch (position) {
      1 => ('1', NumericKey.one),
      2 => ('2', NumericKey.two),
      3 => ('3', NumericKey.three),
      4 => ('4', NumericKey.four),
      5 => ('5', NumericKey.five),
      6 => ('6', NumericKey.six),
      7 => ('7', NumericKey.seven),
      8 => ('8', NumericKey.eight),
      9 => ('9', NumericKey.nine),
      11 => ('0', NumericKey.zero),
      12 => ('C', NumericKey.clear),
      _ => ('', null),
    };

    return MaterialButton(
      padding: const EdgeInsets.all(4.0),
      onPressed: numericKey != null ? () => onNumericKey(numericKey) : null,
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:optional/optional.dart';
import 'package:quiver/iterables.dart';

const _horizontalSteps = 18;
const _verticalSteps = 24;

class Lcd extends StatelessWidget {
  Lcd({
    this.value = const Optional.empty(),
    this.digitCount = 5,
    this.decimalDigitCount = 2,
    Key key,
  }) : super(key: key) {
    final formatted = value
        .map<String>((value) =>
            (value * (pow(10, decimalDigitCount))).toInt().toString())
        .orElse('')
        .padLeft(decimalDigitCount + 1, '0')
        .padLeft(digitCount, ' ');

    if (formatted.length > digitCount) {
      for (final _ in range(digitCount)) {
        _digitMasks.add(8);
      }
    } else {
      final decimalIndex = digitCount - decimalDigitCount - 1;

      for (final i in range(digitCount)) {
        final digitString = formatted[i];

        int digitMask;
        if (digitString == ' ') {
          digitMask = 0;
        } else {
          final digit = int.parse(digitString);

          digitMask = _fromDigitToMask(digit);

          if (i == decimalIndex) {
            digitMask |= 128;
          }
        }

        _digitMasks.add(digitMask);
      }
    }
  }

  final Optional<num> value;
  final int digitCount;
  final int decimalDigitCount;

  final List<int> _digitMasks = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          for (final mask in _digitMasks)
            AspectRatio(
              aspectRatio: 0.5,
              child: LcdDigit(
                segmentMask: mask,
              ),
            ),
        ],
      ),
    );
  }
}

int _fromDigitToMask(int digit) {
  switch (digit) {
    case 0:
      return 1 + 2 + 4 + 16 + 32 + 64;
    case 1:
      return 4 + 32;
    case 2:
      return 1 + 4 + 8 + 16 + 64;
    case 3:
      return 1 + 4 + 8 + 32 + 64;
    case 4:
      return 2 + 4 + 8 + 32;
    case 5:
      return 1 + 2 + 8 + 32 + 64;
    case 6:
      return 1 + 2 + 8 + 16 + 32 + 64;
    case 7:
      return 1 + 4 + 32;
    case 8:
      return 1 + 2 + 4 + 8 + 16 + 32 + 64;
    case 9:
      return 1 + 2 + 4 + 8 + 32;
    default:
      return 8;
  }
}

class LcdDigit extends StatelessWidget {
  const LcdDigit({this.segmentMask = 0, Key key}) : super(key: key);

  final int segmentMask;

  @override
  Widget build(BuildContext context) => CustomPaint(
        child: Container(
            //color: Color.fromRGBO(136, 140, 96, 1),
            ),
        foregroundPainter: _LcdDigitPainter(segmentMask),
      );
}

class _LcdDigitPainter extends CustomPainter {
  _LcdDigitPainter(this.segmentMask);

  final int segmentMask;

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..strokeWidth = 0.5
      ..isAntiAlias = true;

    final stepWidth = size.width / _horizontalSteps;
    final stepHeight = size.height / _verticalSteps;

    var path = Path();

    // segment 1
    if (_isVisibleSegment(1)) {
      _drawHorizontalSegment(
        x: 5,
        y: 2,
        path: path,
        stepWidth: stepWidth,
        stepHeight: stepHeight,
      );
    }

    // segment 2
    if (_isVisibleSegment(2)) {
      _drawVerticalSegment(
        x: 4,
        y: 3,
        path: path,
        stepWidth: stepWidth,
        stepHeight: stepHeight,
      );
    }

    // segment 3
    if (_isVisibleSegment(3)) {
      _drawVerticalSegment(
        x: 14,
        y: 3,
        path: path,
        stepWidth: stepWidth,
        stepHeight: stepHeight,
      );
    }

    // segment 4
    if (_isVisibleSegment(4)) {
      _drawHorizontalSegment(
        x: 4,
        y: 12,
        path: path,
        stepWidth: stepWidth,
        stepHeight: stepHeight,
      );
    }

    // segment 5
    if (_isVisibleSegment(5)) {
      _drawVerticalSegment(
        x: 3,
        y: 13,
        path: path,
        stepWidth: stepWidth,
        stepHeight: stepHeight,
      );
    }

    // segment 6
    if (_isVisibleSegment(6)) {
      _drawVerticalSegment(
        x: 13,
        y: 13,
        path: path,
        stepWidth: stepWidth,
        stepHeight: stepHeight,
      );
    }

    // segment 7
    if (_isVisibleSegment(7)) {
      _drawHorizontalSegment(
        x: 3,
        y: 22,
        path: path,
        stepWidth: stepWidth,
        stepHeight: stepHeight,
      );
    }

    // segment 8
    if (_isVisibleSegment(8)) {
      _drawPointSegment(
        x: 16,
        y: 21,
        path: path,
        stepWidth: stepWidth,
        stepHeight: stepHeight,
      );
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LcdDigitPainter oldDelegate) =>
      oldDelegate.segmentMask != segmentMask;

  bool _isVisibleSegment(int segment) =>
      segmentMask & (1 << (segment - 1)) != 0;

  void _drawHorizontalSegment(
      {int x, int y, Path path, double stepWidth, double stepHeight}) {
    path
      ..moveTo(x * stepWidth, y * stepHeight)
      ..relativeLineTo(1 * stepWidth, -1 * stepHeight)
      ..relativeLineTo(6 * stepWidth, 0 * stepHeight)
      ..relativeLineTo(1 * stepWidth, 1 * stepHeight)
      ..relativeLineTo(-1 * stepWidth, 1 * stepHeight)
      ..relativeLineTo(-6 * stepWidth, 0 * stepHeight);
  }

  void _drawVerticalSegment(
      {int x, int y, Path path, double stepWidth, double stepHeight}) {
    path
      ..moveTo(x * stepWidth, y * stepHeight)
      ..relativeLineTo(1 * stepWidth, 1 * stepHeight)
      ..relativeLineTo(-1 * stepWidth, 6 * stepHeight)
      ..relativeLineTo(-1 * stepWidth, 1 * stepHeight)
      ..relativeLineTo(-1 * stepWidth, -1 * stepHeight)
      ..relativeLineTo(1 * stepWidth, -6 * stepHeight);
  }

  void _drawPointSegment(
      {int x, int y, Path path, double stepWidth, double stepHeight}) {
    path
      ..moveTo(x * stepWidth, y * stepHeight)
      ..relativeLineTo(1 * stepWidth, 1 * stepHeight)
      ..relativeLineTo(-1 * stepWidth, 1 * stepHeight)
      ..relativeLineTo(-1 * stepWidth, -1 * stepHeight)
      ..relativeLineTo(1 * stepWidth, -1 * stepHeight);
  }
}

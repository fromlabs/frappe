import 'dart:math';

import 'package:flutter/material.dart';

const _horizontalSteps = 18;
const _verticalSteps = 24;

/// A seven-segment LCD display widget.
class Lcd extends StatelessWidget {
  Lcd({
    this.value,
    this.digitCount = 5,
    this.decimalDigitCount = 2,
    super.key,
  }) {
    final formatted = value != null
        ? (value! * (pow(10, decimalDigitCount))).toInt().toString()
        : '';
    final padded = formatted
        .padLeft(decimalDigitCount + 1, '0')
        .padLeft(digitCount, ' ');

    if (padded.length > digitCount) {
      for (var i = 0; i < digitCount; i++) {
        _digitMasks.add(8);
      }
    } else {
      final decimalIndex = digitCount - decimalDigitCount - 1;

      for (var i = 0; i < digitCount; i++) {
        final digitString = padded[i];

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

  final num? value;
  final int digitCount;
  final int decimalDigitCount;

  final List<int> _digitMasks = [];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        for (final mask in _digitMasks)
          AspectRatio(
            aspectRatio: 0.5,
            child: LcdDigit(segmentMask: mask),
          ),
      ],
    );
  }
}

int _fromDigitToMask(int digit) => switch (digit) {
      0 => 1 + 2 + 4 + 16 + 32 + 64,
      1 => 4 + 32,
      2 => 1 + 4 + 8 + 16 + 64,
      3 => 1 + 4 + 8 + 32 + 64,
      4 => 2 + 4 + 8 + 32,
      5 => 1 + 2 + 8 + 32 + 64,
      6 => 1 + 2 + 8 + 16 + 32 + 64,
      7 => 1 + 4 + 32,
      8 => 1 + 2 + 4 + 8 + 16 + 32 + 64,
      9 => 1 + 2 + 4 + 8 + 32,
      _ => 8,
    };

/// A single seven-segment LCD digit painted via [CustomPaint].
class LcdDigit extends StatelessWidget {
  const LcdDigit({this.segmentMask = 0, super.key});

  final int segmentMask;

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _LcdDigitPainter(segmentMask),
        child: Container(),
      );
}

class _LcdDigitPainter extends CustomPainter {
  _LcdDigitPainter(this.segmentMask);

  final int segmentMask;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..strokeWidth = 0.5
      ..isAntiAlias = true;

    final stepWidth = size.width / _horizontalSteps;
    final stepHeight = size.height / _verticalSteps;

    final path = Path();

    if (_isVisible(1)) {
      _drawHorizontal(5, 2, path, stepWidth, stepHeight);
    }
    if (_isVisible(2)) {
      _drawVertical(4, 3, path, stepWidth, stepHeight);
    }
    if (_isVisible(3)) {
      _drawVertical(14, 3, path, stepWidth, stepHeight);
    }
    if (_isVisible(4)) {
      _drawHorizontal(4, 12, path, stepWidth, stepHeight);
    }
    if (_isVisible(5)) {
      _drawVertical(3, 13, path, stepWidth, stepHeight);
    }
    if (_isVisible(6)) {
      _drawVertical(13, 13, path, stepWidth, stepHeight);
    }
    if (_isVisible(7)) {
      _drawHorizontal(3, 22, path, stepWidth, stepHeight);
    }
    if (_isVisible(8)) {
      _drawPoint(16, 21, path, stepWidth, stepHeight);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LcdDigitPainter oldDelegate) =>
      oldDelegate.segmentMask != segmentMask;

  bool _isVisible(int segment) => segmentMask & (1 << (segment - 1)) != 0;

  void _drawHorizontal(
      int x, int y, Path path, double stepWidth, double stepHeight) {
    path
      ..moveTo(x * stepWidth, y * stepHeight)
      ..relativeLineTo(1 * stepWidth, -1 * stepHeight)
      ..relativeLineTo(6 * stepWidth, 0)
      ..relativeLineTo(1 * stepWidth, 1 * stepHeight)
      ..relativeLineTo(-1 * stepWidth, 1 * stepHeight)
      ..relativeLineTo(-6 * stepWidth, 0);
  }

  void _drawVertical(
      int x, int y, Path path, double stepWidth, double stepHeight) {
    path
      ..moveTo(x * stepWidth, y * stepHeight)
      ..relativeLineTo(1 * stepWidth, 1 * stepHeight)
      ..relativeLineTo(-1 * stepWidth, 6 * stepHeight)
      ..relativeLineTo(-1 * stepWidth, 1 * stepHeight)
      ..relativeLineTo(-1 * stepWidth, -1 * stepHeight)
      ..relativeLineTo(1 * stepWidth, -6 * stepHeight);
  }

  void _drawPoint(
      int x, int y, Path path, double stepWidth, double stepHeight) {
    path
      ..moveTo(x * stepWidth, y * stepHeight)
      ..relativeLineTo(1 * stepWidth, 1 * stepHeight)
      ..relativeLineTo(-1 * stepWidth, 1 * stepHeight)
      ..relativeLineTo(-1 * stepWidth, -1 * stepHeight)
      ..relativeLineTo(1 * stepWidth, -1 * stepHeight);
  }
}

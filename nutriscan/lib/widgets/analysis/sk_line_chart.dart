import 'package:flutter/material.dart';

/// Seven-day line chart from the Slow Kitchen handoff: solid ink line for
/// this week, dashed faint line for the one before, a dot and printed value
/// per day, and "highest"/"lightest" annotations.
///
/// Geometry is the handoff's 322×200 viewBox, scaled horizontally to the
/// available width; the 200pt height is kept as-is.
class SkLineChart extends StatelessWidget {
  final List<double> values;
  final List<double> previousValues;
  final List<String> labels;
  final String Function(double) format;
  final Color lineColor;
  final Color dotColor;
  final Color gridColor;
  final Color faintColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final TextStyle noteStyle;

  const SkLineChart({
    super.key,
    required this.values,
    required this.previousValues,
    required this.labels,
    required this.format,
    required this.lineColor,
    required this.dotColor,
    required this.gridColor,
    required this.faintColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.noteStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: CustomPaint(painter: _SkLinePainter(this)),
    );
  }
}

class _SkLinePainter extends CustomPainter {
  final SkLineChart c;
  const _SkLinePainter(this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final n = c.values.length;
    if (n < 2) return;

    final all = [...c.values, ...c.previousValues];
    final maxV = all.reduce((a, b) => a > b ? a : b);
    final minV = all.reduce((a, b) => a < b ? a : b);
    final lo = minV * 0.88;
    final hi = maxV * 1.06;
    final span = (hi - lo).abs() < 1e-6 ? 1.0 : hi - lo;

    // Handoff x positions live in a 322-wide viewBox with 6pt inset.
    double px(int i) => (6 + (i * 310) / (n - 1)) / 322 * size.width;
    double py(double v) => 168 - ((v - lo) / span) * 152;

    final grid = Paint()
      ..color = c.gridColor
      ..strokeWidth = 1;
    for (var k = 0; k < 4; k++) {
      final y = 16 + k * 50.0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Previous week — dashed.
    if (c.previousValues.length == n) {
      final dashed = Paint()
        ..color = c.faintColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < n - 1; i++) {
        _drawDashed(
          canvas,
          Offset(px(i), py(c.previousValues[i])),
          Offset(px(i + 1), py(c.previousValues[i + 1])),
          dashed,
        );
      }
    }

    final line = Paint()
      ..color = c.lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(px(0), py(c.values[0]));
    for (var i = 1; i < n; i++) {
      path.lineTo(px(i), py(c.values[i]));
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = c.dotColor;
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(px(i), py(c.values[i])), 4.5, dot);
      _text(canvas, c.format(c.values[i]), c.valueStyle,
          Offset(px(i), py(c.values[i]) - 12));
      if (i < c.labels.length) {
        _text(canvas, c.labels[i], c.labelStyle, Offset(px(i), 192));
      }
    }

    // highest / lightest annotations
    var maxI = 0, minI = 0;
    for (var i = 1; i < n; i++) {
      if (c.values[i] > c.values[maxI]) maxI = i;
      if (c.values[i] < c.values[minI]) minI = i;
    }
    if (maxI != minI) {
      _text(canvas, 'highest', c.noteStyle,
          Offset(px(maxI), py(c.values[maxI]) - 27));
      _text(canvas, 'lightest', c.noteStyle,
          Offset(px(minI), py(c.values[minI]) + 24));
    }
  }

  void _drawDashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 5.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var t = 0.0;
    while (t < total) {
      final end = (t + dash).clamp(0.0, total);
      canvas.drawLine(a + dir * t, a + dir * end, paint);
      t = end + gap;
    }
  }

  /// Draws [text] horizontally centred on [center], clamped inside the canvas.
  void _text(Canvas canvas, String text, TextStyle style, Offset center) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SkLinePainter old) =>
      old.c.values != c.values ||
      old.c.previousValues != c.previousValues ||
      old.c.lineColor != c.lineColor;
}

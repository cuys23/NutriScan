import 'package:flutter/material.dart';

/// Torn-paper zigzag rule used between history day groups.
/// Mirrors the twin 45° gradients in the Slow Kitchen handoff (9px period,
/// 7px band).
class SkTornDivider extends StatelessWidget {
  final Color color;

  const SkTornDivider({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 7,
      width: double.infinity,
      child: CustomPaint(painter: _TornPainter(color)),
    );
  }
}

class _TornPainter extends CustomPainter {
  final Color color;
  const _TornPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const period = 9.0;
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x < size.width; x += period) {
      path.lineTo(x + period / 2, 0);
      path.lineTo(x + period, size.height);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TornPainter old) => old.color != color;
}

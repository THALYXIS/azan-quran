import 'dart:math' as math;

import 'package:flutter/material.dart';

/// أيقونة سبحة (خرز في دايرة + ذيل)، بتاخد لون وحجم الأيقونة من الـ Theme
/// فتشتغل جوه NavigationDestination زي أي Icon عادية.
class TasbihIcon extends StatelessWidget {
  const TasbihIcon({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    return CustomPaint(
      size: Size.square(s),
      painter: _BeadsPainter(theme.color ?? Colors.black),
    );
  }
}

class _BeadsPainter extends CustomPainter {
  _BeadsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;

    // حلقة الخرز
    final center = Offset(w * 0.5, h * 0.35);
    final ringR = w * 0.27;
    const beads = 10;
    for (var i = 0; i < beads; i++) {
      final a = 2 * math.pi * i / beads - math.pi / 2;
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * ringR,
        w * 0.07,
        paint,
      );
    }

    // الذيل (خرزتين تحت الحلقة)
    canvas.drawCircle(Offset(w * 0.5, h * 0.77), w * 0.07, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.91), w * 0.075, paint);
  }

  @override
  bool shouldRepaint(covariant _BeadsPainter old) => old.color != color;
}
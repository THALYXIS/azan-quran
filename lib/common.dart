import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const Color kPaper = Color(0xFFF7F5EC);
const Color kCard = Color(0xFFFFFEFA);
const Color kInk = Color(0xFF1B2A22);
const Color kGold = Color(0xFFE2C275);

/// يحوّل الأرقام الإنجليزية إلى الهندية (٠١٢٣...)
String arDigits(Object? value) {
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  var s = '$value';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(western[i], eastern[i]);
  }
  return s;
}

/// مثال: ٣:١٥ م
String formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '${arDigits(h)}:${arDigits(m)} ${t.hour < 12 ? 'ص' : 'م'}';
}

/// بطاقة بحدود خفيفة تُستخدم في كل الشاشات
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: kCard,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: child,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  خلفية التطبيق: تدرّج هادي + زخرفة إسلامية (نجمة ثمانية) خفيفة جدًا
// ═════════════════════════════════════════════════════════════

class IslamicBackground extends StatelessWidget {
  const IslamicBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(
        painter: _PatternPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter();

  static const double _tile = 68;
  static const double _r = 21; // نصف قطر النجمة

  Path _star(Offset c) {
    final p = Path();
    for (final start in [math.pi / 4, 0.0]) {
      for (var k = 0; k < 4; k++) {
        final a = start + k * math.pi / 2;
        final pt = c + Offset(math.cos(a), math.sin(a)) * _r;
        k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      p.close();
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // تدرّج: كريمي دافي من فوق ← أخضر باهت من تحت
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const [Color(0xFFFAF7EC), Color(0xFFF3F1E2), Color(0xFFE6EEDF)],
          [0.0, 0.5, 1.0],
        ),
    );

    // وهج ذهبي خفيف من فوق اليمين، وأخضر خفيف من تحت الشمال
    final g1 = Offset(size.width * 0.9, size.height * 0.02);
    canvas.drawCircle(
      g1,
      size.width * 0.9,
      Paint()
        ..shader = ui.Gradient.radial(g1, size.width * 0.9, [
          const Color(0xFFE2C275).withValues(alpha: 0.22),
          const Color(0x00E2C275),
        ]),
    );
    final g2 = Offset(size.width * 0.05, size.height * 0.98);
    canvas.drawCircle(
      g2,
      size.width * 1.0,
      Paint()
        ..shader = ui.Gradient.radial(g2, size.width * 1.0, [
          const Color(0xFF14653D).withValues(alpha: 0.13),
          const Color(0x0014653D),
        ]),
    );

    // الزخرفة
    final line = Paint()
      ..color = const Color(0xFF0F4A2C).withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;
    final dot = Paint()
      ..color = const Color(0xFFB8923A).withValues(alpha: 0.20)
      ..isAntiAlias = true;

    final cols = (size.width / _tile).ceil() + 1;
    final rows = (size.height / _tile).ceil() + 1;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final center = Offset(c * _tile + _tile / 2, r * _tile + _tile / 2);
        canvas.drawPath(_star(center), line);
        canvas.drawCircle(center, 1.6, dot);
        // نقطة صغيرة بين النجوم
        canvas.drawCircle(center + const Offset(_tile / 2, _tile / 2), 1.3, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// كل صفحة بتترسم فوق الخلفية دي (الـ Scaffold شفّاف)، فتبان ثابتة مع الانتقال بين الصفحات
class BackgroundTransitions extends PageTransitionsBuilder {
  const BackgroundTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return const ZoomPageTransitionsBuilder().buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      Stack(
        fit: StackFit.expand,
        children: [const IslamicBackground(), child],
      ),
    );
  }
}
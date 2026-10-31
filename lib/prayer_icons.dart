import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// أيقونات المواقيت: مرسومة بالكود وملوّنة بألوان حقيقية
/// (شمس ذهبية، غروب برتقالي، قمر ونجوم، سحابة...) بدل الأيقونات الأحادية اللون.
enum PrayerIconKind { fajr, sunrise, dhuhr, asr, maghrib, isha }

class PrayerIcon extends StatelessWidget {
  const PrayerIcon(this.kind, {super.key, this.size = 30, this.muted = false});

  final PrayerIconKind kind;
  final double size;

  /// للأوقات اللي مش صلاة (زي الشروق): أخفّ شوية
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: muted ? 0.6 : 1,
      child: CustomPaint(
        size: Size.square(size),
        painter: _PrayerIconPainter(kind),
      ),
    );
  }
}

class _PrayerIconPainter extends CustomPainter {
  _PrayerIconPainter(this.kind);

  final PrayerIconKind kind;

  static const Color _moon = Color(0xFF4A5BB8);
  static const Color _star = Color(0xFFF5B400);

  @override
  void paint(Canvas canvas, Size size) {
    // بنرسم على مساحة ١٠٠×١٠٠ وبنكبّرها/نصغّرها حسب الحجم
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    switch (kind) {
      case PrayerIconKind.fajr:
        _fajr(canvas);
      case PrayerIconKind.sunrise:
        _horizonSun(
          canvas,
          horizonY: 66,
          inner: const Color(0xFFFFE27A),
          outer: const Color(0xFFF59E0B),
          ray: const Color(0xFFF5B400),
          line: const Color(0xFF6B8F71),
          reflection: false,
        );
      case PrayerIconKind.dhuhr:
        _noon(canvas);
      case PrayerIconKind.asr:
        _afternoon(canvas);
      case PrayerIconKind.maghrib:
        _horizonSun(
          canvas,
          horizonY: 62,
          inner: const Color(0xFFFFA040),
          outer: const Color(0xFFE8590C),
          ray: const Color(0xFFEF7B2A),
          line: const Color(0xFFB4532A),
          reflection: true,
        );
      case PrayerIconKind.isha:
        _night(canvas);
    }
    canvas.restore();
  }

  // ───────── أدوات رسم ─────────

  Paint _fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  Paint _sunPaint(Offset c, double r, Color inner, Color outer) => Paint()
    ..isAntiAlias = true
    ..shader = ui.Gradient.radial(c, r, [inner, outer]);

  /// أشعة بين نصفي قطر معينين، على مدى زاوية معين
  void _rays(Canvas canvas, Offset c, double r1, double r2, List<double> angles,
      Paint p) {
    for (final a in angles) {
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * r1,
        c + Offset(math.cos(a), math.sin(a)) * r2,
        p,
      );
    }
  }

  List<double> _fullCircle(int n) =>
      [for (var i = 0; i < n; i++) 2 * math.pi * i / n];

  /// أشعة نص دايرة علوية (فوق الأفق)
  List<double> _upperHalf(int n) =>
      [for (var k = 1; k <= n; k++) math.pi + math.pi * k / (n + 1)];

  Path _crescent(Offset c, double r) {
    final full = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final cutter = Path()
      ..addOval(Rect.fromCircle(
        center: c + Offset(r * 0.5, -r * 0.35),
        radius: r * 0.82,
      ));
    return Path.combine(PathOperation.difference, full, cutter);
  }

  Path _sparkle(Offset c, double r) {
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
  }

  // ───────── الفجر: هلال + نجمة + بداية ضوء على الأفق ─────────

  void _fajr(Canvas canvas) {
    // توهّج الفجر على الأفق
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 0, 100, 80));
    const glow = Offset(50, 80);
    canvas.drawCircle(
      glow,
      15,
      _sunPaint(glow, 15, const Color(0xFFFFD180), const Color(0xFFFF8F3D)),
    );
    canvas.restore();
    canvas.drawLine(
        const Offset(14, 80), const Offset(86, 80), _stroke(const Color(0xFF6B8F71), 5));

    // الهلال والنجوم
    canvas.drawPath(_crescent(const Offset(38, 36), 24), _fill(_moon));
    canvas.drawPath(_sparkle(const Offset(72, 24), 9), _fill(_star));
    canvas.drawPath(_sparkle(const Offset(80, 50), 6), _fill(_star));
  }

  // ───────── الشروق / المغرب: نص شمس على الأفق ─────────

  void _horizonSun(
    Canvas canvas, {
    required double horizonY,
    required Color inner,
    required Color outer,
    required Color ray,
    required Color line,
    required bool reflection,
  }) {
    final c = Offset(50, horizonY);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, 100, horizonY));
    canvas.drawCircle(c, 20, _sunPaint(c, 20, inner, outer));
    canvas.restore();

    _rays(canvas, c, 27, 36, _upperHalf(5), _stroke(ray, 5));
    canvas.drawLine(
        Offset(10, horizonY), Offset(90, horizonY), _stroke(line, 4.5));

    if (reflection) {
      final r = _stroke(outer.withValues(alpha: 0.6), 4);
      canvas.drawLine(Offset(28, horizonY + 12), Offset(72, horizonY + 12), r);
      canvas.drawLine(Offset(38, horizonY + 22), Offset(62, horizonY + 22), r);
    }
  }

  // ───────── الظهر: شمس كاملة ─────────

  void _noon(Canvas canvas) {
    const c = Offset(50, 50);
    _rays(canvas, c, 28, 39, _fullCircle(8), _stroke(const Color(0xFFF5B400), 6));
    canvas.drawCircle(
      c,
      19,
      _sunPaint(c, 19, const Color(0xFFFFE27A), const Color(0xFFF59E0B)),
    );
  }

  // ───────── العصر: شمس بعد الزوال وسحابة ─────────

  void _afternoon(Canvas canvas) {
    const sun = Offset(66, 34);
    _rays(canvas, sun, 20, 28, _fullCircle(8), _stroke(const Color(0xFFF5B400), 5));
    canvas.drawCircle(
      sun,
      14,
      _sunPaint(sun, 14, const Color(0xFFFFE27A), const Color(0xFFF59E0B)),
    );

    var cloud = Path()
      ..addOval(Rect.fromCircle(center: const Offset(34, 66), radius: 13));
    for (final part in <Path>[
      Path()..addOval(Rect.fromCircle(center: const Offset(50, 58), radius: 17)),
      Path()..addOval(Rect.fromCircle(center: const Offset(68, 68), radius: 11)),
      Path()
        ..addRRect(RRect.fromLTRBR(22, 66, 80, 82, const Radius.circular(8))),
    ]) {
      cloud = Path.combine(PathOperation.union, cloud, part);
    }
    canvas.drawPath(cloud, _fill(const Color(0xFFF4F8FC)));
    canvas.drawPath(
      cloud,
      Paint()
        ..color = const Color(0xFF7FA3C7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  // ───────── العشاء: هلال كبير ونجوم ─────────

  void _night(Canvas canvas) {
    canvas.drawPath(_crescent(const Offset(42, 52), 31), _fill(_moon));
    canvas.drawPath(_sparkle(const Offset(74, 26), 10), _fill(_star));
    canvas.drawPath(_sparkle(const Offset(82, 56), 6), _fill(_star));
    canvas.drawPath(_sparkle(const Offset(66, 80), 5), _fill(_star));
  }

  @override
  bool shouldRepaint(covariant _PrayerIconPainter old) => old.kind != kind;
}

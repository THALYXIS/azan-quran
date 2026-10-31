import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ═════════════════════════════════════════════════════════════
//  حسابات الشمس والقمر (دقة كافية للرسم: فرق دقايق قليلة)
// ═════════════════════════════════════════════════════════════

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;
double _norm(double x) => x - 360 * (x / 360).floorToDouble();
double _jd(DateTime t) => t.toUtc().millisecondsSinceEpoch / 86400000.0 + 2440587.5;

class _Eq {
  const _Eq(this.ra, this.dec, this.lon);
  final double ra; // الصعود المستقيم (راديان)
  final double dec; // الميل (راديان)
  final double lon; // خط الطول الكسوفي (درجات)
}

_Eq _sunEq(double jd) {
  final n = jd - 2451545.0;
  final l = _norm(280.460 + 0.9856474 * n);
  final g = _rad(_norm(357.528 + 0.9856003 * n));
  final lam = _rad(l + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g));
  final eps = _rad(23.439 - 0.0000004 * n);
  final ra = math.atan2(math.cos(eps) * math.sin(lam), math.cos(lam));
  final dec = math.asin(math.sin(eps) * math.sin(lam));
  return _Eq(ra, dec, _norm(_deg(lam)));
}

_Eq _moonEq(double jd) {
  final d = jd - 2451543.5;
  final nodeN = _norm(125.1228 - 0.0529538083 * d);
  const incl = 5.1454;
  final w = _norm(318.0634 + 0.1643573223 * d);
  const a = 60.2666;
  const e = 0.054900;
  final mDeg = _norm(115.3654 + 13.0649929509 * d);
  final m = _rad(mDeg);

  var ecc = m + e * math.sin(m) * (1 + e * math.cos(m));
  for (var i = 0; i < 3; i++) {
    ecc = ecc - (ecc - e * math.sin(ecc) - m) / (1 - e * math.cos(ecc));
  }
  final xv = a * (math.cos(ecc) - e);
  final yv = a * math.sqrt(1 - e * e) * math.sin(ecc);
  final v = math.atan2(yv, xv);
  final r = math.sqrt(xv * xv + yv * yv);

  final nr = _rad(nodeN);
  final ir = _rad(incl);
  final vw = v + _rad(w);
  final xh = r * (math.cos(nr) * math.cos(vw) - math.sin(nr) * math.sin(vw) * math.cos(ir));
  final yh = r * (math.sin(nr) * math.cos(vw) + math.cos(nr) * math.sin(vw) * math.cos(ir));
  final zh = r * math.sin(vw) * math.sin(ir);
  var lon = _deg(math.atan2(yh, xh));
  var lat = _deg(math.atan2(zh, math.sqrt(xh * xh + yh * yh)));

  final ms = _norm(356.0470 + 0.9856002585 * d);
  final ws = 282.9404 + 4.70935e-5 * d;
  final lm = _norm(mDeg + w + nodeN);
  final ls = _norm(ms + ws);
  final dd = _rad(_norm(lm - ls));
  final f = _rad(_norm(lm - nodeN));
  final msr = _rad(ms);

  lon += -1.274 * math.sin(m - 2 * dd) +
      0.658 * math.sin(2 * dd) -
      0.186 * math.sin(msr) -
      0.059 * math.sin(2 * m - 2 * dd) -
      0.057 * math.sin(m - 2 * dd + msr) +
      0.053 * math.sin(m + 2 * dd) +
      0.046 * math.sin(2 * dd - msr) +
      0.041 * math.sin(m - msr) -
      0.035 * math.sin(dd) -
      0.031 * math.sin(m + msr) -
      0.015 * math.sin(2 * f - 2 * dd) +
      0.011 * math.sin(m - 4 * dd);
  lat += -0.173 * math.sin(f - 2 * dd) -
      0.055 * math.sin(m - f - 2 * dd) -
      0.046 * math.sin(m + f - 2 * dd) +
      0.033 * math.sin(f + 2 * dd) +
      0.017 * math.sin(2 * m + f);
  lon = _norm(lon);

  final eps = _rad(23.4393 - 3.563e-7 * d);
  final lr = _rad(lon);
  final br = _rad(lat);
  final x = math.cos(lr) * math.cos(br);
  final y = math.sin(lr) * math.cos(br);
  final z = math.sin(br);
  final ye = y * math.cos(eps) - z * math.sin(eps);
  final ze = y * math.sin(eps) + z * math.cos(eps);
  return _Eq(math.atan2(ye, x), math.atan2(ze, math.sqrt(x * x + ye * ye)), lon);
}

/// ارتفاع الجرم فوق الأفق بالدرجات
double _altitude(_Eq q, double lat, double lng, double jd) {
  final gmst = _norm(280.46061837 + 360.98564736629 * (jd - 2451545.0));
  final ha = _rad(_norm(gmst + lng)) - q.ra;
  final la = _rad(lat);
  return _deg(math.asin(
    math.sin(la) * math.sin(q.dec) + math.cos(la) * math.cos(q.dec) * math.cos(ha),
  ));
}

double _sunAlt(DateTime t, double lat, double lng) {
  final jd = _jd(t);
  return _altitude(_sunEq(jd), lat, lng, jd);
}

double _moonAlt(DateTime t, double lat, double lng) {
  final jd = _jd(t);
  return _altitude(_moonEq(jd), lat, lng, jd);
}

DateTime _bisect(double Function(DateTime) g, DateTime lo, DateTime hi) {
  var a = lo;
  var b = hi;
  for (var i = 0; i < 12; i++) {
    final mid = a.add(Duration(milliseconds: b.difference(a).inMilliseconds ~/ 2));
    if ((g(mid) > 0) == (g(a) > 0)) {
      a = mid;
    } else {
      b = mid;
    }
  }
  return a;
}


/// قوس ظهور الجرم (شروق، غروب):
/// لو الجرم فوق الأفق دلوقتي بيرجّع قوسه الحالي، ولو تحت الأفق بيرجّع قوسه الجاي.
/// null لو مفيش قوس (مناطق قطبية مثلًا).
(DateTime, DateTime)? _arc(
  double Function(DateTime) alt,
  double h0,
  DateTime now, {
  int forwardSteps = 200,
}) {
  double g(DateTime t) => alt(t) - h0;
  const step = Duration(minutes: 10);
  DateTime? rise;
  DateTime? set;

  if (g(now) > 0) {
    var t = now;
    for (var i = 0; i < 160; i++) {
      final prev = t.subtract(step);
      if (g(prev) <= 0) {
        rise = _bisect(g, prev, t);
        break;
      }
      t = prev;
    }
    t = now;
    for (var i = 0; i < 160; i++) {
      final next = t.add(step);
      if (g(next) <= 0) {
        set = _bisect(g, t, next);
        break;
      }
      t = next;
    }
  } else {
    var t = now;
    for (var i = 0; i < forwardSteps; i++) {
      final next = t.add(step);
      if (g(next) > 0) {
        rise = _bisect(g, t, next);
        t = next;
        break;
      }
      t = next;
    }
    if (rise != null) {
      for (var i = 0; i < 160; i++) {
        final next = t.add(step);
        if (g(next) <= 0) {
          set = _bisect(g, t, next);
          break;
        }
        t = next;
      }
    }
  }
  if (rise == null || set == null) return null;
  return (rise, set);
}

/// مكان الجرم في رحلته: ٠ = لحظة الشروق، ١ = لحظة الغروب، null = تحت الأفق
double? _fracOf((DateTime, DateTime)? arc, DateTime now) {
  if (arc == null) return null;
  final (rise, set) = arc;
  if (now.isBefore(rise) || now.isAfter(set)) return null;
  final total = set.difference(rise).inMilliseconds;
  if (total <= 0) return null;
  return now.difference(rise).inMilliseconds / total;
}

class SkyState {
  const SkyState({
    required this.sunArc,
    required this.moonArc,
    required this.moonElong,
    required this.waxing,
    required this.sunWest,
  });

  final (DateTime, DateTime)? sunArc; // قوس الشمس (الحالي أو الجاي)
  final (DateTime, DateTime)? moonArc; // قوس القمر (الحالي أو الجاي)
  final double moonElong; // زاوية الاستطالة (٠ محاق ← ١٨٠ بدر)
  final bool waxing; // هلال متزايد؟
  final bool sunWest; // الشمس في جهة الغروب (بعد الزوال)؟
}

SkyState computeSky(DateTime now, double lat, double lng) {
  final jd = _jd(now);
  final sun = _sunEq(jd);
  final moon = _moonEq(jd);
  final dd = _norm(moon.lon - sun.lon);
  final waxing = dd < 180;
  final later = now.add(const Duration(minutes: 1));
  return SkyState(
    sunArc: _arc((t) => _sunAlt(t, lat, lng), -0.833, now),
    moonArc: _arc((t) => _moonAlt(t, lat, lng), 0.125, now),
    moonElong: waxing ? dd : 360 - dd,
    waxing: lat >= 0 ? waxing : !waxing,
    sunWest: _sunAlt(later, lat, lng) < _sunAlt(now, lat, lng),
  );
}

// ═════════════════════════════════════════════════════════════
//  الويدجت: سماء حيّة حسب الوقت الحقيقي في مدينتك
// ═════════════════════════════════════════════════════════════

class SkyBackground extends StatefulWidget {
  const SkyBackground({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);
  Timer? _timer;
  late SkyState _sky;
  double _last = 0;

  @override
  void initState() {
    super.initState();
    _sky = computeSky(DateTime.now(), widget.lat, widget.lng);
    // حركة السحب والنجوم وموضع الشمس بتتحدّث ٣٠ مرة في الثانية
    _ticker = createTicker((d) {
      final s = d.inMicroseconds / 1e6;
      if (s - _last >= 1 / 30) {
        _last = s;
        _clock.value = s;
      }
    })
      ..start();
    // الأقواس (الشروق والغروب) بنعيد حسابها كل نص دقيقة
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _sky = computeSky(DateTime.now(), widget.lat, widget.lng));
  }

  @override
  void didUpdateWidget(covariant SkyBackground old) {
    super.didUpdateWidget(old);
    if (old.lat != widget.lat || old.lng != widget.lng) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SkyPainter(
          sky: _sky,
          lat: widget.lat,
          lng: widget.lng,
          clock: _clock,
        ),
        size: Size.infinite,
      ),
    );
  }
}

// ───────── ألوان السماء حسب ارتفاع الشمس (فوق / وسط / عند الأفق) ─────────

class _SkyStop {
  const _SkyStop(this.alt, this.top, this.mid, this.bottom);
  final double alt;
  final Color top;
  final Color mid;
  final Color bottom;
}

const List<_SkyStop> _stops = [
  _SkyStop(-18, Color(0xFF03060F), Color(0xFF0A1230), Color(0xFF111B40)), // ليل
  _SkyStop(-12, Color(0xFF0B1230), Color(0xFF1B2556), Color(0xFF2E3A73)), // غسق بحري
  _SkyStop(-6, Color(0xFF1E2F66), Color(0xFF5A5B9A), Color(0xFFF0906A)), // شفق
  _SkyStop(-1, Color(0xFF3B5BA0), Color(0xFFB58BAA), Color(0xFFFFB067)), // شروق / غروب
  _SkyStop(6, Color(0xFF3E7BC4), Color(0xFF86B4DE), Color(0xFFFFD29A)), // صباح / عصر
  _SkyStop(20, Color(0xFF2E7BD6), Color(0xFF63A9E8), Color(0xFFA9D6F5)), // نهار
  _SkyStop(45, Color(0xFF1F6FD0), Color(0xFF4F9DE6), Color(0xFF9ACFF4)), // ظهيرة
];

(Color, Color, Color) _skyColors(double alt) {
  if (alt <= _stops.first.alt) {
    final s = _stops.first;
    return (s.top, s.mid, s.bottom);
  }
  for (var i = 1; i < _stops.length; i++) {
    final a = _stops[i - 1];
    final b = _stops[i];
    if (alt <= b.alt) {
      final t = (alt - a.alt) / (b.alt - a.alt);
      return (
        Color.lerp(a.top, b.top, t)!,
        Color.lerp(a.mid, b.mid, t)!,
        Color.lerp(a.bottom, b.bottom, t)!,
      );
    }
  }
  final s = _stops.last;
  return (s.top, s.mid, s.bottom);
}

/// لون قرص الشمس: أحمر برتقالي عند الأفق ← أصفر ← أبيض مصفرّ في الظهيرة
Color _sunColor(double alt) {
  const stops = <(double, Color)>[
    (0.0, Color(0xFFFF4D1A)),
    (5.0, Color(0xFFFF8A2B)),
    (15.0, Color(0xFFFFC94D)),
    (35.0, Color(0xFFFFF0B3)),
  ];
  if (alt <= stops.first.$1) return stops.first.$2;
  for (var i = 1; i < stops.length; i++) {
    if (alt <= stops[i].$1) {
      final a = stops[i - 1];
      final b = stops[i];
      return Color.lerp(a.$2, b.$2, (alt - a.$1) / (b.$1 - a.$1))!;
    }
  }
  return stops.last.$2;
}

// ───────── نجوم وسحب (ثابتة المواضع، بتتحرك مع الوقت) ─────────

class _Star {
  const _Star(this.x, this.y, this.r, this.a, this.phase, this.speed);
  final double x;
  final double y;
  final double r;
  final double a;
  final double phase;
  final double speed;
}

final List<_Star> _starField = () {
  final rnd = math.Random(7);
  return List<_Star>.generate(
    90,
    (_) => _Star(
      rnd.nextDouble(),
      rnd.nextDouble() * 0.68,
      0.5 + rnd.nextDouble() * 0.9,
      0.45 + rnd.nextDouble() * 0.55,
      rnd.nextDouble() * 6.28,
      0.8 + rnd.nextDouble() * 2.0,
    ),
  );
}();

class _Cloud {
  const _Cloud(this.x, this.y, this.scale, this.speed, this.puffs);
  final double x; // ٠..١ من عرض الكرت
  final double y; // ٠..١ من ارتفاع الكرت
  final double scale;
  final double speed; // بكسل في الثانية
  final List<(double, double, double)> puffs; // (إزاحة س، إزاحة ص، نصف القطر)
}

final List<_Cloud> _cloudField = () {
  final rnd = math.Random(21);
  return List<_Cloud>.generate(6, (i) {
    final n = 4 + rnd.nextInt(3);
    final puffs = <(double, double, double)>[];
    for (var k = 0; k < n; k++) {
      final off = k - (n - 1) / 2;
      final mid = n / 2 - off.abs(); // الأوسط أكبر وأعلى
      puffs.add((
        off * 16,
        -mid * 3 * (0.6 + rnd.nextDouble() * 0.8),
        11 + mid * 3 + rnd.nextDouble() * 3,
      ));
    }
    return _Cloud(
      (i + rnd.nextDouble() * 0.6) / 6,
      0.08 + rnd.nextDouble() * 0.38,
      0.7 + rnd.nextDouble() * 0.9,
      2.5 + rnd.nextDouble() * 5,
      puffs,
    );
  });
}();

// نقاط "بحار" القمر: (إزاحة س، إزاحة ص، نصف القطر) كنسبة من نصف قطر القمر
const List<(double, double, double)> _maria = [
  (-0.30, -0.25, 0.30),
  (0.25, -0.05, 0.24),
  (-0.10, 0.35, 0.20),
  (0.38, 0.40, 0.13),
  (0.00, -0.55, 0.13),
];

// ═════════════════════════════════════════════════════════════
//  الرسّام
// ═════════════════════════════════════════════════════════════

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.sky,
    required this.lat,
    required this.lng,
    required this.clock,
  }) : super(repaint: clock);

  final SkyState sky;
  final double lat;
  final double lng;
  final ValueNotifier<double> clock;

  // الشمس والقمر بيمشوا في قوس: الشروق على اليمين والغروب على الشمال
  // (نفس اتجاه الوقت في الواجهة العربية). الأفق عند ٨٠٪ من الارتفاع.
  Offset _pos(Size s, double frac, double arcH) => Offset(
        s.width * (0.92 - 0.84 * frac),
        s.height * 0.80 - arcH * math.sin(math.pi * frac),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = clock.value;
    final now = DateTime.now();

    final alt = _sunAlt(now, lat, lng);
    final day = ((alt + 6) / 12).clamp(0.0, 1.0).toDouble();
    final night = ((-alt - 3) / 12).clamp(0.0, 1.0).toDouble();
    final sunFrac = _fracOf(sky.sunArc, now);
    final moonFrac = _fracOf(sky.moonArc, now);
    final (top, mid, bottom) = _skyColors(alt);
    final horizonY = h * 0.80;

    // ───── السماء ─────
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          [top, mid, bottom],
          [0.0, 0.55, 1.0],
        ),
    );

    // ───── النجوم ─────
    if (night > 0) {
      for (final s in _starField) {
        final tw = 0.65 + 0.35 * math.sin(t * s.speed + s.phase);
        final a = s.a * night * tw;
        final p = Offset(s.x * w, s.y * h);
        canvas.drawCircle(
            p, s.r, Paint()..color = Colors.white.withValues(alpha: a));
        if (s.r > 1.1) {
          canvas.drawCircle(
            p,
            s.r * 3,
            Paint()..color = Colors.white.withValues(alpha: a * 0.18),
          );
        }
      }
      _drawShootingStar(canvas, size, t, night);
    }

    // ───── توهّج الأفق (الفجر والشروق والغروب) ─────
    final g = alt >= -1 ? (1 - (alt + 1) / 16) : (1 - (-1 - alt) / 12);
    final glow = g.clamp(0.0, 1.0).toDouble();
    if (glow > 0) {
      final fx = sunFrac ?? (sky.sunWest ? 1.05 : -0.05);
      final c = Offset(w * (0.92 - 0.84 * fx), horizonY);
      final r = w * 0.8;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [
            const Color(0xFFFF8A4C).withValues(alpha: 0.7 * glow),
            const Color(0x00FF8A4C),
          ]),
      );
    }

    // ───── القمر ─────
    if (moonFrac != null) {
      _drawMoon(
        canvas,
        _pos(size, moonFrac, h * 0.56),
        14,
        sky.moonElong,
        sky.waxing,
        1.0 - 0.55 * day,
      );
    }

    // ───── الشمس ─────
    if (sunFrac != null) {
      _drawSun(canvas, _pos(size, sunFrac, h * 0.62), alt, t, size);
    }

    // ───── السحب ─────
    _drawClouds(canvas, size, t, alt);

    // ───── التلال والأرض والمسجد ─────
    final far = Color.lerp(bottom, const Color(0xFF1F4A3A), 0.6)!;
    final nearHill = Color.lerp(bottom, const Color(0xFF14412A), 0.82)!;
    final ground =
        Color.lerp(const Color(0xFF07170E), const Color(0xFF14412A), day)!;

    canvas.drawPath(
        _hills(size, h * 0.78, h * 0.06, 0.021, 0.047, 1.3, 4.1), Paint()..color = far);
    canvas.drawPath(
        _hills(size, h * 0.835, h * 0.035, 0.034, 0.071, 0.4, 2.2),
        Paint()..color = nearHill);

    final base = h * 0.86;
    canvas.drawRect(Rect.fromLTWH(0, base, w, h - base), Paint()..color = ground);
    _drawMosque(
      canvas,
      Offset(w * 0.15, base),
      Color.lerp(ground, Colors.black, 0.35)!,
      night,
    );

    // ───── طبقة غامقة خفيفة عشان الكتابة البيضا تفضل واضحة ─────
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          const [Color(0x1A000000), Color(0x59000000)],
        ),
    );
  }

  // ───────── أدوات الرسم ─────────

  Path _hills(Size s, double y0, double amp, double f1, double f2, double p1,
      double p2) {
    final path = Path()..moveTo(0, s.height);
    for (var x = 0.0; x <= s.width + 6; x += 6) {
      final y = y0 -
          amp * (0.5 + 0.30 * math.sin(x * f1 + p1) + 0.20 * math.sin(x * f2 + p2));
      path.lineTo(x, y);
    }
    path
      ..lineTo(s.width, s.height)
      ..close();
    return path;
  }

  void _drawShootingStar(Canvas canvas, Size size, double t, double night) {
    // نيزك كل ٢٠ ثانية، يمرّ في أقل من ثانية
    final u = (t % 20.0);
    if (u > 0.9 || night < 0.6) return;
    final k = u / 0.9;
    final dir = const Offset(-1, 0.45);
    final head = Offset(size.width * 0.85, size.height * 0.10) + dir * (k * 220);
    final tail = head - dir * 55;
    final a = (1 - k) * night;
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(tail, head, [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.9 * a),
        ]),
    );
  }

  void _drawSun(Canvas canvas, Offset c, double alt, double t, Size size) {
    final low = (1 - alt / 25).clamp(0.0, 1.0).toDouble(); // ١ عند الأفق
    final r = 15.0 * (1 + 0.28 * low); // الشمس أكبر شوية عند الأفق
    final color = _sunColor(alt);

    // توهّج الجو الواسع
    final wide = size.width * 0.5;
    canvas.drawCircle(
      c,
      wide,
      Paint()
        ..shader = ui.Gradient.radial(c, wide, [
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0.0),
        ]),
    );

    // هالة بتنبض بالراحة
    final pulse = 1 + 0.05 * math.sin(t * 1.6);
    final cr = r * 4.2 * pulse;
    canvas.drawCircle(
      c,
      cr,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          cr,
          [
            color.withValues(alpha: 0.65),
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.0),
          ],
          [0.0, 0.35, 1.0],
        ),
    );

    // القرص: قلب أبيض حار وأطراف ملوّنة
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [Colors.white, Color.lerp(Colors.white, color, 0.55)!, color],
          [0.0, 0.55, 1.0],
        ),
    );
  }

  void _drawMoon(Canvas canvas, Offset c, double r, double elongDeg,
      bool waxing, double alpha) {
    // هالة
    canvas.drawCircle(
      c,
      r * 2.6,
      Paint()
        ..shader = ui.Gradient.radial(c, r * 2.6, [
          const Color(0xFFFFF6D6).withValues(alpha: 0.30 * alpha),
          const Color(0x00FFF6D6),
        ]),
    );
    // الجزء المظلم (ضوء الأرض الخافت)
    canvas.drawCircle(
      c,
      r,
      Paint()..color = const Color(0xFF3A4468).withValues(alpha: 0.85 * alpha),
    );
    // الجزء المضيء (حسب طور القمر الحقيقي)
    final cosE = math.cos(_rad(elongDeg));
    final s = waxing ? 1.0 : -1.0;
    final lit = Path()
      ..moveTo(c.dx, c.dy - r)
      ..arcTo(Rect.fromCircle(center: c, radius: r), -math.pi / 2, s * math.pi,
          false);
    final rx = (r * cosE).abs();
    final sweep = (s * cosE > 0) ? -math.pi : math.pi;
    lit.arcTo(
      Rect.fromCenter(center: c, width: 2 * rx, height: 2 * r),
      math.pi / 2,
      sweep,
      false,
    );
    lit.close();
    canvas.drawPath(
      lit,
      Paint()..color = const Color(0xFFF6F1DC).withValues(alpha: alpha),
    );

    // بحار وفوهات القمر على الجزء المضيء
    canvas.save();
    canvas.clipPath(lit);
    for (final m in _maria) {
      canvas.drawCircle(
        c + Offset(m.$1 * r, m.$2 * r),
        m.$3 * r,
        Paint()..color = const Color(0xFFB4AE92).withValues(alpha: 0.38 * alpha),
      );
    }
    canvas.restore();
  }

  void _drawClouds(Canvas canvas, Size size, double t, double alt) {
    final daylight = ((alt + 4) / 16).clamp(0.0, 1.0).toDouble();
    final twilight = (1 - (alt - 2).abs() / 10).clamp(0.0, 1.0).toDouble();
    var color = Color.lerp(const Color(0xFF39457A), Colors.white, daylight)!;
    color = Color.lerp(color, const Color(0xFFFFA77A), twilight * 0.7)!;
    final a = 0.28 + 0.45 * daylight;

    final span = size.width + 240;
    for (final cl in _cloudField) {
      final cx = ((cl.x * span - t * cl.speed) % span) - 120;
      final cy = cl.y * size.height;
      for (final p in cl.puffs) {
        final c = Offset(cx + p.$1 * cl.scale, cy + p.$2 * cl.scale);
        final r = p.$3 * cl.scale;
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              c,
              r,
              [
                color.withValues(alpha: a),
                color.withValues(alpha: a * 0.5),
                color.withValues(alpha: 0.0),
              ],
              [0.0, 0.55, 1.0],
            ),
        );
      }
    }
  }

  void _drawMosque(Canvas canvas, Offset b, Color c, double night) {
    final p = Paint()..color = c;

    // المبنى
    canvas.drawRect(Rect.fromLTRB(b.dx - 30, b.dy - 16, b.dx + 30, b.dy), p);
    // القبة الرئيسية
    final dome = Path()
      ..moveTo(b.dx - 17, b.dy - 16)
      ..arcTo(
        Rect.fromCenter(center: Offset(b.dx, b.dy - 16), width: 34, height: 44),
        math.pi,
        math.pi,
        false,
      )
      ..close();
    canvas.drawPath(dome, p);
    // هلال القبة
    canvas.drawRect(Rect.fromLTWH(b.dx - 0.7, b.dy - 46, 1.4, 8), p);
    canvas.drawCircle(Offset(b.dx, b.dy - 49), 2.6, p);
    // قبّتان جانبيتان
    for (final sx in [-22.0, 22.0]) {
      final side = Path()
        ..moveTo(b.dx + sx - 8, b.dy - 16)
        ..arcTo(
          Rect.fromCenter(
              center: Offset(b.dx + sx, b.dy - 16), width: 16, height: 18),
          math.pi,
          math.pi,
          false,
        )
        ..close();
      canvas.drawPath(side, p);
    }
    // مئذنتان
    for (final mx in [-42.0, 42.0]) {
      final x = b.dx + mx;
      final tall = mx > 0 ? 54.0 : 46.0;
      canvas.drawRect(Rect.fromLTWH(x - 3.5, b.dy - tall, 7, tall), p);
      canvas.drawRect(Rect.fromLTWH(x - 5.5, b.dy - tall * 0.62, 11, 3), p);
      final cap = Path()
        ..moveTo(x - 4.5, b.dy - tall)
        ..lineTo(x, b.dy - tall - 13)
        ..lineTo(x + 4.5, b.dy - tall)
        ..close();
      canvas.drawPath(cap, p);
      canvas.drawCircle(Offset(x, b.dy - tall - 15), 1.6, p);
    }

    // نوافذ منوّرة بالليل
    if (night > 0.15) {
      final win = Paint()
        ..color = const Color(0xFFFFD27A).withValues(alpha: 0.9 * night);
      for (final wx in [-14.0, -4.0, 6.0, 16.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(b.dx + wx - 1.6, b.dy - 12, 3.2, 7),
            const Radius.circular(1.6),
          ),
          win,
        );
      }
      for (final mx in [-42.0, 42.0]) {
        final tall = mx > 0 ? 54.0 : 46.0;
        canvas.drawRect(
          Rect.fromLTWH(b.dx + mx - 1, b.dy - tall * 0.8, 2, 4),
          win,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) =>
      old.sky != sky || old.lat != lat || old.lng != lng;
}
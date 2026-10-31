import 'dart:async';
import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'adhan_notifications.dart';
import 'cities.dart';
import 'common.dart';
import 'hijri_date.dart';
import 'location_service.dart';
import 'prayer_icons.dart';
import 'prayer_settings.dart';
import 'sky_card.dart';

class _Slot {
  const _Slot(this.name, this.icon, this.time, this.isPrayer);
  final String name;
  final PrayerIconKind icon;
  final DateTime time;
  final bool isPrayer;
}

const List<String> _kWeekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

const List<String> _kMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const Color _kDateGold = Color(0xFFB8923A);

const List<Shadow> _kTextShadow = [
  Shadow(blurRadius: 8, color: Color(0x8C000000), offset: Offset(0, 1)),
];

// ───────────────────────── الصفحة ─────────────────────────

class PrayerPage extends StatefulWidget {
  const PrayerPage({super.key});

  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage> {
  SharedPreferences? _prefs;
  Place? _place;
  MethodOption _method = methodById('muslim_world_league');
  bool _methodChosen = false;
  Madhab _madhab = Madhab.shafi;
  bool _busy = true;
  String? _error;
  int _hijriAdj = 0; // تعديل التاريخ الهجري (من الإعدادات)

  @override
  void initState() {
    super.initState();
    settingsChanged.addListener(_onSettingsChanged);
    _init();
  }

  @override
  void dispose() {
    settingsChanged.removeListener(_onSettingsChanged);
    super.dispose();
  }

  /// بتتنفّذ لما المستخدم يغيّر حاجة من صفحة الإعدادات
  Future<void> _onSettingsChanged() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    final savedMethod = p.getString('p_method');
    final madhab =
        p.getString('p_madhab') == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    final adj = p.getInt('hijri_adj') ?? 0;
    final place = LocationService.saved(p);
    if (!mounted) return;
    setState(() {
      if (savedMethod != null) {
        _method = methodById(savedMethod);
        _methodChosen = true;
      }
      _madhab = madhab;
      _hijriAdj = adj;
      if (place != null) {
        _place = place; // الموقع اتغيّر من الإعدادات
        _error = null;
        _busy = false;
        if (!_methodChosen) _method = methodById(autoMethodId(place.cc));
      }
    });
    unawaited(_scheduleAdhan());
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;

    final savedMethod = p.getString('p_method');
    if (savedMethod != null) {
      _method = methodById(savedMethod);
      _methodChosen = true;
    }
    _madhab = p.getString('p_madhab') == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    _hijriAdj = p.getInt('hijri_adj') ?? 0;

    final lat = p.getDouble('p_lat');
    final lng = p.getDouble('p_lng');
    if (lat != null && lng != null) {
      final cc = p.getString('p_cc');
      if (!_methodChosen) _method = methodById(autoMethodId(cc));
      if (!mounted) return;
      setState(() {
        _place = Place(
          city: p.getString('p_city') ?? 'موقعك',
          lat: lat,
          lng: lng,
          cc: cc,
          fromGps: p.getBool('p_gps') ?? false,
        );
        _busy = false;
      });
      unawaited(_startAdhan());
    } else {
      // أول مرة: نطلب صلاحية الموقع ونحدد المدينة
      await _detect();
    }
  }

  // ───────── تحديد الموقع ─────────

  Future<void> _detect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final place = await LocationService.detect();
      if (!mounted) return;
      _applyPlace(place);
    } on LocationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'تعذر تحديد موقعك. اتأكد من الـ GPS أو اختر مدينتك يدويًا.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyPlace(Place pl) {
    setState(() {
      _place = pl;
      _error = null;
      if (!_methodChosen) _method = methodById(autoMethodId(pl.cc));
    });
    unawaited(_startAdhan());
    final p = _prefs;
    if (p == null) return;
    // بعد الحفظ نبلّغ صفحة الإعدادات عشان تعرض الموقع الجديد
    unawaited(LocationService.save(p, pl).then((_) => notifySettingsChanged()));
  }

  // ───────── الاختيارات ─────────

  Future<void> _pickCity() async {
    final chosen = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('تحديد موقعي تلقائيًا (GPS)'),
              onTap: () {
                Navigator.pop(ctx);
                _detect();
              },
            ),
            const Divider(height: 1),
            for (final c in kCities)
              ListTile(
                leading: const Icon(Icons.location_city_outlined),
                title: Text(c.city),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    _applyPlace(chosen);
  }

  // ───────── تنبيه الأذان ─────────

  Future<void> _scheduleAdhan() async {
    final p = _place;
    if (p == null) return;
    await AdhanService.instance.reschedule(timesFor: _timesFor, city: p.city);
  }

  Future<void> _startAdhan() async {
    await AdhanService.instance.askPermissionsOnce();
    await _scheduleAdhan();
  }

  // ───────── الحساب ─────────

  PrayerTimes _timesFor(DateTime day) {
    final params = _method.method.getParameters();
    params.madhab = _madhab;
    final p = _place!;
    return PrayerTimes(
      Coordinates(p.lat, p.lng),
      DateComponents.from(day),
      params,
    );
  }

  List<_Slot> _slots(PrayerTimes t) => [
        _Slot('الفجر', PrayerIconKind.fajr, t.fajr, true),
        _Slot('الشروق', PrayerIconKind.sunrise, t.sunrise, false),
        _Slot('الظهر', PrayerIconKind.dhuhr, t.dhuhr, true),
        _Slot('العصر', PrayerIconKind.asr, t.asr, true),
        _Slot('المغرب', PrayerIconKind.maghrib, t.maghrib, true),
        _Slot('العشاء', PrayerIconKind.isha, t.isha, true),
      ];

  // ───────── الواجهة ─────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
      ),
      body: _place == null ? _emptyState() : _content(),
    );
  }

  Widget _emptyState() {
    if (_busy) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جارٍ تحديد موقعك...'),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              _error ?? 'محتاجين موقعك عشان نحسب مواقيت الصلاة بدقة لمدينتك.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _detect,
              icon: const Icon(Icons.my_location),
              label: const Text('السماح وتحديد موقعي'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickCity,
              icon: const Icon(Icons.location_city),
              label: const Text('اختيار المدينة يدويًا'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final scheme = Theme.of(context).colorScheme;
    final place = _place!;
    final now = DateTime.now();

    final today = _slots(_timesFor(now));
    final nextIndex = today.indexWhere((s) => s.isPrayer && s.time.isAfter(now));
    final isTomorrow = nextIndex == -1;
    final nextSlot = isTomorrow
        ? _slots(_timesFor(now.add(const Duration(days: 1)))).first
        : today[nextIndex];

    // وقت الصلاة السابقة (عشان شريط التقدّم)
    final DateTime prevTime;
    if (isTomorrow) {
      prevTime = today.lastWhere((s) => s.isPrayer).time;
    } else if (nextIndex == 0) {
      prevTime = _slots(_timesFor(now.subtract(const Duration(days: 1))))
          .lastWhere((s) => s.isPrayer)
          .time;
    } else {
      prevTime = today.sublist(0, nextIndex).lastWhere((s) => s.isPrayer).time;
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 2),

        // المدينة واليوم
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Row(
            children: [
              Icon(
                place.fromGps ? Icons.my_location : Icons.location_city,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  place.city,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _kWeekdays[now.weekday - 1],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // التاريخ الهجري والميلادي
        _DateStrip(now: now, hijriAdj: _hijriAdj),

        if (_error != null)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: scheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(height: 1.5)),
                  ),
                ],
              ),
            ),
          ),

        // الصلاة القادمة
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // السماء: شمس وقمر وسحب ونجوم حسب الوقت الحقيقي في مدينتك
                Positioned.fill(
                  child: SkyBackground(lat: place.lat, lng: place.lng),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 215),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          isTomorrow ? 'الصلاة القادمة، غدًا' : 'الصلاة القادمة',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            shadows: _kTextShadow,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              nextSlot.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                shadows: _kTextShadow,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              formatTime(nextSlot.time),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                shadows: _kTextShadow,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text(
                            'متبقي  ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              shadows: _kTextShadow,
                            ),
                          ),
                          _Countdown(
                            target: nextSlot.time,
                            onReached: () {
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _NextProgress(start: prevTime, end: nextSlot.time),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // مواقيت اليوم
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < today.length; i++) ...[
                if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                _row(today[i], i == nextIndex, scheme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(_Slot s, bool highlight, ColorScheme scheme) {
    final weight = highlight ? FontWeight.w700 : FontWeight.w500;
    return Container(
      color: highlight ? scheme.primaryContainer : null,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          PrayerIcon(s.icon, size: 32, muted: !s.isPrayer),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              s.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: weight,
                color: s.isPrayer ? kInk : scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            formatTime(s.time),
            style: TextStyle(
              fontSize: 18,
              fontWeight: weight,
              color: s.isPrayer ? kInk : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── العدّاد التنازلي ─────────────────────────

class _Countdown extends StatefulWidget {
  const _Countdown({required this.target, required this.onReached});

  final DateTime target;
  final VoidCallback onReached;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) _fired = false;
  }

  void _tick() {
    if (!mounted) return;
    if (!widget.target.isAfter(DateTime.now())) {
      if (!_fired) {
        _fired = true;
        widget.onReached();
      }
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    var seconds = widget.target.difference(DateTime.now()).inSeconds;
    if (seconds < 0) seconds = 0;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return Text(
      arDigits('${_two(h)}:${_two(m)}:${_two(s)}'),
      style: const TextStyle(
        color: kGold,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        shadows: _kTextShadow,
      ),
    );
  }
}

// ───────────────────────── شريط التقدّم نحو الصلاة القادمة ─────────────────────────

class _NextProgress extends StatefulWidget {
  const _NextProgress({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  State<_NextProgress> createState() => _NextProgressState();
}

class _NextProgressState extends State<_NextProgress> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.end.difference(widget.start).inSeconds;
    final done = DateTime.now().difference(widget.start).inSeconds;
    final value =
        total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 5,
        backgroundColor: Colors.white.withValues(alpha: 0.22),
        valueColor: const AlwaysStoppedAnimation<Color>(kGold),
      ),
    );
  }
}

// ───────────────────────── شريط التاريخ (هجري + ميلادي) ─────────────────────────

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.now, required this.hijriAdj});

  final DateTime now;
  final int hijriAdj;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = HijriDate.fromGregorian(now, adjust: hijriAdj);
    return AppCard(
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _DateHalf(
                label: 'التاريخ الهجري',
                day: h.day,
                title: h.monthName,
                subtitle: '${arDigits(h.year)} هـ',
                color: scheme.primary,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              indent: 12,
              endIndent: 12,
              color: scheme.outlineVariant,
            ),
            Expanded(
              child: _DateHalf(
                label: 'التاريخ الميلادي',
                day: now.day,
                title: _kMonths[now.month - 1],
                subtitle: '${arDigits(now.year)} م',
                color: _kDateGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHalf extends StatelessWidget {
  const _DateHalf({
    required this.label,
    required this.day,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String label;
  final int day;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          _DayBadge(day, color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// رقم اليوم داخل نجمة ثمانية (مربعان متداخلان)
class _DayBadge extends StatelessWidget {
  const _DayBadge(this.day, this.color);

  final int day;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget square() => Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color, width: 1.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          square(),
          Transform.rotate(angle: math.pi / 4, child: square()),
          Text(
            arDigits(day),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
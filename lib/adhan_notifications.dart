import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'common.dart';

// ═════════════════════════════════════════════════════════════
//  أصوات الأذان
//  عشان تضيف صوت: حط ملف mp3 في المكانين (الشرح في الرسالة)
//  وضيف سطر جديد في القايمة اللي تحت.
//  الـ id لازم يكون نفس اسم الملف بدون .mp3
//  (حروف إنجليزي صغيرة وأرقام و _ بس)
// ═════════════════════════════════════════════════════════════

class AdhanVoice {
  const AdhanVoice(this.id, this.name);
  final String id;
  final String name;
}

const AdhanVoice kDefaultVoice =
    AdhanVoice('default', 'صوت الإشعار الافتراضي');

const List<AdhanVoice> kAdhanVoices = [
  AdhanVoice('azan1', 'أذان ١'),
  AdhanVoice('azan2', 'أذان ٢'),
  AdhanVoice('azan3', 'أذان ٣'),
];

class PrayerKey {
  const PrayerKey(this.key, this.name, this.icon);
  final String key;
  final String name;
  final IconData icon;
}

const List<PrayerKey> kPrayerKeys = [
  PrayerKey('fajr', 'الفجر', Icons.nights_stay_outlined),
  PrayerKey('dhuhr', 'الظهر', Icons.wb_sunny_outlined),
  PrayerKey('asr', 'العصر', Icons.wb_cloudy_outlined),
  PrayerKey('maghrib', 'المغرب', Icons.brightness_4_outlined),
  PrayerKey('isha', 'العشاء', Icons.bedtime_outlined),
];

// ═════════════════════════════════════════════════════════════
//  الخدمة: بتجدول إشعارات الأذان وبتحفظ اختيارات المستخدم
// ═════════════════════════════════════════════════════════════

class AdhanService {
  AdhanService._();
  static final AdhanService instance = AdhanService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _player = AudioPlayer();
  SharedPreferences? _prefs;
  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  // ───────── الإعدادات المحفوظة ─────────

  bool get enabled => _prefs?.getBool('adh_enabled') ?? true;
  Future<void> setEnabled(bool v) async => _prefs?.setBool('adh_enabled', v);

  bool prayerOn(String key) => _prefs?.getBool('adh_on_$key') ?? true;
  Future<void> setPrayerOn(String key, bool v) async =>
      _prefs?.setBool('adh_on_$key', v);

  AdhanVoice voiceById(String id) => kAdhanVoices.firstWhere(
        (v) => v.id == id,
        orElse: () => kDefaultVoice,
      );

  AdhanVoice voiceFor(String key) =>
      voiceById(_prefs?.getString('adh_voice_$key') ?? kDefaultVoice.id);

  Future<void> setVoice(String key, AdhanVoice v) async =>
      _prefs?.setString('adh_voice_$key', v.id);

  // ───────── التجهيز ─────────

  String _channelId(AdhanVoice v) => 'adhan_${v.id}_v2';
  String _channelName(AdhanVoice v) => 'أذان - ${v.name}';

  AndroidNotificationSound? _soundOf(AdhanVoice v) =>
      v.id == kDefaultVoice.id ? null : RawResourceAndroidNotificationSound(v.id);

  Future<void> init() async {
    if (_ready) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      // قناة منفصلة لكل صوت (صوت القناة مبيتغيرش بعد ما تتعمل)
      for (final v in [kDefaultVoice, ...kAdhanVoices]) {
        await _android?.createNotificationChannel(
          AndroidNotificationChannel(
            _channelId(v),
            _channelName(v),
            description: 'تنبيهات أوقات الصلاة',
            importance: Importance.max,
            playSound: true,
            sound: _soundOf(v),
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );
      }
      _ready = true;
    } catch (e) {
      debugPrint('adhan init failed: $e');
    }
  }

  NotificationDetails _details(AdhanVoice v) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId(v),
          _channelName(v),
          channelDescription: 'تنبيهات أوقات الصلاة',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: _soundOf(v),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
        ),
      );

  // ───────── الصلاحيات ─────────

  Future<bool> requestPermissions() async {
    if (!_ready) await init();
    final android = _android;
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission() ?? false;
    try {
      final exact = await android.canScheduleExactNotifications() ?? false;
      if (!exact) await android.requestExactAlarmsPermission();
    } catch (_) {}
    return granted;
  }

  /// بتطلب الصلاحيات أول مرة بس
  Future<void> askPermissionsOnce() async {
    if (!_ready) await init();
    final p = _prefs;
    if (p == null || p.getBool('adh_asked') == true) return;
    try {
      await requestPermissions();
      // نسجّل إننا سألنا بس لو الطلب نفسه اشتغل
      await p.setBool('adh_asked', true);
    } catch (e) {
      debugPrint('adhan permission request failed: $e');
    }
  }

  // ───────── فحص التنبيهات ─────────

  /// تقرير بحالة الصلاحيات والتنبيهات المجدولة
  Future<String> diagnose() async {
    if (!_ready) await init();
    final a = _android;
    bool? notif;
    bool? exact;
    var pending = -1;
    try {
      notif = await a?.areNotificationsEnabled();
    } catch (_) {}
    try {
      exact = await a?.canScheduleExactNotifications();
    } catch (_) {}
    try {
      pending = (await _plugin.pendingNotificationRequests()).length;
    } catch (_) {}

    String yn(bool? v) => v == true ? 'مسموح ✓' : (v == false ? 'مرفوض ✗' : 'غير معروف');
    return 'التهيئة: ${_ready ? 'تمت ✓' : 'فشلت ✗'}\n'
        'تفعيل الأذان من الإعدادات: ${enabled ? 'مفعّل ✓' : 'مقفول ✗'}\n'
        'إذن الإشعارات: ${yn(notif)}\n'
        'إذن المنبّهات الدقيقة: ${yn(exact)}\n'
        'تنبيهات مجدولة: ${pending < 0 ? 'غير معروف' : pending}\n\n'
        'لو الإذن مرفوض اضغط "طلب الصلاحيات". ولو التنبيهات المجدولة صفر، '
        'افتح صفحة المواقيت مرة عشان تتجدول.';
  }

  /// إشعار مجدول بعد دقيقة، لتجربة الجدولة نفسها (مش الإشعار الفوري)
  Future<void> scheduleTest() async {
    if (!_ready) await init();
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      id: 998,
      title: 'اختبار الجدولة',
      body: 'لو شفت الإشعار ده يبقى الجدولة شغّالة',
      scheduledDate: tz.TZDateTime.from(
        DateTime.now().add(const Duration(minutes: 1)),
        tz.UTC,
      ),
      notificationDetails: _details(kAdhanVoices.first),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // ───────── الجدولة ─────────

  /// بتجدول أذان 7 أيام جاية (وبتتجدد كل ما التطبيق يفتح)
  Future<void> reschedule({
    required PrayerTimes Function(DateTime day) timesFor,
    required String city,
  }) async {
    if (!_ready) await init();
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (!enabled) return;

      final exact = await _android?.canScheduleExactNotifications() ?? false;
      final now = DateTime.now();

      for (var d = 0; d < 7; d++) {
        final t = timesFor(now.add(Duration(days: d)));
        final times = [t.fajr, t.dhuhr, t.asr, t.maghrib, t.isha];
        for (var i = 0; i < kPrayerKeys.length; i++) {
          final p = kPrayerKeys[i];
          final time = times[i];
          if (!prayerOn(p.key)) continue;
          if (!time.isAfter(now.add(const Duration(seconds: 5)))) continue;

          await _plugin.zonedSchedule(
            id: d * 10 + i,
            title: 'حان الآن موعد أذان ${p.name}',
            body: city,
            scheduledDate: tz.TZDateTime.from(time, tz.UTC),
            notificationDetails: _details(voiceFor(p.key)),
            androidScheduleMode: exact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    } catch (e) {
      debugPrint('adhan schedule failed: $e');
    }
  }

  /// إشعار فوري للتجربة بالصوت المختار
  Future<void> showTest(AdhanVoice v) async {
    if (!_ready) await init();
    try {
      await _plugin.show(
        id: 999,
        title: 'تجربة الأذان',
        body: v.name,
        notificationDetails: _details(v),
      );
    } catch (e) {
      debugPrint('adhan test failed: $e');
    }
  }

  // ───────── سماع الصوت قبل الاختيار ─────────

  Stream<void> get onPreviewDone => _player.onPlayerComplete;

  Future<void> preview(AdhanVoice v) async {
    await _player.stop();
    if (v.id == kDefaultVoice.id) return;
    try {
      await _player.play(AssetSource('adhan/${v.id}.mp3'));
    } catch (e) {
      debugPrint('adhan preview failed: $e');
    }
  }

  Future<void> stopPreview() => _player.stop();
}

// ═════════════════════════════════════════════════════════════
//  صفحة إعدادات الأذان
// ═════════════════════════════════════════════════════════════

class AdhanSettingsPage extends StatefulWidget {
  const AdhanSettingsPage({super.key, required this.onChanged});

  /// بتتنفّذ بعد أي تغيير عشان تتعمل جدولة جديدة
  final Future<void> Function() onChanged;

  @override
  State<AdhanSettingsPage> createState() => _AdhanSettingsPageState();
}

class _AdhanSettingsPageState extends State<AdhanSettingsPage> {
  final AdhanService _svc = AdhanService.instance;

  Future<void> _changed() async {
    if (mounted) setState(() {});
    await widget.onChanged();
  }

  Future<AdhanVoice?> _pickVoice(String title, AdhanVoice current) async {
    final chosen = await showModalBottomSheet<AdhanVoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _VoiceSheet(title: title, current: current),
    );
    await _svc.stopPreview();
    return chosen;
  }

  Future<void> _applyAll() async {
    final v = await _pickVoice('صوت واحد لكل الصلوات', kDefaultVoice);
    if (v == null) return;
    for (final p in kPrayerKeys) {
      await _svc.setVoice(p.key, v);
    }
    await _changed();
  }

  Future<void> _diagnose() async {
    final report = await _svc.diagnose();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('فحص التنبيهات'),
        content: SingleChildScrollView(
          child: Text(report, style: const TextStyle(height: 1.8)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _svc.requestPermissions();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('طلب الصلاحيات'),
          ),
          TextButton(
            onPressed: () async {
              await _svc.scheduleTest();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('اختبار بعد دقيقة'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _test() async {
    final v = await _pickVoice('اختار صوت للتجربة', kDefaultVoice);
    if (v == null) return;
    await _svc.requestPermissions();
    await _svc.showTest(v);
  }

  Widget _prayerTile(PrayerKey p, ColorScheme scheme) {
    final voice = _svc.voiceFor(p.key);
    return ListTile(
      leading: Icon(p.icon, color: scheme.primary),
      title: Text(p.name, style: const TextStyle(fontSize: 18)),
      subtitle: Text('الصوت: ${voice.name}'),
      onTap: () async {
        final v = await _pickVoice('صوت أذان ${p.name}', voice);
        if (v == null) return;
        await _svc.setVoice(p.key, v);
        await _changed();
      },
      trailing: Switch(
        value: _svc.prayerOn(p.key),
        onChanged: (on) async {
          await _svc.setPrayerOn(p.key, on);
          await _changed();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('تنبيه الأذان')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          AppCard(
            child: SwitchListTile(
              title: const Text('تفعيل تنبيه الأذان'),
              subtitle: const Text('يشغّل صوت الأذان في وقت كل صلاة'),
              value: _svc.enabled,
              onChanged: (v) async {
                await _svc.setEnabled(v);
                if (v) await _svc.requestPermissions();
                await _changed();
              },
            ),
          ),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < kPrayerKeys.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                  _prayerTile(kPrayerKeys[i], scheme),
                ],
              ],
            ),
          ),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.library_music_outlined,
                      color: scheme.primary),
                  title: const Text('نفس الصوت لكل الصلوات'),
                  subtitle: const Text('اختار صوت واحد وطبّقه على الكل'),
                  onTap: _applyAll,
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                ListTile(
                  leading: Icon(Icons.notifications_active_outlined,
                      color: scheme.primary),
                  title: const Text('جرّب التنبيه الآن'),
                  subtitle: const Text('اختار صوت وهيظهر إشعار فورًا'),
                  onTap: _test,
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                ListTile(
                  leading: Icon(Icons.health_and_safety_outlined,
                      color: scheme.primary),
                  title: const Text('فحص التنبيهات'),
                  subtitle: const Text('لو الأذان مش بيشتغل في وقته'),
                  onTap: _diagnose,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: Text(
              'لو الأذان ما اشتغلش: اتأكد من السماح بالإشعارات، وإن الموبايل '
              'مش بيقفل التطبيق في الخلفية (توفير الطاقة)، وإن صوت المنبّه عالي.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                height: 1.6,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────── شاشة اختيار الصوت مع زرار تشغيل لكل صوت ─────────

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet({required this.title, required this.current});

  final String title;
  final AdhanVoice current;

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  String? _playing;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AdhanService.instance.onPreviewDone.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _toggle(AdhanVoice v) async {
    if (_playing == v.id) {
      await AdhanService.instance.stopPreview();
      if (mounted) setState(() => _playing = null);
    } else {
      setState(() => _playing = v.id);
      await AdhanService.instance.preview(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = [kDefaultVoice, ...kAdhanVoices];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: kInk),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final v in all)
                    ListTile(
                      leading: Icon(
                        v.id == widget.current.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: scheme.primary,
                      ),
                      title: Text(v.name),
                      trailing: v.id == kDefaultVoice.id
                          ? null
                          : IconButton(
                              tooltip: 'سماع الصوت',
                              icon: Icon(
                                _playing == v.id
                                    ? Icons.stop_circle_outlined
                                    : Icons.play_circle_outline,
                                size: 30,
                              ),
                              onPressed: () => _toggle(v),
                            ),
                      onTap: () => Navigator.pop(context, v),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'adhan_notifications.dart';
import 'cities.dart';
import 'common.dart';
import 'hijri_date.dart';
import 'location_service.dart';
import 'prayer_settings.dart';
import 'update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SharedPreferences? _prefs;
  MethodOption _method = methodById('muslim_world_league');
  Madhab _madhab = Madhab.shafi;
  Place? _place;
  int _hijriAdj = 0;
  bool _locating = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    settingsChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    settingsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('p_method');
    if (!mounted) return;
    setState(() {
      _prefs = p;
      // لو المستخدم ما اختارش طريقة، بنعرض الطريقة التلقائية حسب دولته
      _method = methodById(saved ?? autoMethodId(p.getString('p_cc')));
      _madhab =
          p.getString('p_madhab') == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
      _place = LocationService.saved(p);
      _hijriAdj = p.getInt('hijri_adj') ?? 0;
    });
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {}
  }

  // ───────── الموقع ─────────

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickLocation() async {
    final chosen = await showModalBottomSheet<Object>(
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
              onTap: () => Navigator.pop(ctx, 'gps'),
            ),
            const Divider(height: 1),
            for (final c in kCities)
              ListTile(
                leading: const Icon(Icons.location_city_outlined),
                title: Text(c.city),
                trailing: _place != null &&
                        !_place!.fromGps &&
                        _place!.city == c.city
                    ? Icon(Icons.check,
                        color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    if (chosen == 'gps') {
      await _detect();
    } else if (chosen is Place) {
      await _setPlace(chosen);
    }
  }

  Future<void> _detect() async {
    setState(() => _locating = true);
    try {
      final place = await LocationService.detect();
      await _setPlace(place);
    } on LocationException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذر تحديد موقعك. اتأكد من الـ GPS أو اختر مدينتك يدويًا.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _setPlace(Place place) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await LocationService.save(p, place);
    if (mounted) setState(() => _place = place);
    notifySettingsChanged(); // صفحة المواقيت تحسب من الموقع الجديد
  }

  // ───────── التاريخ الهجري ─────────

  Future<void> _setHijriAdj(int v) async {
    setState(() => _hijriAdj = v);
    await _prefs?.setInt('hijri_adj', v);
    notifySettingsChanged();
  }

  Future<void> _pickMethod() async {
    final chosen = await showModalBottomSheet<MethodOption>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in kMethods)
              ListTile(
                title: Text(m.label),
                trailing: m.id == _method.id
                    ? Icon(Icons.check,
                        color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _method = chosen);
    await _prefs?.setString('p_method', chosen.id);
    notifySettingsChanged();
  }

  Future<void> _setMadhab(Madhab m) async {
    setState(() => _madhab = m);
    await _prefs?.setString(
        'p_madhab', m == Madhab.hanafi ? 'hanafi' : 'shafi');
    notifySettingsChanged();
  }

  void _openAdhanSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdhanSettingsPage(
          // بعد أي تغيير في الأذان، صفحة المواقيت بتعيد الجدولة
          onChanged: () async => notifySettingsChanged(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          // الموقع
          AppCard(
            child: ListTile(
              leading: _locating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(
                      (_place?.fromGps ?? false)
                          ? Icons.my_location
                          : Icons.location_city,
                    ),
              title: const Text('الموقع'),
              subtitle: Text(
                _place == null
                    ? 'لسه ما اتحددش، اضغط للاختيار'
                    : '${_place!.city}${_place!.fromGps ? ' (تلقائي)' : ''}',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: _locating ? null : _pickLocation,
            ),
          ),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('تنبيه الأذان'),
                  subtitle: const Text('اختيار صوت الأذان لكل صلاة'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _openAdhanSettings,
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: const Text('طريقة الحساب'),
                  subtitle: Text(_method.label),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _pickMethod,
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'حساب وقت العصر',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<Madhab>(
                          segments: const <ButtonSegment<Madhab>>[
                            ButtonSegment(
                              value: Madhab.shafi,
                              label: Text('الجمهور'),
                            ),
                            ButtonSegment(
                              value: Madhab.hanafi,
                              label: Text('الحنفي'),
                            ),
                          ],
                          selected: {_madhab},
                          onSelectionChanged: (s) => _setMadhab(s.first),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // التحديث
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: const Text('التحقق من التحديثات'),
              subtitle: Text(
                  _version.isEmpty ? '' : 'الإصدار الحالي: ${arDigits(_version)}'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => UpdateService.checkAndPrompt(context, manual: true),
            ),
          ),
          // التاريخ الهجري
          AppCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تعديل التاريخ الهجري',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'النهاردة: ${HijriDate.fromGregorian(DateTime.now(), adjust: _hijriAdj).format()}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: const <ButtonSegment<int>>[
                        ButtonSegment(value: -1, label: Text('يوم أقل')),
                        ButtonSegment(value: 0, label: Text('كما هو')),
                        ButtonSegment(value: 1, label: Text('يوم أكثر')),
                      ],
                      selected: {_hijriAdj},
                      onSelectionChanged: (s) => _setHijriAdj(s.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
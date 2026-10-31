import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';

import 'common.dart';

const int _surahCount = 114;
const String _basmala = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

// ───────────────────────── فهرس السور ─────────────────────────

class QuranIndexPage extends StatefulWidget {
  const QuranIndexPage({super.key});

  @override
  State<QuranIndexPage> createState() => _QuranIndexPageState();
}

class _QuranIndexPageState extends State<QuranIndexPage> {
  int? _lastSurah;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _lastSurah = prefs.getInt('last_surah'));
  }

  Future<void> _open(int surah) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SurahPage(surah: surah)),
    );
    _loadLast();
  }

  bool _isMakki(int n) =>
      quran.getPlaceOfRevelation(n).toLowerCase().startsWith('mak');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _lastSurah;

    return Scaffold(
      appBar: AppBar(title: const Text('المصحف الشريف')),
      body: Column(
        children: [
          if (last != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Material(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _open(last),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.auto_stories, color: scheme.onPrimary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'كمّل القراءة',
                                style: TextStyle(
                                    color: scheme.onPrimary, fontSize: 13),
                              ),
                              Text(
                                'سورة ${quran.getSurahNameArabic(last)}',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_left, color: scheme.onPrimary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: _surahCount,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: scheme.outlineVariant,
              ),
              itemBuilder: (context, i) {
                final n = i + 1;
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: _SurahBadge(n),
                  title: Text(
                    quran.getSurahNameArabic(n),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                    ),
                  ),
                  subtitle: Text(
                    '${_isMakki(n) ? 'مكية' : 'مدنية'}، ${arDigits(quran.getVerseCount(n))} آية',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => _open(n),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// رقم السورة داخل نجمة ثمانية (مربعان متداخلان)
class _SurahBadge extends StatelessWidget {
  const _SurahBadge(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    Widget square() => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.2),
            borderRadius: BorderRadius.circular(3),
          ),
        );

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          square(),
          Transform.rotate(angle: math.pi / 4, child: square()),
          Text(
            arDigits(number),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── قراءة السورة ─────────────────────────

class SurahPage extends StatefulWidget {
  const SurahPage({super.key, required this.surah});

  final int surah;

  @override
  State<SurahPage> createState() => _SurahPageState();
}

class _SurahPageState extends State<SurahPage> {
  double _fontSize = 22;
  SharedPreferences? _prefs;

  /// آيات السورة مقسّمة على صفحات المصحف: رقم الصفحة ← أرقام الآيات
  late final Map<int, List<int>> _pages = _buildPages();

  Map<int, List<int>> _buildPages() {
    final pages = <int, List<int>>{};
    final count = quran.getVerseCount(widget.surah);
    for (var v = 1; v <= count; v++) {
      pages
          .putIfAbsent(quran.getPageNumber(widget.surah, v), () => <int>[])
          .add(v);
    }
    return pages;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah', widget.surah);
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _fontSize = prefs.getDouble('mushaf_font_size') ?? 22;
    });
  }

  void _changeSize(double delta) {
    final size = (_fontSize + delta).clamp(18.0, 48.0).toDouble();
    setState(() => _fontSize = size);
    _prefs?.setDouble('mushaf_font_size', size);
  }

  bool get _isMakki =>
      quran.getPlaceOfRevelation(widget.surah).toLowerCase().startsWith('mak');

  /// نص الآية بدون الرقم
  String _plain(int verse) => quran.getVerse(widget.surah, verse).trim();

  /// علامة نهاية الآية (الدائرة ورقمها)
  String _marker(int verse) {
    final plain = quran.getVerse(widget.surah, verse);
    final full = quran.getVerse(widget.surah, verse, verseEndSymbol: true);
    return full.length > plain.length
        ? full.substring(plain.length).trim()
        : '';
  }

  Widget _headerChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 13.5),
        ),
      );

  // ───────── العنوان: إطار السورة + البسملة ─────────

  Widget _header(ColorScheme scheme, bool showBasmala) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF0B3B22), Color(0xFF14653D)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330F4A2C),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(color: kGold.withValues(alpha: 0.85), width: 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  'سورة ${quran.getSurahNameArabic(widget.surah)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: kGold,
                  ),
                ),
                const SizedBox(height: 8),
                // فاصل زخرفي: خط ◆ خط
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: kGold.withValues(alpha: 0.45),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Transform.rotate(
                        angle: math.pi / 4,
                        child: Container(width: 8, height: 8, color: kGold),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: kGold.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _headerChip(_isMakki ? 'مكية' : 'مدنية'),
                    const SizedBox(width: 8),
                    _headerChip(
                        '${arDigits(quran.getVerseCount(widget.surah))} آية'),
                    const SizedBox(width: 8),
                    _headerChip('رقم ${arDigits(widget.surah)}'),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (showBasmala)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              _basmala,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _fontSize + 2,
                height: 2,
                color: scheme.primary,
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ───────── صفحة من المصحف ─────────

  Widget _mushafPage(int page, List<int> verses, ColorScheme scheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(child: Divider(color: scheme.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'صفحة ${arDigits(page)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(child: Divider(color: scheme.outlineVariant)),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                for (final v in verses) ...[
                  TextSpan(text: _plain(v)),
                  // العلامة أصغر ولونها مختلف، وملزوقة بآخر كلمة
                  TextSpan(
                    text: '\u00A0${_marker(v)} ',
                    style: TextStyle(
                      fontSize: _fontSize * 0.8,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ],
            ),
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: _fontSize, height: 1.95, color: kInk),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // البسملة تظهر قبل كل سورة إلا الفاتحة (هي آية فيها) والتوبة
    final showBasmala = widget.surah != 1 && widget.surah != 9;
    final entries = _pages.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('سورة ${quran.getSurahNameArabic(widget.surah)}'),
        actions: [
          IconButton(
            tooltip: 'تصغير الخط',
            icon: const Icon(Icons.text_decrease),
            onPressed: () => _changeSize(-2),
          ),
          IconButton(
            tooltip: 'تكبير الخط',
            icon: const Icon(Icons.text_increase),
            onPressed: () => _changeSize(2),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 48),
        itemCount: entries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _header(scheme, showBasmala);
          final e = entries[index - 1];
          return _mushafPage(e.key, e.value, scheme);
        },
      ),
    );
  }
}
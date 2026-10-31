import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'adhkar_data.dart';
import 'common.dart';

// ───────────────────────── قائمة الفئات ─────────────────────────

class AdhkarPage extends StatelessWidget {
  const AdhkarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الأذكار')),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          // زرار الأدعية (فيه أدعية كتير مقسّمة على أقسام)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Material(
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF0B3B22), Color(0xFF14653D)],
                  ),
                ),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DuasPage()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                    // الأيقونة في نص الكارت، وتحتها العنوان والسطر الصغير
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: kGold.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(color: kGold, width: 1.2),
                            ),
                            child: const Center(
                              child: FaIcon(FontAwesomeIcons.personPraying,
                                  color: kGold, size: 32),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'الأدعية',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: kGold,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${arDigits(kDuas.length)} أقسام، ${arDigits(_countItems(kDuas))} دعاء',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _SectionLabel('الأذكار اليومية', scheme.primary),
          for (final c in kAdhkar) CategoryTile(c),
        ],
      ),
    );
  }
}

int _countItems(List<DhikrCategory> cs) =>
    cs.fold(0, (sum, c) => sum + c.items.length);

// ───────────────────────── صفحة الأدعية ─────────────────────────

class DuasPage extends StatelessWidget {
  const DuasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأدعية')),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [for (final c in kDuas) CategoryTile(c, unit: 'دعاء')],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 2, 22, 8),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// بطاقة قسم (أذكار أو أدعية) بأيقونة جوه دايرة خضرا فاتحة
class CategoryTile extends StatelessWidget {
  const CategoryTile(this.category, {super.key, this.unit = 'ذكر'});

  final DhikrCategory category;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = category;
    return AppCard(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: FaIcon(c.icon, size: 20, color: scheme.primary),
        ),
        title: Text(
          c.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: kInk,
          ),
        ),
        subtitle: Text('${c.hint}، ${arDigits(c.items.length)} $unit'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AdhkarListPage(category: c)),
        ),
      ),
    );
  }
}

// ───────────────────────── صفحة الأذكار مع العدّاد ─────────────────────────

class AdhkarListPage extends StatefulWidget {
  const AdhkarListPage({super.key, required this.category});

  final DhikrCategory category;

  @override
  State<AdhkarListPage> createState() => _AdhkarListPageState();
}

class _AdhkarListPageState extends State<AdhkarListPage> {
  late final List<String> _bodies;
  late List<int> _remaining;

  @override
  void initState() {
    super.initState();
    final items = widget.category.items;
    _bodies = [for (final d in items) d.body];
    _remaining = [for (final d in items) d.count];
  }

  int get _done => _remaining.where((r) => r == 0).length;

  void _tap(int i) {
    if (_remaining[i] == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _remaining[i]--);
    if (_remaining[i] == 0) {
      HapticFeedback.mediumImpact();
      if (_done == _remaining.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تقبّل الله منك، أتممت الأذكار')),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _remaining = [for (final d in widget.category.items) d.count];
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = widget.category.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        actions: [
          IconButton(
            tooltip: 'البدء من جديد',
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: items.isEmpty ? 0 : _done / items.length,
            minHeight: 3,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final d = items[i];
          final done = _remaining[i] == 0;
          return Opacity(
            opacity: done ? 0.5 : 1,
            child: AppCard(
              child: InkWell(
                onTap: () => _tap(i),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    children: [
                      if (d.title != null) ...[
                        Text(
                          d.title!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        _bodies[i],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 2,
                          color: kInk,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            done
                                ? Icons.check_circle
                                : Icons.touch_app_outlined,
                            size: 20,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            done
                                ? 'تم'
                                : 'المتبقي ${arDigits(_remaining[i])} من ${arDigits(d.count)}',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
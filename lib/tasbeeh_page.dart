import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'common.dart';

const List<String> _phrases = [
  'سُبْحَانَ اللَّهِ',
  'الْحَمْدُ لِلَّهِ',
  'اللَّهُ أَكْبَرُ',
  'لَا إِلَهَ إِلَّا اللَّهُ',
  'أَسْتَغْفِرُ اللَّهَ',
  'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
  'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
];

class TasbeehPage extends StatefulWidget {
  const TasbeehPage({super.key});

  @override
  State<TasbeehPage> createState() => _TasbeehPageState();
}

class _TasbeehPageState extends State<TasbeehPage> {
  SharedPreferences? _prefs;
  int _index = 0;
  int _target = 33; // 0 = مفتوح
  List<int> _counts = List<int>.filled(_phrases.length, 0);

  // صوت الضغطة: AudioPool بيشغّل الصوت مع كل ضغطة حتى لو سريعة
  // (ملفات الصوت في assets/adhan)
  AudioPool? _tickPool;
  AudioPool? _donePool;

  @override
  void initState() {
    super.initState();
    _load();
    _initSounds();
  }

  @override
  void dispose() {
    _tickPool?.dispose();
    _donePool?.dispose();
    super.dispose();
  }

  Future<void> _initSounds() async {
    try {
      // يشتغل مع أي صوت تاني (موسيقى مثلاً) من غير ما يقطعه
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
    } catch (e) {
      debugPrint('tasbeeh audio context failed: $e');
    }
    try {
      final tick = await AudioPool.create(
        source: AssetSource('adhan/tick.wav'),
        maxPlayers: 6,
      );
      final done = await AudioPool.create(
        source: AssetSource('adhan/done.wav'),
        maxPlayers: 2,
      );
      if (!mounted) {
        await tick.dispose();
        await done.dispose();
        return;
      }
      _tickPool = tick;
      _donePool = done;
    } catch (e) {
      debugPrint('tasbeeh sound init failed: $e');
    }
  }

  Future<void> _playSound(AudioPool? pool, double volume) async {
    if (pool == null) return;
    try {
      await pool.start(volume: volume);
    } catch (e) {
      debugPrint('tasbeeh sound failed: $e');
    }
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getStringList('tb_counts');
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _index = (p.getInt('tb_index') ?? 0).clamp(0, _phrases.length - 1);
      _target = p.getInt('tb_target') ?? 33;
      if (saved != null && saved.length == _phrases.length) {
        _counts = [for (final s in saved) int.tryParse(s) ?? 0];
      }
    });
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setStringList('tb_counts', [for (final c in _counts) '$c']);
    p.setInt('tb_index', _index);
    p.setInt('tb_target', _target);
  }

  void _tap() {
    setState(() => _counts[_index]++);
    if (_target > 0 && _counts[_index] % _target == 0) {
      HapticFeedback.heavyImpact();
      unawaited(_playSound(_donePool, 0.7)); // اكتملت دورة
    } else {
      HapticFeedback.lightImpact();
      unawaited(_playSound(_tickPool, 0.5)); // ضغطة عادية
    }
    _save();
  }

  void _reset() {
    setState(() => _counts[_index] = 0);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = _counts[_index];
    final ring = _target == 0 || count == 0
        ? 0.0
        : (((count - 1) % _target) + 1) / _target;

    return Scaffold(
      appBar: AppBar(
        title: const Text('السبحة'),
        actions: [
          IconButton(
            tooltip: 'تصفير العدّاد',
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _phrases.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ChoiceChip(
                    label: Text(_phrases[i]),
                    selected: i == _index,
                    onSelected: (_) {
                      setState(() => _index = i);
                      _save();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _phrases[_index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    height: 1.8,
                    color: kInk,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: ring,
                        strokeWidth: 8,
                        backgroundColor: scheme.primaryContainer,
                        color: scheme.primary,
                      ),
                    ),
                    Material(
                      color: kCard,
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _tap,
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(
                            child: Text(
                              arDigits(count),
                              style: TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _target == 0
                    ? 'اضغط على الدائرة للعدّ'
                    : 'الدورات المكتملة: ${arDigits(count ~/ _target)}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: <ButtonSegment<int>>[
                      ButtonSegment(value: 33, label: Text(arDigits(33))),
                      ButtonSegment(value: 100, label: Text(arDigits(100))),
                      const ButtonSegment(value: 0, label: Text('مفتوح')),
                    ],
                    selected: {_target},
                    onSelectionChanged: (s) {
                      setState(() => _target = s.first);
                      _save();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
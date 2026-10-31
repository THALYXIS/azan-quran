import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═════════════════════════════════════════════════════════════
//  التحديث من غير متجر: التطبيق بيسأل GitHub Releases عن آخر إصدار،
//  ولو أحدث من اللي مثبّت بينزّل الـ APK ويفتح شاشة التثبيت.
// ═════════════════════════════════════════════════════════════

/// غيّرها لاسم حسابك واسم الـ repo على GitHub، مثال: 'mohammed123/azan-quran'
const String kUpdateRepo = 'THALYXIS/azan-quran';

class UpdateInfo {
  const UpdateInfo(this.version, this.apkUrl, this.notes);
  final String version;
  final String apkUrl;
  final String notes;
}

class UpdateService {
  UpdateService._();

  static bool get _configured => !kUpdateRepo.startsWith('YOUR_');

  static List<int> _parts(String v) {
    final clean = v
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first;
    return [for (final p in clean.split('.')) int.tryParse(p) ?? 0];
  }

  /// هل [remote] أحدث من [local]؟ (مقارنة x.y.z)
  static bool _isNewer(String remote, String local) {
    final a = _parts(remote);
    final b = _parts(local);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// آخر إصدار منشور على GitHub (أو null لو مفيش إصدار فيه ملف APK)
  static Future<UpdateInfo?> fetchLatest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.getUrl(
        Uri.parse('https://api.github.com/repos/$kUpdateRepo/releases/latest'),
      );
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'azan-quran-app');
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) return null; // لسه مفيش إصدارات
      if (res.statusCode != 200) {
        throw HttpException('status ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?) ?? '';
      final assets = (json['assets'] as List?) ?? const [];
      String? apk;
      for (final a in assets) {
        final m = a as Map<String, dynamic>;
        final name = (m['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apk = m['browser_download_url'] as String?;
          break;
        }
      }
      if (tag.isEmpty || apk == null) return null;
      return UpdateInfo(
        tag.replaceFirst(RegExp(r'^[vV]'), ''),
        apk,
        ((json['body'] as String?) ?? '').trim(),
      );
    } finally {
      client.close();
    }
  }

  static void _toast(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// بتتنادى تلقائي مع فتح التطبيق (مرة كل ٦ ساعات)، أو يدوي من الإعدادات
  static Future<void> checkAndPrompt(BuildContext context,
      {bool manual = false}) async {
    if (!_configured) {
      if (manual) _toast(context, 'مكان التحديثات لسه ما اتضبطش في الكود');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!manual) {
        final last = prefs.getInt('upd_last') ?? 0;
        if (now - last < 6 * 3600 * 1000) return;
      }

      final current = (await PackageInfo.fromPlatform()).version;
      final latest = await fetchLatest();
      await prefs.setInt('upd_last', now);

      if (latest == null || !_isNewer(latest.version, current)) {
        if (manual) _toast(context, 'إنت على آخر إصدار ($current)');
        return;
      }
      if (!context.mounted) return;
      final notes = latest.notes.length > 600
          ? '${latest.notes.substring(0, 600)}…'
          : latest.notes;
      final message = notes.isEmpty
          ? 'الإصدار ${latest.version} متاح (إصدارك الحالي $current).'
          : 'الإصدار ${latest.version} متاح (إصدارك الحالي $current).\n\n$notes';
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تحديث جديد متاح'),
          content: SingleChildScrollView(
            child: Text(message, style: const TextStyle(height: 1.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لاحقًا'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تحديث الآن'),
            ),
          ],
        ),
      );
      if (go == true && context.mounted) await _download(context, latest);
    } catch (e) {
      debugPrint('update check failed: $e');
      if (manual) {
        _toast(context, 'تعذر التحقق من التحديث، اتأكد من الإنترنت وجرّب تاني');
      }
    }
  }

  static Future<void> _download(BuildContext context, UpdateInfo info) async {
    final progress = ValueNotifier<double?>(0);
    final navigator = Navigator.of(context, rootNavigator: true);

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('جارٍ تحميل التحديث'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, v, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: v),
                const SizedBox(height: 12),
                Text(v == null ? '...' : '${(v * 100).round()}%'),
              ],
            ),
          ),
        ),
      ),
    ));

    final file = File('${Directory.systemTemp.path}/azan_quran_update.apk');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      if (await file.exists()) await file.delete();
      final req = await client.getUrl(Uri.parse(info.apkUrl));
      req.headers.set('User-Agent', 'azan-quran-app');
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('status ${res.statusCode}');
      final total = res.contentLength;
      var got = 0;
      final sink = file.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        progress.value = total > 0 ? got / total : null;
      }
      await sink.flush();
      await sink.close();

      navigator.pop(); // نقفل شاشة التحميل
      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done && context.mounted) {
        _toast(
          context,
          'اسمح للتطبيق بتثبيت التطبيقات من إعدادات الموبايل، وبعدها اضغط تحديث تاني',
        );
      }
    } catch (e) {
      debugPrint('update download failed: $e');
      navigator.pop();
      if (context.mounted) {
        _toast(context, 'فشل تحميل التحديث، جرّب تاني بعد شوية');
      }
    } finally {
      client.close();
      progress.dispose();
    }
  }
}
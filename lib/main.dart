import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'adhan_notifications.dart';
import 'adhkar_page.dart';
import 'app_icons.dart';
import 'common.dart';
import 'prayer_page.dart';
import 'quran_page.dart';
import 'settings_page.dart';
import 'tasbeeh_page.dart';
import 'update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdhanService.instance.init();
  runApp(const AzanQuranApp());
}

class AzanQuranApp extends StatelessWidget {
  const AzanQuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF14532D))
        .copyWith(primary: const Color(0xFF0F4A2C), onPrimary: Colors.white);

    return MaterialApp(
      title: 'أذان وقرآن',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: kPaper,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPaper,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: kCard,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      // الواجهة كلها من اليمين لليسار
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // بعد ما الشاشة تظهر نسأل: فيه تحديث جديد؟
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.checkAndPrompt(context);
    });
  }

  static const List<Widget> _pages = [
    PrayerPage(),
    QuranIndexPage(),
    AdhkarPage(),
    TasbeehPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.mosque, size: 20),
            label: 'المواقيت',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.bookQuran, size: 21),
            label: 'المصحف',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.handsPraying, size: 21),
            label: 'الأذكار',
          ),
          NavigationDestination(
            icon: TasbihIcon(size: 26),
            label: 'السبحة',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.gear, size: 20),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
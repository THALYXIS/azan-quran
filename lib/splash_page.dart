import 'package:flutter/material.dart';

import 'common.dart';
import 'main.dart' show RootPage;

/// شاشة البداية: الأيقونة والاسم بحركة خفيفة ثم الدخول للتطبيق
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late final Animation<double> _logoScale = Tween<double>(begin: 0.72, end: 1)
      .animate(CurvedAnimation(
          parent: _c, curve: const Interval(0, 0.6, curve: Curves.easeOutBack)));
  late final Animation<double> _logoFade = CurvedAnimation(
      parent: _c, curve: const Interval(0, 0.45, curve: Curves.easeOut));
  late final Animation<double> _textFade = CurvedAnimation(
      parent: _c, curve: const Interval(0.45, 1, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 2300), _enter);
  }

  void _enter() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const Stack(
          fit: StackFit.expand,
          children: [IslamicBackground(), RootPage()],
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F4A2C),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B3B22), Color(0xFF14653D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Image.asset(
                    'assets/icon/splash_logo.png',
                    width: 190,
                    height: 190,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: _textFade,
                child: Column(
                  children: [
                    const Text(
                      'رفيق المسلم',
                      style: TextStyle(
                        color: kGold,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'الصلاة  •  القرآن  •  الأذكار',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

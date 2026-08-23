import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import 'home_shell.dart';

/// Branded launch splash: your designed full-screen artwork
/// (assets/images/splash.png) fades in, holds, then transitions into
/// the app. Falls back to a composed logo + tagline if the asset is missing.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _timer = Timer(const Duration(milliseconds: 5000), _goToApp);
  }

  void _goToApp() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (BuildContext context, Animation<double> a,
                Animation<double> b) =>
            const HomeShell(),
        transitionsBuilder: (BuildContext context, Animation<double> a,
            Animation<double> b, Widget child) {
          return FadeTransition(opacity: a, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: FadeTransition(
        opacity: _fade,
        child: SizedBox.expand(
          child: Image.asset(
            Platform.isIOS
                ? 'assets/images/splash.png'
                : 'assets/images/splash_android.png',
            fit: BoxFit.contain,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) {
              return const _FallbackSplash();
            },
          ),
        ),
      ),
    );
  }
}

/// Shown only if splash.png is missing — keeps the app launching cleanly.
class _FallbackSplash extends StatelessWidget {
  const _FallbackSplash();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const BrandLogo(width: 300, height: 160),
            const SizedBox(height: 18),
            Text(
              'Write Once. Share Everywhere.',
              style: TextStyle(
                color: AppColors.gold.withValues(alpha: 0.85),
                fontSize: 15,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

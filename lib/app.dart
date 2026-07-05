import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

class OneSocialSuiteApp extends StatelessWidget {
  const OneSocialSuiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '1Social',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}

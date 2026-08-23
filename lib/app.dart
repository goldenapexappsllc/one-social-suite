import 'app_name.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/purchase_service.dart';

class OneSocialSuiteApp extends StatefulWidget {
  const OneSocialSuiteApp({super.key});

  @override
  State<OneSocialSuiteApp> createState() => _OneSocialSuiteAppState();
}

class _OneSocialSuiteAppState extends State<OneSocialSuiteApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Runs once at startup -- also performs the first subscription
    // verification of the session, so re-verification happens even for
    // someone who subscribes once and never revisits the paywall screen.
    PurchaseService.instance.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PurchaseService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check subscription status whenever the app comes back to the
    // foreground -- catches a subscription cancelled or expired while
    // the app was backgrounded, without needing a server to push updates.
    if (state == AppLifecycleState.resumed) {
      PurchaseService.instance.reverifyIfStale();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}

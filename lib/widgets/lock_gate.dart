import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';
import '../screens/lock_screen.dart';

/// Wraps the app. Watches lifecycle: when the app returns to the foreground
/// after being backgrounded, it locks if the idle timeout has passed (and the
/// keyboard isn't open). On launch, locks immediately if enabled.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Lock on launch if the feature is enabled.
    _locked = AppLockService.instance.isEnabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Leaving foreground: stamp the time so idle is measured from now.
      AppLockService.instance.recordActivity();
    } else if (state == AppLifecycleState.resumed) {
      if (!mounted) return;
      if (AppLockService.instance.shouldLock(context)) {
        setState(() => _locked = true);
      }
    }
  }

  void _unlock() => setState(() => _locked = false);

  @override
  Widget build(BuildContext context) {
    // Any tap anywhere counts as activity, resetting the idle timer.
    return Listener(
      onPointerDown: (_) => AppLockService.instance.recordActivity(),
      child: Stack(
        children: <Widget>[
          widget.child,
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _locked
                ? LockScreen(key: const ValueKey(true), onUnlock: _unlock)
                : const SizedBox.shrink(key: ValueKey(false)),
          ),
        ],
      ),
    );
  }
}

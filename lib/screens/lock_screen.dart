import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';

/// Lock screen -- Face ID with automatic iOS passcode fallback.
/// iOS Secure Enclave handles all authentication.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlock});
  final VoidCallback onUnlock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool   _authenticating = false;
  String _errorMsg       = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    if (_authenticating || !mounted) return;
    setState(() {
      _authenticating = true;
      _errorMsg       = '';
    });

    final ok = await AppLockService.instance.authenticate();
    if (!mounted) return;
    setState(() => _authenticating = false);

    if (ok) {
      AppLockService.instance.recordActivity();
      widget.onUnlock();
    } else {
      setState(() =>
          _errorMsg = 'Authentication failed. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const BrandLogo(width: 280, height: 150),
              const SizedBox(height: 44),
              const Icon(Icons.lock_outline,
                  color: AppColors.gold, size: 52),
              const SizedBox(height: 16),
              const Text('1Social is locked',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text(
                'Use Face ID or your iPhone passcode to unlock.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 36),
              if (_errorMsg.isNotEmpty) ...<Widget>[
                Text(_errorMsg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
              ],
              SizedBox(
                width: 260,
                child: ElevatedButton.icon(
                  onPressed: _authenticating ? null : _tryUnlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    disabledBackgroundColor:
                        AppColors.gold.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                  ),
                  icon: const Icon(Icons.face,
                      color: Colors.black, size: 22),
                  label: Text(
                    _authenticating ? 'Unlocking...' : 'Unlock',
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 17),
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

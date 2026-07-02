import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App lock service -- Face ID with iOS device passcode fallback.
/// iOS Secure Enclave handles all biometric security.
/// No custom PIN, no lockout logic, no complexity.
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  static const String _kEnabled = 'lock_enabled';
  static const String _kTimeout = 'lock_timeout_minutes';

  final LocalAuthentication _auth = LocalAuthentication();

  bool _enabled       = false;
  int  _timeoutMinutes = 1;
  DateTime _lastActive = DateTime.now();

  bool get isEnabled      => _enabled;
  int  get timeoutMinutes => _timeoutMinutes;

  Future<void> load() async {
    final prefs     = await SharedPreferences.getInstance();
    _enabled        = prefs.getBool(_kEnabled) ?? false;
    _timeoutMinutes = prefs.getInt(_kTimeout)  ?? 1;
    _lastActive     = DateTime.now();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
    _lastActive = DateTime.now();
  }

  Future<void> setTimeout(int minutes) async {
    _timeoutMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTimeout, minutes);
  }

  void recordActivity() => _lastActive = DateTime.now();

  bool shouldLock(BuildContext context) {
    if (!_enabled) return false;
    final keyboardOpen =
        MediaQuery.of(context).viewInsets.bottom > 0;
    if (keyboardOpen) return false;
    final idle = DateTime.now().difference(_lastActive);
    return idle.inMinutes >= _timeoutMinutes;
  }

  /// Authenticate with Face ID -- iOS automatically falls back
  /// to device passcode if Face ID fails. No custom PIN needed.
  Future<bool> authenticate() async {
    try {
      final bool canCheck =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) return true;
      return await _auth.authenticate(
        localizedReason: 'Unlock 1Social',
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: false, // iOS passcode fallback enabled
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

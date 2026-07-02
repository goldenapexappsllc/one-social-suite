import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _pinKey = 'user_pin';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _appLockEnabledKey = 'app_lock_enabled';

  Future<bool> canUseBiometrics() async => await _localAuth.canCheckBiometrics;

  Future<bool> authenticateWithBiometrics({bool strictFaceID = true}) async {
    try {
      final success = await _localAuth.authenticate(
        localizedReason: 'Unlock 1Social — Face ID required',
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: strictFaceID,
          useErrorDialogs: true,
        ),
      );
      return success;
    } catch (e) {
      return false;
    }
  }

  Future<void> setPin(String pin) async => await _storage.write(key: _pinKey, value: pin);
  Future<bool> verifyPin(String entered) async {
    final stored = await _storage.read(key: _pinKey);
    return stored == entered;
  }
  Future<bool> hasPin() async => await _storage.read(key: _pinKey) != null;

  Future<void> setBiometricEnabled(bool val) async => await _storage.write(key: _biometricEnabledKey, value: val.toString());
  Future<bool> isBiometricEnabled() async => (await _storage.read(key: _biometricEnabledKey)) == 'true';

  Future<void> setAppLockEnabled(bool val) async => await _storage.write(key: _appLockEnabledKey, value: val.toString());
  Future<bool> isAppLockEnabled() async => (await _storage.read(key: _appLockEnabledKey)) != 'false';
}

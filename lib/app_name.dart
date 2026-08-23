import 'dart:io' show Platform;

/// The app ships under two store names from one codebase.
/// Google Play  = 1Social
/// App Store    = 1PrivateSocial
String get kAppName => Platform.isIOS ? '1PrivateSocial' : '1Social';

/// Biometric unlock is called different things on each platform.
String get kBiometricName => Platform.isIOS ? 'Face ID' : 'fingerprint unlock';

/// Device-level passcode wording.
String get kPasscodeName => Platform.isIOS ? 'iPhone passcode' : 'screen lock';

/// The OS, when it has to be named.
String get kOsName => Platform.isIOS ? 'iOS' : 'Android';

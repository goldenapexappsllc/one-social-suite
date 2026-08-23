import 'package:shared_preferences/shared_preferences.dart';

/// Tracks user consent for the AI Assist feature (OpenAI-powered caption
/// enhancement).
///
/// Versioned so that if the disclosure copy ever changes in a way that
/// materially affects what the user is agreeing to, bumping
/// [currentConsentVersion] automatically re-prompts every existing user —
/// nobody silently carries forward consent to language they never saw.
class AiConsentService {
  AiConsentService._();
  static final AiConsentService instance = AiConsentService._();

  /// Bump this any time the consent dialog's wording changes materially.
  static const int currentConsentVersion = 1;

  static const _keyConsentVersion = 'ai_consent_version';
  static const _keyConsentDate = 'ai_consent_date';

  /// True only if the user has accepted the *current* version of the
  /// consent copy. Returns false for new users and for anyone who
  /// accepted an older version that's since been superseded.
  Future<bool> hasCurrentConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_keyConsentVersion) ?? 0;
    return storedVersion >= currentConsentVersion;
  }

  Future<void> recordConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyConsentVersion, currentConsentVersion);
    await prefs.setString(_keyConsentDate, DateTime.now().toIso8601String());
  }

  /// Not currently wired to any UI — available if you ever want a
  /// "reset AI consent" option buried in Settings.
  Future<void> revokeConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyConsentVersion);
    await prefs.remove(_keyConsentDate);
  }
}

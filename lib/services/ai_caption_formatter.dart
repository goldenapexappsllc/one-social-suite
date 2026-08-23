import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/platform_def.dart';
import '../models/tone.dart';

/// AI-powered caption formatter, routed through GoldenApexApps LLC's
/// own proxy rather than calling OpenAI directly. The app never holds
/// a real OpenAI key -- only a proxy URL and an app-only shared secret.
///
/// Implements the same contract as RulesCaptionFormatter so it drops in
/// with zero UI changes. On any error, returns an empty string so the
/// caller can fall back to the rules engine.
class AICaptionFormatter {
  const AICaptionFormatter();

  static const String _proxyUrl = String.fromEnvironment(
    'AI_PROXY_URL',
    defaultValue: '',
  );

  static const String _appSharedSecret = String.fromEnvironment(
    'APP_SHARED_SECRET',
    defaultValue: '',
  );

  bool get isConfigured => _proxyUrl.isNotEmpty && _appSharedSecret.isNotEmpty;

  Future<String> formatAsync(
      String text, PlatformDef platform, Tone tone,
      {String? targetLanguage}) async {
    if (!isConfigured || text.trim().isEmpty) return '';

    final String prompt = _buildPrompt(text, platform, tone, targetLanguage);
    const String systemMessage =
        'You are a social media copywriter. Rewrite the message for a specific '
        'platform. If a target language is specified, write the rewritten '
        'caption entirely in that language -- otherwise keep the same '
        'language as the original message. Return ONLY the rewritten '
        'caption: no quotes, no preamble, no notes.';

    try {
      final http.Response res = await http
          .post(
            Uri.parse(_proxyUrl),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'x-app-secret': _appSharedSecret,
            },
            body: jsonEncode(<String, String>{
              'systemMessage': systemMessage,
              'prompt': prompt,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) return '';
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> choices =
          data['choices'] as List<dynamic>? ?? <dynamic>[];
      if (choices.isEmpty) return '';
      final Map<String, dynamic> msg =
          (choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>;
      final String out = (msg['content'] as String? ?? '').trim();
      if (out.length > platform.charLimit) {
        return out.substring(0, platform.charLimit);
      }
      return out;
    } catch (_) {
      return '';
    }
  }

  String _buildPrompt(
      String text, PlatformDef p, Tone tone, String? targetLanguage) {
    final String style = switch (p.id) {
      'x' => 'short, sharp, max 280 characters, at most 2 hashtags',
      'linkedin' =>
        'professional and polished, no emoji spam, expand contractions',
      'instagram' => 'visual and emotional, with a hashtag block at the end',
      'pinterest' => 'keyword-rich and descriptive, search-friendly',
      'nextdoor' => 'local, friendly, community-focused, no hashtags',
      'tiktok' => 'short, catchy, trend-aware energy',
      'facebook' => 'personal and conversational',
      'snapchat' => 'very short and casual',
      _ => 'clear and engaging',
    };
    final String languageLine = (targetLanguage != null &&
            targetLanguage.trim().isNotEmpty)
        ? 'Target language: $targetLanguage -- write the rewritten caption '
            'entirely in this language, regardless of the language the '
            'original message was written in.\n'
        : '';

    return 'Platform: ${p.name}\n'
        'Tone: ${tone.label}\n'
        'Style guidance: $style\n'
        '$languageLine'
        'Keep it under ${p.charLimit} characters.\n\n'
        'Message to rewrite:\n$text';
  }
}

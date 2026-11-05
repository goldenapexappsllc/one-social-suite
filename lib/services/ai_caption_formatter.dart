import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/platform_def.dart';
import '../models/tone.dart';
import 'purchase_service.dart';

/// AI-powered caption formatter, routed through GoldenApexApps LLC's
/// own proxy rather than calling OpenAI directly. The app never holds
/// a real OpenAI key -- only a proxy URL and an app-only shared secret.
///
/// Every request also carries the subscriber's purchase proof, so the
/// proxy can verify the subscription with Apple/Google and keep the
/// usage count server-side. The proxy's numbers come back in response
/// headers and are handed to PurchaseService.
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

  /// Short reason for the most recent failed AI call, or null if the last
  /// call worked. Codes: not_configured, timeout, http_STATUS,
  /// subscription_inactive, empty_reply, bad_reply, network_error.
  static String? lastFailure;

  static void _log(String m) {
    if (kDebugMode) debugPrint('[AI] $m');
  }

  bool get isConfigured => _proxyUrl.isNotEmpty && _appSharedSecret.isNotEmpty;

  Future<String> formatAsync(
      String text, PlatformDef platform, Tone tone,
      {String? targetLanguage}) async {
    if (!isConfigured) {
      lastFailure = 'not_configured';
      _log('not configured (proxy url or secret missing from this build)');
      return '';
    }
    if (text.trim().isEmpty) return '';

    final String prompt = _buildPrompt(text, platform, tone, targetLanguage);
    const String systemMessage =
        'You are a social media copywriter. Rewrite the message for a specific '
        'platform. If a target language is specified, write the rewritten '
        'caption entirely in that language -- otherwise keep the same '
        'language as the original message. Return ONLY the rewritten '
        'caption: no quotes, no preamble, no notes.';

    try {
      final Map<String, String> headers = <String, String>{
        'Content-Type': 'application/json',
        'x-app-secret': _appSharedSecret,
      };
      // Purchase proof + platform, if this device has a stored purchase.
      headers.addAll(await PurchaseService.instance.serverHeaders());

      final Stopwatch sw = Stopwatch()..start();
      final http.Response res = await http
          .post(
            Uri.parse(_proxyUrl),
            headers: headers,
            body: jsonEncode(<String, String>{
              'systemMessage': systemMessage,
              'prompt': prompt,
            }),
          )
          .timeout(const Duration(seconds: 20));
      sw.stop();

      // The proxy reports the real remaining counts in response headers
      // (on success and on a 429 limit-reached alike).
      final bool hadMeter =
          await PurchaseService.instance.applyServerMeter(res.headers);

      _log('${platform.id}: status ${res.statusCode} in '
          '${sw.elapsedMilliseconds} ms, meter headers: $hadMeter '
          '(monthly=${res.headers['x-ai-monthly-left']}, '
          'bonus=${res.headers['x-ai-bonus-left']})');

      if (res.statusCode == 402) {
        try {
          final dynamic j = jsonDecode(res.body);
          if (j is Map && j['error'] == 'subscription_inactive') {
            _log('server says subscription_inactive');
            lastFailure = 'subscription_inactive';
            await PurchaseService.instance.handleSubscriptionInactive();
            return '';
          }
        } catch (_) {}
        lastFailure = 'http_402';
        return '';
      }

      if (res.statusCode != 200) {
        String word = '';
        try {
          final dynamic j = jsonDecode(res.body);
          if (j is Map && j['error'] is String) {
            word = j['error'] as String;
            if (word.length > 60) word = word.substring(0, 60);
          }
        } catch (_) {}
        _log('failed: http_${res.statusCode}${word.isEmpty ? '' : ' ($word)'}');
        lastFailure = 'http_${res.statusCode}';
        return '';
      }

      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> choices =
          data['choices'] as List<dynamic>? ?? <dynamic>[];
      if (choices.isEmpty) {
        _log('failed: empty_reply (no choices)');
        lastFailure = 'empty_reply';
        return '';
      }
      final Map<String, dynamic> msg =
          (choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>;
      final String out = (msg['content'] as String? ?? '').trim();
      if (out.isEmpty) {
        _log('failed: empty_reply (blank content)');
        lastFailure = 'empty_reply';
        return '';
      }

      // The server already counted this call, so the local counter must
      // not count it a second time.
      if (hadMeter) PurchaseService.instance.noteServerCountedCall();

      lastFailure = null;
      if (out.length > platform.charLimit) {
        return out.substring(0, platform.charLimit);
      }
      return out;
    } on TimeoutException {
      _log('failed: timeout after 20 s');
      lastFailure = 'timeout';
      return '';
    } on FormatException {
      _log('failed: bad_reply (response was not valid JSON)');
      lastFailure = 'bad_reply';
      return '';
    } catch (e) {
      _log('failed: network_error (${e.runtimeType})');
      lastFailure = 'network_error';
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

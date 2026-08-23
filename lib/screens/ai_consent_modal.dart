import 'package:flutter/material.dart';
import 'ai_consent.dart';

/// Shown the first time a user tries to turn AI Assist on — and again
/// automatically for existing users if [AiConsentService.currentConsentVersion]
/// is ever bumped.
///
/// Returns `true` if the user tapped "Enable AI Assist" (consent recorded),
/// or `false` if they dismissed it or tapped "Not Now" (AI Assist stays off).
Future<bool> showAiConsentModal(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.amber, width: 0.5),
      ),
      title: const Row(
        children: [
          Icon(Icons.auto_fix_high, color: Colors.amber, size: 22),
          SizedBox(width: 8),
          Text('About AI Assist', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: const Text(
        'AI Assist uses OpenAI to help enhance your post captions. '
        'When you use this feature, the text you submit is sent to '
        "OpenAI's API to generate a response — this is the only time "
        'any of your content leaves your device.\n\n'
        'AI-generated suggestions may contain errors or inaccuracies. '
        'Always review your post before submitting it, to make sure '
        'your statement is represented the way you intend.\n\n'
        'This feature is entirely optional and off by default.',
        style: TextStyle(color: Colors.white70, height: 1.4, fontSize: 13.5),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not Now', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          onPressed: () async {
            await AiConsentService.instance.recordConsent();
            if (context.mounted) Navigator.of(context).pop(true);
          },
          child: const Text('I Understand, Enable AI Assist'),
        ),
      ],
    ),
  );
  return accepted ?? false;
}

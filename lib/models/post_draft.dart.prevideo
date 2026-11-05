import 'tone.dart';

/// The single object that flows Composer -> Formatter -> Share.
class PostDraft {
  const PostDraft({
    required this.text,
    required this.selectedPlatformIds,
    required this.tone,
    this.mediaPath,
    this.isVideo = false,
    this.useAi = false,
    this.targetLanguage,
  });

  final String text;
  final Set<String> selectedPlatformIds;
  final Tone tone;
  final String? mediaPath;
  final bool isVideo;
  final bool useAi;

  /// Null means "write in whatever language the original text is in."
  /// Set only when the user explicitly picks a target language for AI
  /// Assist to translate into.
  final String? targetLanguage;

  bool get hasMedia => mediaPath != null;
}

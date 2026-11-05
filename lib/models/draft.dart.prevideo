import '../models/tone.dart';

/// A saved draft post. Stored locally in Hive as a plain map (no codegen).
class Draft {
  Draft({
    required this.id,
    required this.text,
    required this.selectedPlatformIds,
    required this.tone,
    this.mediaPath,
    this.isVideo = false,
    required this.createdAt,
    required this.editedAt,
  });

  final String id;
  final String text;
  final List<String> selectedPlatformIds;
  final Tone tone;
  final String? mediaPath;
  final bool isVideo;
  final DateTime createdAt;
  final DateTime editedAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'text': text,
        'platforms': selectedPlatformIds,
        'tone': tone.name,
        'mediaPath': mediaPath,
        'isVideo': isVideo,
        'createdAt': createdAt.toIso8601String(),
        'editedAt': editedAt.toIso8601String(),
      };

  static Draft fromMap(Map<dynamic, dynamic> m) => Draft(
        id: m['id'] as String,
        text: m['text'] as String? ?? '',
        selectedPlatformIds:
            (m['platforms'] as List<dynamic>? ?? <dynamic>[])
                .map((e) => e.toString())
                .toList(),
        tone: Tone.values.firstWhere(
          (t) => t.name == (m['tone'] as String? ?? 'casual'),
          orElse: () => Tone.casual,
        ),
        mediaPath: m['mediaPath'] as String?,
        isVideo: m['isVideo'] as bool? ?? false,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
        editedAt: DateTime.tryParse(m['editedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  String get preview {
    final String t = text.trim();
    if (t.isEmpty) return '(empty draft)';
    return t.length <= 60 ? t : '${t.substring(0, 60)}...';
  }
}

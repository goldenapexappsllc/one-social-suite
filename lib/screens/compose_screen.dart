import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/platform_def.dart';
import '../models/platform_registry.dart';
import '../models/platform_suggestion.dart';
import '../models/post_draft.dart';
import '../models/tone.dart';
import '../services/platform_suggester.dart';
import '../theme/app_theme.dart';
import '../models/draft.dart';
import '../services/storage_service.dart';
import 'ai_consent.dart';
import 'ai_consent_modal.dart';
import 'preview_screen.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key, this.initialDraft});

  final Draft? initialDraft;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  static const PlatformSuggester _suggester = RuleBasedPlatformSuggester();
  static const Color _warn = Color(0xFFFF8A3D);

  final TextEditingController _text = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final Set<String> _selected = <String>{};
  final FocusNode _textFocus = FocusNode();

  Tone _tone = Tone.casual;
  bool _useAi = false;
  String? _mediaPath;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    final Draft? d = widget.initialDraft;
    if (d != null) {
      _text.text = d.text;
      _selected.addAll(d.selectedPlatformIds);
      _tone = d.tone;
      _mediaPath = d.mediaPath;
      _isVideo = d.isVideo;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  int get _wordCount =>
      _text.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  bool get _allSelected => _selected.length == PlatformRegistry.count;

  PlatformSuggestion get _suggestion => _suggester.suggest(PostDraft(
        text: _text.text,
        selectedPlatformIds: _selected,
        tone: _tone,
        mediaPath: _mediaPath,
        isVideo: _isVideo,
      ));

  void _toggle(String id) => setState(() {
        _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      });

  void _toggleAll() => setState(() {
        if (_allSelected) {
          _selected.clear();
        } else {
          _selected
            ..clear()
            ..addAll(PlatformRegistry.all.map((p) => p.id));
        }
      });


  Future<void> _pickMedia() async {
    _dismissKeyboard();
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_outlined, color: AppColors.gold),
              title: const Text('Photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.videocam_outlined, color: AppColors.gold),
              title: const Text('Video', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final XFile? file = choice == 'photo'
        ? await _picker.pickImage(source: ImageSource.gallery)
        : await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      _mediaPath = file.path;
      _isVideo = choice == 'video';
    });
  }

  void _removeMedia() => setState(() {
        _mediaPath = null;
        _isVideo = false;
      });

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _saveDraft() async {
    _dismissKeyboard();
    if (_text.text.trim().isEmpty) {
      _toast('Write something first.');
      return;
    }
    final DateTime now = DateTime.now();
    final Draft d = Draft(
      id: now.microsecondsSinceEpoch.toString(),
      text: _text.text,
      selectedPlatformIds: _selected.toList(),
      tone: _tone,
      mediaPath: _mediaPath,
      isVideo: _isVideo,
      createdAt: now,
      editedAt: now,
    );
    await StorageService.instance.saveDraft(d);
    if (!mounted) return;
    _toast('Draft saved');
  }

  void _openPreview() {
    _dismissKeyboard();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreviewScreen(
          draft: PostDraft(
            text: _text.text,
            selectedPlatformIds: _selected,
            tone: _tone,
            mediaPath: _mediaPath,
            isVideo: _isVideo,
            useAi: _useAi,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int len = _text.text.trim().length;
    final List<PlatformDef> selectedDefs =
        PlatformRegistry.all.where((p) => _selected.contains(p.id)).toList();
    final bool showSuggestion = _wordCount >= 10;
    final PlatformSuggestion sug = _suggestion;

    return Container(
      color: AppColors.black,
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismissKeyboard,
          child: Column(
            children: <Widget>[
              // Keyboard "Done" bar (only while typing)
              if (_textFocus.hasFocus)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12, top: 4),
                    child: TextButton(
                      onPressed: _dismissKeyboard,
                      child: const Text('Done',
                          style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Center(
                        child: Text(
                          'Compose',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Center(
                        child: Text(
                          'Write Once. Share Everywhere.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _label('Your message'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: TextField(
                          controller: _text,
                          focusNode: _textFocus,
                          maxLines: 6,
                          minLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          onTap: () => setState(() {}),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          cursorColor: AppColors.gold,
                          decoration: const InputDecoration.collapsed(
                            hintText: 'Check out my new project...',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        '$len characters',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13),
                      ),
                      if (selectedDefs.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedDefs.map((p) {
                            final bool fits = len <= p.charLimit;
                            return _fitPill(p.name, fits);
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 22),

                      _label('Add media'),
                      const SizedBox(height: 8),
                      if (_mediaPath == null)
                        _outlineButton(
                          icon: Icons.add_photo_alternate_outlined,
                          text: 'Add photo / video',
                          onTap: _pickMedia,
                        )
                      else
                        _mediaPreview(),
                      const SizedBox(height: 22),

                      _label('Tone'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: Tone.values.map((t) {
                          return _chip(
                            label: t.label,
                            selected: _tone == t,
                            onTap: () => setState(() => _tone = t),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),

                      // --- AI Assist (BETA) ---
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.auto_awesome,
                            color: AppColors.gold, size: 18),
                        const SizedBox(width: 8),
                        const Text('AI Assist',
                            style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('BETA',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        Switch(
                          value: _useAi,
                          onChanged: (bool v) async {
                            if (v) {
                              final bool hasConsent = await AiConsentService
                                  .instance
                                  .hasCurrentConsent();
                              if (!hasConsent) {
                                if (!context.mounted) return;
                                final bool accepted =
                                    await showAiConsentModal(context);
                                if (!accepted) return;
                              }
                            }
                            setState(() => _useAi = v);
                          },
                          activeThumbColor: AppColors.gold,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _useAi
                          ? 'Your text is sent to OpenAI to enhance each caption.'
                          : 'Off. Captions are shaped on your device only.',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _label('Share to'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _chip(
                            label: 'All',
                            selected: _allSelected,
                            onTap: _toggleAll,
                            emphasize: true,
                          ),
                          ...PlatformRegistry.all.map((p) => _chip(
                                label: p.name,
                                selected: _selected.contains(p.id),
                                onTap: () => _toggle(p.id),
                              )),
                        ],
                      ),
                      const SizedBox(height: 22),

                      if (showSuggestion && !sug.isEmpty) _suggestionCard(sug),

                      const SizedBox(height: 24),

                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saveDraft,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.gold),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Save Draft',
                                  style: TextStyle(color: AppColors.gold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _selected.isEmpty ? null : _openPreview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                disabledBackgroundColor:
                                    AppColors.gold.withValues(alpha: 0.3),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Next',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(
        t,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _fitPill(String name, bool fits) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: fits ? AppColors.border : _warn.withValues(alpha: 0.6)),
        ),
        child: Text(
          fits ? 'OK $name' : '$name will be trimmed',
          style: TextStyle(
            color: fits ? AppColors.gold : _warn,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool emphasize = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.16)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.gold : Colors.white,
              fontWeight:
                  (selected || emphasize) ? FontWeight.w700 : FontWeight.w400,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: AppColors.gold, size: 22),
              const SizedBox(width: 10),
              Text(text, style: const TextStyle(color: AppColors.gold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaPreview() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _isVideo
                ? Container(
                    width: 56,
                    height: 56,
                    color: AppColors.black,
                    child: const Icon(Icons.videocam,
                        color: AppColors.gold, size: 28),
                  )
                : Image.file(
                    File(_mediaPath!),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object error,
                            StackTrace? stack) =>
                        const Icon(Icons.broken_image,
                            color: AppColors.textMuted),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isVideo ? 'Video attached' : 'Photo attached',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textMuted),
            onPressed: _removeMedia,
          ),
        ],
      ),
    );
  }

  Widget _suggestionCard(PlatformSuggestion sug) {
    final List<PlatformDef> recs = sug.recommendedIds
        .map((id) => PlatformRegistry.byId(id))
        .whereType<PlatformDef>()
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: const <Widget>[
              Icon(Icons.auto_awesome, color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Text(
                'Smart Suggestion',
                style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Recommended:',
              style: TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 6),
          ...recs.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('- ${p.name}',
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              )),

          if (sug.reasons.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            const Text('Why?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...sug.reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('- $r',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
                )),
          ],
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/draft.dart';
import '../models/platform_registry.dart';
import '../models/tone.dart';
import '../models/video_item.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'compose_screen.dart';
import 'storage_screen.dart';
import 'trash_screen.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _warn = Color(0xFFFF8A3D);

  List<Draft> _drafts = <Draft>[];
  List<VideoItem> _videos = <VideoItem>[];
  int _trashCount = 0;
  int _videoBytes = 0;

  VideoItem? _undoItem;
  late final AnimationController _undoCtl;

  @override
  void initState() {
    super.initState();
    _undoCtl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((AnimationStatus s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _undoItem = null);
        }
      });
    _load();
  }

  @override
  void dispose() {
    _undoCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await StorageService.instance.syncVideos();
    await StorageService.instance.purgeExpiredTrash();
    if (!mounted) return;
    _refresh();
  }

  void _refresh() {
    final StorageService s = StorageService.instance;
    setState(() {
      _drafts = s.getDrafts();
      _videos = s.getVideos();
      _trashCount = s.getTrashedVideos().length;
      _videoBytes = s.videoBytes;
    });
  }

  Future<void> _delete(Draft d) async {
    setState(() => _drafts.removeWhere((Draft x) => x.id == d.id));
    await StorageService.instance.deleteDraft(d.id);
    _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Draft deleted')));
  }

  Future<void> _openCompose(Draft d, String title) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF000000),
          appBar: AppBar(
            title: Text(title),
            backgroundColor: const Color(0xFF000000),
            foregroundColor: const Color(0xFFF5CC1F),
          ),
          body: ComposeScreen(initialDraft: d),
        ),
      ),
    );
    _load();
  }

  Future<void> _openInPreview(Draft d) => _openCompose(d, 'Edit Draft');

  Future<void> _newPostWithVideo(VideoItem v) {
    final DateTime now = DateTime.now();
    final Draft d = Draft(
      id: now.microsecondsSinceEpoch.toString(),
      text: '',
      selectedPlatformIds: <String>[],
      tone: Tone.casual,
      mediaPath: StorageService.instance.fileFor(v).path,
      isVideo: true,
      videoName: v.name,
      videoSeconds: v.seconds,
      createdAt: now,
      editedAt: now,
    );
    return _openCompose(d, 'New Post');
  }

  Future<void> _openTrash() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TrashScreen()),
    );
    _load();
  }

  Future<void> _openStorage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const StorageScreen()),
    );
    _load();
  }

  Future<void> _trashVideo(VideoItem v) async {
    await StorageService.instance.trashVideo(v.fileName);
    _refresh();
    if (!mounted) return;
    setState(() => _undoItem = v);
    _undoCtl.forward(from: 0);
  }

  Future<void> _undo() async {
    final VideoItem? v = _undoItem;
    if (v == null) return;
    _undoCtl.stop();
    setState(() => _undoItem = null);
    await StorageService.instance.restoreVideo(v.fileName);
    _refresh();
  }

  Future<void> _renameVideo(VideoItem v) async {
    final TextEditingController c = TextEditingController(text: v.name);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename video',
            style: TextStyle(color: AppColors.gold)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppColors.gold,
          decoration: const InputDecoration(
            hintText: 'Video name',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Save', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    c.dispose();
    if (result == null) return;
    await StorageService.instance.renameVideo(v.fileName, result);
    _refresh();
  }

  String _platformSummary(Draft d) {
    final List<String> names = d.selectedPlatformIds
        .map((id) => PlatformRegistry.byId(id)?.name)
        .whereType<String>()
        .toList();
    if (names.isEmpty) return 'No platforms';
    if (names.length <= 3) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2} more';
  }

  String _subtitle() {
    if (_drafts.isEmpty && _videos.isEmpty) return 'Saved locally on your device';
    final List<String> parts = <String>[];
    if (_drafts.isNotEmpty) {
      parts.add('${_drafts.length} ${_drafts.length == 1 ? "draft" : "drafts"}');
    }
    if (_videos.isNotEmpty) {
      parts.add('${_videos.length} ${_videos.length == 1 ? "video" : "videos"}');
    }
    return parts.join('  -  ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.black,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Column(
              children: <Widget>[
                const SizedBox(height: 8),
                _header(),
                const SizedBox(height: 4),
                Text(
                  _subtitle(),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: (_drafts.isEmpty && _videos.isEmpty)
                      ? _empty()
                      : _list(),
                ),
              ],
            ),
            if (_undoItem != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _undoBar(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: <Widget>[
        const SizedBox(width: 96),
        const Expanded(
          child: Center(
            child: Text(
              'Drafts',
              style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                tooltip: 'Trash',
                onPressed: _openTrash,
                icon: Badge(
                  isLabelVisible: _trashCount > 0,
                  label: Text('$_trashCount'),
                  backgroundColor: AppColors.gold,
                  textColor: AppColors.black,
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.gold),
                ),
              ),
              IconButton(
                tooltip: 'Storage',
                onPressed: _openStorage,
                icon: const Icon(Icons.sd_storage_outlined,
                    color: AppColors.gold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _undoBar() {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text('Video moved to Trash',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                  TextButton(
                    onPressed: _undo,
                    child: const Text('Undo',
                        style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _undoCtl,
              builder: (BuildContext context, Widget? child) =>
                  LinearProgressIndicator(
                value: 1 - _undoCtl.value,
                minHeight: 3,
                backgroundColor: Colors.transparent,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 2),
              ),
              child: const Icon(Icons.drafts_outlined,
                  color: AppColors.gold, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('No drafts yet',
                style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Write a post in Compose and tap Save Draft. Your drafts and videos stay on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(
          t,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      );

  Widget _reminderBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openStorage,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.sd_storage_outlined,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your videos are using ${formatBytes(_videoBytes)}. Tap to manage storage.',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _list() {
    final bool showReminder =
        StorageService.instance.storageReminder && _videoBytes > kReminderBytes;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      children: <Widget>[
        if (showReminder) _reminderBanner(),
        if (_drafts.isNotEmpty) ...<Widget>[
          _sectionLabel('Drafts'),
          ..._drafts.map((Draft d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _draftCard(d),
              )),
        ],
        if (_videos.isNotEmpty) ...<Widget>[
          _sectionLabel('Videos'),
          ..._videos.map((VideoItem v) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _videoCard(v),
              )),
        ],
      ],
    );
  }

  Widget _videoCard(VideoItem v) {
    final List<String> bits = <String>[
      if (v.seconds != null) formatLength(v.seconds!),
      formatBytes(v.bytes),
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _newPostWithVideo(v),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.videocam,
                    color: AppColors.gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      v.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${bits.join('  -  ')}  -  tap to post',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surfaceAlt,
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                onSelected: (String choice) {
                  if (choice == 'rename') _renameVideo(v);
                  if (choice == 'trash') _trashVideo(v);
                },
                itemBuilder: (BuildContext ctx) =>
                    <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'rename',
                    child: Text('Rename',
                        style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem<String>(
                    value: 'trash',
                    child: Text('Delete video',
                        style: TextStyle(color: _warn)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _draftCard(Draft d) {
    final bool videoMissing = d.isVideo &&
        d.mediaPath != null &&
        !File(d.mediaPath!).existsSync();
    return Dismissible(
      key: ValueKey<String>(d.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF3A1212),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFFF8A3D)),
      ),
      onDismissed: (_) => _delete(d),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openInPreview(d),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (d.mediaPath != null) ...<Widget>[
                      Icon(
                        d.isVideo
                            ? Icons.videocam_outlined
                            : Icons.image_outlined,
                        color: AppColors.gold,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        d.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                if (d.isVideo &&
                    ((d.videoName ?? '').isNotEmpty || videoMissing))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      videoMissing
                          ? 'Video no longer on this phone'
                          : 'Video: ${d.videoName}',
                      style: TextStyle(
                        color: videoMissing ? _warn : AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    const Icon(Icons.hub_outlined,
                        color: AppColors.textMuted, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _platformSummary(d),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        d.tone.label,
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

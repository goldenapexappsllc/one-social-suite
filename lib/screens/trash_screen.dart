import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  static const Color _warn = Color(0xFFFF8A3D);

  List<VideoItem> _items = <VideoItem>[];
  bool _auto = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await StorageService.instance.purgeExpiredTrash();
    if (!mounted) return;
    _refresh();
  }

  void _refresh() {
    setState(() {
      _items = StorageService.instance.getTrashedVideos();
      _auto = StorageService.instance.autoEmptyTrash;
    });
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.gold)),
        content: Text(body,
            style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: _warn)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _restore(VideoItem v) async {
    await StorageService.instance.restoreVideo(v.fileName);
    _refresh();
  }

  Future<void> _deleteForever(VideoItem v) async {
    final bool ok = await _confirm(
      'Are you sure?',
      '"${v.name}" will be deleted for good. It can\'t be recovered.',
      'Delete forever',
    );
    if (!ok) return;
    await StorageService.instance.deleteVideoForever(v.fileName);
    _refresh();
  }

  Future<void> _emptyAll() async {
    final bool ok = await _confirm(
      'Empty Trash?',
      'All ${_items.length} ${_items.length == 1 ? "video" : "videos"} in Trash will be deleted for good.',
      'Empty Trash',
    );
    if (!ok) return;
    await StorageService.instance.emptyTrash();
    _refresh();
  }

  String _daysLeft(VideoItem v) {
    if (!_auto) return 'Stays in Trash until you empty it';
    final int used = DateTime.now().difference(v.trashedAt!).inDays;
    final int left = (kTrashDays - used).clamp(0, kTrashDays);
    if (left == 0) return 'Deletes today';
    return 'Deletes in $left ${left == 1 ? "day" : "days"}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Trash'),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.gold,
        actions: <Widget>[
          TextButton(
            onPressed: _items.isEmpty ? null : _emptyAll,
            child: Text(
              'Empty',
              style: TextStyle(
                color: _items.isEmpty ? AppColors.textMuted : _warn,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              _auto
                  ? 'Videos in Trash are deleted for good after $kTrashDays days. You can change this in Storage.'
                  : 'Videos stay in Trash until you empty it. You can change this in Storage.',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13, height: 1.4),
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('Trash is empty',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 15)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int i) =>
                        _card(_items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(VideoItem v) {
    final List<String> bits = <String>[
      if (v.seconds != null) formatLength(v.seconds!),
      formatBytes(v.bytes),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
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
              const Icon(Icons.videocam, color: AppColors.gold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  v.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${bits.join('  -  ')}  -  ${_daysLeft(v)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: () => _restore(v),
                icon: const Icon(Icons.restore,
                    color: AppColors.gold, size: 18),
                label: const Text('Restore',
                    style: TextStyle(color: AppColors.gold)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _deleteForever(v),
                icon: const Icon(Icons.delete_forever_outlined,
                    color: _warn, size: 18),
                label:
                    const Text('Delete forever', style: TextStyle(color: _warn)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

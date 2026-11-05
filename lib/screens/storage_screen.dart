import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'trash_screen.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  static const Color _warn = Color(0xFFFF8A3D);

  int _videoCount = 0;
  int _videoBytes = 0;
  int _trashCount = 0;
  int _trashBytes = 0;
  bool _auto = true;
  bool _reminder = true;

  @override
  void initState() {
    super.initState();
    _load();
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
      _videoCount = s.getVideos().length;
      _videoBytes = s.videoBytes;
      _trashCount = s.getTrashedVideos().length;
      _trashBytes = s.trashBytes;
      _auto = s.autoEmptyTrash;
      _reminder = s.storageReminder;
    });
  }

  Future<void> _setAuto(bool v) async {
    await StorageService.instance.setAutoEmptyTrash(v);
    if (v) await StorageService.instance.purgeExpiredTrash();
    _refresh();
  }

  Future<void> _setReminder(bool v) async {
    await StorageService.instance.setStorageReminder(v);
    _refresh();
  }

  Future<void> _openTrash() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TrashScreen()),
    );
    _refresh();
  }

  Future<void> _emptyNow() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title:
            const Text('Empty Trash?', style: TextStyle(color: AppColors.gold)),
        content: const Text(
          'Everything in Trash will be deleted for good.',
          style: TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty Trash', style: TextStyle(color: _warn)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await StorageService.instance.emptyTrash();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Storage'),
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.gold,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _card(<Widget>[
            _row('Videos', '$_videoCount  -  ${formatBytes(_videoBytes)}'),
            _row('Trash', '$_trashCount  -  ${formatBytes(_trashBytes)}'),
            _row('Total',
                formatBytes(_videoBytes + _trashBytes)),
            const SizedBox(height: 4),
            const Text(
              'Videos stay on this phone. Nothing is uploaded.',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
            ),
          ]),
          const SizedBox(height: 16),
          _card(<Widget>[
            _switchRow(
              'Empty Trash after $kTrashDays days',
              _auto
                  ? 'Videos in Trash are deleted for good after $kTrashDays days.'
                  : 'Videos stay in Trash until you empty it.',
              _auto,
              _setAuto,
            ),
            const Divider(color: AppColors.border, height: 24),
            _switchRow(
              'Storage reminder',
              'Show a reminder on Drafts when your videos use more than 1 GB.',
              _reminder,
              _setReminder,
            ),
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _openTrash,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.gold),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.delete_outline, color: AppColors.gold),
            label: const Text('Open Trash',
                style: TextStyle(color: AppColors.gold)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _trashCount == 0 ? null : _emptyNow,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: _trashCount == 0 ? AppColors.border : _warn),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: Icon(Icons.delete_forever_outlined,
                color: _trashCount == 0 ? AppColors.textMuted : _warn),
            label: Text('Empty Trash now',
                style: TextStyle(
                    color: _trashCount == 0 ? AppColors.textMuted : _warn)),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 14)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _switchRow(
    String title,
    String body,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(body,
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        height: 1.4)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.gold,
          ),
        ],
      );
}

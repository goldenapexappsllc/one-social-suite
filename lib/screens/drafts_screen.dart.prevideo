import 'package:flutter/material.dart';
import '../models/draft.dart';
import '../models/platform_registry.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'compose_screen.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  List<Draft> _drafts = <Draft>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _drafts = StorageService.instance.getDrafts());

  Future<void> _delete(Draft d) async {
    await StorageService.instance.deleteDraft(d.id);
    _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Draft deleted')));
  }

  Future<void> _openInPreview(Draft d) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF000000),
          appBar: AppBar(
            title: const Text('Edit Draft'),
            backgroundColor: const Color(0xFF000000),
            foregroundColor: const Color(0xFFF5CC1F),
          ),
          body: ComposeScreen(initialDraft: d),
        ),
      ),
    );
    _load();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.black,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 14),
            const Text(
              'Drafts',
              style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _drafts.isEmpty
                  ? 'Saved locally on your device'
                  : '${_drafts.length} saved ${_drafts.length == 1 ? "draft" : "drafts"}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _drafts.isEmpty ? _empty() : _list(),
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
              'Write a post in Compose and tap Save Draft. Your drafts stay on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _drafts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int i) {
        final Draft d = _drafts[i];
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
      },
    );
  }
}

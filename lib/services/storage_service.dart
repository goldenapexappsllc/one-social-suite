import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/draft.dart';
import '../models/history_entry.dart';
import '../models/video_item.dart';

/// Days a video stays in Trash before it is deleted for good.
const int kTrashDays = 7;

/// Videos above this total size trigger the optional storage reminder.
const int kReminderBytes = 1024 * 1024 * 1024;

/// Local persistence via Hive. Drafts + connection state + video registry,
/// all on-device. No cloud, no codegen (stores plain maps). Privacy-first.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const String _draftsBox = 'drafts';
  static const String _stateBox = 'app_state';
  static const String _historyBox = 'history';
  static const String _videosBox = 'videos';
  static const String _kConnected = 'connected_platforms';
  static const String _kSeenAppInfo = 'seen_app_info';
  static const String _kAutoEmptyTrash = 'auto_empty_trash';
  static const String _kStorageReminder = 'storage_reminder';

  late Box<dynamic> _drafts;
  late Box<dynamic> _state;
  late Box<dynamic> _history;
  late Box<dynamic> _videos;
  late Directory _videosDir;

  Directory get videosDir => _videosDir;

  /// Call once at startup, before runApp.
  Future<void> init() async {
    await Hive.initFlutter();
    _drafts = await Hive.openBox<dynamic>(_draftsBox);
    _state = await Hive.openBox<dynamic>(_stateBox);
    _history = await Hive.openBox<dynamic>(_historyBox);
    _videos = await Hive.openBox<dynamic>(_videosBox);
    final Directory docs = await getApplicationDocumentsDirectory();
    _videosDir = Directory('${docs.path}/videos');
    await _videosDir.create(recursive: true);
    await syncVideos();
    await purgeExpiredTrash();
  }

  String _base(String path) {
    final int i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }

  // ---- Drafts ----

  List<Draft> getDrafts() {
    final List<Draft> out = _drafts.values
        .map((v) => _rebase(Draft.fromMap(v as Map<dynamic, dynamic>)))
        .toList();
    out.sort((a, b) => b.editedAt.compareTo(a.editedAt)); // newest first
    return out;
  }

  Draft _withPath(Draft d, String path) => Draft(
        id: d.id,
        text: d.text,
        selectedPlatformIds: d.selectedPlatformIds,
        tone: d.tone,
        mediaPath: path,
        isVideo: d.isVideo,
        videoName: d.videoName,
        videoSeconds: d.videoSeconds,
        createdAt: d.createdAt,
        editedAt: d.editedAt,
      );

  /// If a video draft's saved path is stale (the app's folder moved),
  /// point it at the same file name inside the current videos folder.
  Draft _rebase(Draft d) {
    final String? p = d.mediaPath;
    if (!d.isVideo || p == null) return d;
    if (File(p).existsSync()) return d;
    final String candidate = '${_videosDir.path}/${_base(p)}';
    if (File(candidate).existsSync()) return _withPath(d, candidate);
    return d;
  }

  Future<void> saveDraft(Draft draft) async {
    Draft toSave = draft;
    if (draft.isVideo && draft.mediaPath != null) {
      toSave = await _adoptVideo(draft);
    }
    await _drafts.put(toSave.id, toSave.toMap());
  }

  Future<void> deleteDraft(String id) async {
    await _drafts.delete(id);
  }

  int get draftCount => _drafts.length;

  // ---- Videos ----

  List<VideoItem> _allVideos() => _videos.values
      .map((v) => VideoItem.fromMap(v as Map<dynamic, dynamic>))
      .toList();

  VideoItem? _videoByFile(String fileName) {
    final dynamic raw = _videos.get(fileName);
    if (raw == null) return null;
    return VideoItem.fromMap(raw as Map<dynamic, dynamic>);
  }

  /// Active (not in Trash) videos, newest first.
  List<VideoItem> getVideos() {
    final List<VideoItem> out =
        _allVideos().where((v) => !v.isTrashed).toList();
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// Videos in Trash, most recently trashed first.
  List<VideoItem> getTrashedVideos() {
    final List<VideoItem> out =
        _allVideos().where((v) => v.isTrashed).toList();
    out.sort((a, b) => b.trashedAt!.compareTo(a.trashedAt!));
    return out;
  }

  File fileFor(VideoItem v) => File('${_videosDir.path}/${v.fileName}');

  int get videoBytes =>
      getVideos().fold<int>(0, (int sum, VideoItem v) => sum + v.bytes);

  int get trashBytes =>
      getTrashedVideos().fold<int>(0, (int sum, VideoItem v) => sum + v.bytes);

  /// Makes the registry match the files in the videos folder: new files
  /// get an entry, entries whose file is gone are dropped.
  Future<void> syncVideos() async {
    final Set<String> onDisk = <String>{};
    for (final FileSystemEntity e in _videosDir.listSync()) {
      if (e is! File) continue;
      final String fn = _base(e.path);
      if (fn.startsWith('.')) continue;
      onDisk.add(fn);
      if (!_videos.containsKey(fn)) {
        final FileStat st = e.statSync();
        await _videos.put(
          fn,
          VideoItem(
            fileName: fn,
            name: defaultVideoName(st.modified),
            bytes: st.size,
            createdAt: st.modified,
          ).toMap(),
        );
      }
    }
    for (final dynamic k in _videos.keys.toList()) {
      if (!onDisk.contains(k as String)) await _videos.delete(k);
    }
  }

  /// Makes sure the draft's video lives in the app's videos folder and is
  /// in the registry. Gallery videos are copied in. Returns the draft with
  /// its final path.
  Future<Draft> _adoptVideo(Draft d) async {
    final String srcPath = d.mediaPath!;
    File src = File(srcPath);
    if (!await src.exists()) {
      final File rebased = File('${_videosDir.path}/${_base(srcPath)}');
      if (await rebased.exists()) {
        src = rebased;
      } else {
        return d;
      }
    }
    Draft out = d;
    final String fileName;
    if (src.parent.path == _videosDir.path) {
      fileName = _base(src.path);
      if (src.path != srcPath) out = _withPath(d, src.path);
    } else {
      final String b = _base(src.path);
      final String ext = b.contains('.') ? b.split('.').last : 'mp4';
      fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final String dest = '${_videosDir.path}/$fileName';
      await src.copy(dest);
      out = _withPath(d, dest);
    }

    final VideoItem? existing = _videoByFile(fileName);
    final int bytes = await File('${_videosDir.path}/$fileName').length();
    final String typed = (d.videoName ?? '').trim();
    final String name = typed.isNotEmpty
        ? typed
        : (existing?.name ?? defaultVideoName(DateTime.now()));
    final VideoItem base = existing ??
        VideoItem(
          fileName: fileName,
          name: name,
          seconds: d.videoSeconds,
          bytes: bytes,
          createdAt: DateTime.now(),
        );
    final VideoItem item = base.copyWith(
      name: name,
      seconds: d.videoSeconds ?? existing?.seconds,
      bytes: bytes,
      clearTrash: true, // using a video again takes it out of Trash
    );
    await _videos.put(fileName, item.toMap());
    return out;
  }

  Future<void> renameVideo(String fileName, String name) async {
    final VideoItem? v = _videoByFile(fileName);
    if (v == null || name.trim().isEmpty) return;
    await _videos.put(fileName, v.copyWith(name: name.trim()).toMap());
  }

  Future<void> trashVideo(String fileName) async {
    final VideoItem? v = _videoByFile(fileName);
    if (v == null) return;
    await _videos.put(fileName, v.copyWith(trashedAt: DateTime.now()).toMap());
  }

  Future<void> restoreVideo(String fileName) async {
    final VideoItem? v = _videoByFile(fileName);
    if (v == null) return;
    await _videos.put(fileName, v.copyWith(clearTrash: true).toMap());
  }

  Future<void> deleteVideoForever(String fileName) async {
    try {
      final File f = File('${_videosDir.path}/$fileName');
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await _videos.delete(fileName);
  }

  Future<void> emptyTrash() async {
    for (final VideoItem v in getTrashedVideos()) {
      await deleteVideoForever(v.fileName);
    }
  }

  /// Deletes videos that have been in Trash longer than [kTrashDays],
  /// but only when the auto-empty setting is on. Returns how many.
  Future<int> purgeExpiredTrash() async {
    if (!autoEmptyTrash) return 0;
    final DateTime cutoff =
        DateTime.now().subtract(const Duration(days: kTrashDays));
    int n = 0;
    for (final VideoItem v in getTrashedVideos()) {
      if (v.trashedAt!.isBefore(cutoff)) {
        await deleteVideoForever(v.fileName);
        n++;
      }
    }
    return n;
  }

  bool get autoEmptyTrash =>
      _state.get(_kAutoEmptyTrash, defaultValue: true) as bool;

  Future<void> setAutoEmptyTrash(bool v) async {
    await _state.put(_kAutoEmptyTrash, v);
  }

  bool get storageReminder =>
      _state.get(_kStorageReminder, defaultValue: true) as bool;

  Future<void> setStorageReminder(bool v) async {
    await _state.put(_kStorageReminder, v);
  }

  // ---- First run ----

  /// False until the App Info tab has been shown once. Used to land new
  /// users on the how-to page instead of straight into Compose.
  bool get hasSeenAppInfo =>
      _state.get(_kSeenAppInfo, defaultValue: false) as bool;

  Future<void> markAppInfoSeen() async {
    await _state.put(_kSeenAppInfo, true);
  }

  // ---- Connection state (survives restart) ----

  Set<String> getConnected() {
    final List<dynamic> raw =
        _state.get(_kConnected, defaultValue: <dynamic>[]) as List<dynamic>;
    return raw.map((e) => e.toString()).toSet();
  }

  Future<void> setConnected(Set<String> ids) async {
    await _state.put(_kConnected, ids.toList());
  }

  // ---- Share history ----

  List<HistoryEntry> getHistory() {
    final List<HistoryEntry> out = _history.values
        .map((v) => HistoryEntry.fromMap(v as Map<dynamic, dynamic>))
        .toList();
    out.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
    return out;
  }

  Future<void> addHistory(HistoryEntry entry) async {
    await _history.put(entry.id, entry.toMap());
  }

  Future<void> deleteHistory(String id) async {
    await _history.delete(id);
  }

  Future<void> clearHistory() async {
    await _history.clear();
  }
}

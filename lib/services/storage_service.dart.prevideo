import 'package:hive_flutter/hive_flutter.dart';
import '../models/draft.dart';
import '../models/history_entry.dart';

/// Local persistence via Hive. Drafts + connection state, all on-device.
/// No cloud, no codegen (stores plain maps). Privacy-first.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const String _draftsBox = 'drafts';
  static const String _stateBox = 'app_state';
  static const String _historyBox = 'history';
  static const String _kConnected = 'connected_platforms';
  static const String _kSeenAppInfo = 'seen_app_info';

  late Box<dynamic> _drafts;
  late Box<dynamic> _state;
  late Box<dynamic> _history;

  /// Call once at startup, before runApp.
  Future<void> init() async {
    await Hive.initFlutter();
    _drafts = await Hive.openBox<dynamic>(_draftsBox);
    _state = await Hive.openBox<dynamic>(_stateBox);
    _history = await Hive.openBox<dynamic>(_historyBox);
  }

  // ---- Drafts ----

  List<Draft> getDrafts() {
    final List<Draft> out = _drafts.values
        .map((v) => Draft.fromMap(v as Map<dynamic, dynamic>))
        .toList();
    out.sort((a, b) => b.editedAt.compareTo(a.editedAt)); // newest first
    return out;
  }

  Future<void> saveDraft(Draft draft) async {
    await _drafts.put(draft.id, draft.toMap());
  }

  Future<void> deleteDraft(String id) async {
    await _drafts.delete(id);
  }

  int get draftCount => _drafts.length;

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

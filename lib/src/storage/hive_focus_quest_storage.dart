import 'package:focus_quest/src/models/focus_profile.dart';
import 'package:focus_quest/src/models/focus_session.dart';
import 'package:focus_quest/src/storage/focus_quest_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed local persistence for focus sessions and profile state.
class HiveFocusQuestStorage implements FocusQuestStorage {
  /// Creates a Hive-backed storage adapter.
  HiveFocusQuestStorage({
    this.boxName = 'focus_quest',
    HiveInterface? hive,
    this.initializeHive = true,
  }) : _hive = hive ?? Hive;

  static const String _sessionsKey = 'sessions';
  static const String _profileKey = 'profile';

  /// Name of the Hive box used by this adapter.
  final String boxName;
  final HiveInterface _hive;

  /// Whether [initialize] should call `Hive.initFlutter()`.
  ///
  /// Set this to false when the host app has already initialized Hive or when
  /// tests initialize Hive with a temporary directory.
  final bool initializeHive;

  Box<dynamic>? _box;

  Future<Box<dynamic>> get _openBox async {
    final existingBox = _box;
    if (existingBox != null && existingBox.isOpen) {
      return existingBox;
    }

    if (initializeHive && !_hive.isBoxOpen(boxName)) {
      await _hive.initFlutter();
    }

    _box = await _hive.openBox<dynamic>(boxName);
    return _box!;
  }

  @override
  Future<void> initialize() async {
    await _openBox;
  }

  @override
  Future<void> saveSession(FocusSession session) async {
    final box = await _openBox;
    final sessions = await loadSessions();
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }

    await box.put(
      _sessionsKey,
      sessions.map((item) => item.toJson()).toList(growable: false),
    );
  }

  @override
  Future<List<FocusSession>> loadSessions() async {
    final box = await _openBox;
    final rawValue = box.get(_sessionsKey);
    if (rawValue is! List) {
      return <FocusSession>[];
    }

    return rawValue
        .whereType<Map>()
        .map((item) => FocusSession.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<void> saveProfile(FocusProfile profile) async {
    final box = await _openBox;
    await box.put(_profileKey, profile.toJson());
  }

  @override
  Future<FocusProfile?> loadProfile() async {
    final box = await _openBox;
    final rawValue = box.get(_profileKey);
    if (rawValue is! Map) {
      return null;
    }

    return FocusProfile.fromJson(Map<String, Object?>.from(rawValue));
  }

  @override
  Future<void> clear() async {
    final box = await _openBox;
    await box.delete(_sessionsKey);
    await box.delete(_profileKey);
  }
}

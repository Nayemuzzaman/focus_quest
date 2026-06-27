import 'dart:convert';

import 'package:focus_quest/src/models/focus_profile.dart';
import 'package:focus_quest/src/models/focus_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides a storage abstraction for persisting sessions and profile state.
abstract class FocusQuestStorage {
  Future<void> initialize();
  Future<void> saveSession(FocusSession session);
  Future<List<FocusSession>> loadSessions();
  Future<void> saveProfile(FocusProfile profile);
  Future<FocusProfile?> loadProfile();
  Future<void> clear();
}

class InMemoryFocusQuestStorage implements FocusQuestStorage {
  final List<FocusSession> _sessions = <FocusSession>[];
  FocusProfile? _profile;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> saveSession(FocusSession session) async {
    final index = _sessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      _sessions[index] = session;
    } else {
      _sessions.add(session);
    }
  }

  @override
  Future<List<FocusSession>> loadSessions() async =>
      List<FocusSession>.from(_sessions);

  @override
  Future<void> saveProfile(FocusProfile profile) async {
    _profile = profile;
  }

  @override
  Future<FocusProfile?> loadProfile() async => _profile;

  @override
  Future<void> clear() async {
    _sessions.clear();
    _profile = null;
  }
}

class SharedPreferencesFocusQuestStorage implements FocusQuestStorage {
  SharedPreferencesFocusQuestStorage({this.prefix = 'focus_quest'});

  final String prefix;
  SharedPreferences? _preferences;

  Future<SharedPreferences> _getPreferences() async {
    _preferences ??= await SharedPreferences.getInstance();
    return _preferences!;
  }

  @override
  Future<void> initialize() async {
    await _getPreferences();
  }

  @override
  Future<void> saveSession(FocusSession session) async {
    final prefs = await _getPreferences();
    final sessions = await loadSessions();
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }

    final encoded = jsonEncode(sessions.map((item) => item.toJson()).toList());
    await prefs.setString('${prefix}_sessions', encoded);
  }

  @override
  Future<List<FocusSession>> loadSessions() async {
    final prefs = await _getPreferences();
    final rawValue = prefs.getString('${prefix}_sessions');
    if (rawValue == null || rawValue.isEmpty) {
      return <FocusSession>[];
    }

    final decoded = jsonDecode(rawValue) as List<dynamic>;
    return decoded
        .map(
          (item) =>
              FocusSession.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveProfile(FocusProfile profile) async {
    final prefs = await _getPreferences();
    await prefs.setString('${prefix}_profile', jsonEncode(profile.toJson()));
  }

  @override
  Future<FocusProfile?> loadProfile() async {
    final prefs = await _getPreferences();
    final rawValue = prefs.getString('${prefix}_profile');
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    return FocusProfile.fromJson(
      Map<String, Object?>.from(jsonDecode(rawValue) as Map),
    );
  }

  @override
  Future<void> clear() async {
    final prefs = await _getPreferences();
    await prefs.remove('${prefix}_sessions');
    await prefs.remove('${prefix}_profile');
  }
}

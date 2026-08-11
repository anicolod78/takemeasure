import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/measure_session.dart';

/// Persistenza locale delle sessioni tramite [SharedPreferences].
///
/// Tutte le sessioni sono serializzate in un'unica chiave come lista JSON.
class SessionRepository {
  static const _key = 'measure_sessions';

  Future<List<MeasureSession>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final sessions = list
        .map((e) => MeasureSession.fromJson(e as Map<String, dynamic>))
        .toList();
    // Più recenti in cima.
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  Future<void> _saveAll(List<MeasureSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  /// Inserisce o aggiorna una sessione (per id).
  Future<void> upsert(MeasureSession session) async {
    final sessions = await loadAll();
    final index = sessions.indexWhere((s) => s.id == session.id);
    session.updatedAt = DateTime.now();
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }
    await _saveAll(sessions);
  }

  Future<void> delete(String id) async {
    final sessions = await loadAll();
    sessions.removeWhere((s) => s.id == id);
    await _saveAll(sessions);
  }
}

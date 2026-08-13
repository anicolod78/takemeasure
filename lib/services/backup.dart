import 'dart:convert';

import '../models/measure_session.dart';

const int backupFormatVersion = 1;

/// Serializza tutte le sessioni in un backup JSON (con intestazione).
String encodeBackup(List<MeasureSession> sessions, DateTime exportedAt) {
  return const JsonEncoder.withIndent('  ').convert({
    'app': 'takemeasure',
    'type': 'backup',
    'version': backupFormatVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'sessions': sessions.map((s) => s.toJson()).toList(),
  });
}

/// Interpreta un contenuto JSON come elenco di sessioni. Accetta:
/// - un backup completo `{ "sessions": [...] }`
/// - una lista di sessioni `[...]`
/// - una singola sessione `{ "roomName": ..., "vertices": [...] }`
List<MeasureSession> decodeBackup(String source) {
  final data = jsonDecode(source);
  if (data is Map<String, dynamic>) {
    final list = data['sessions'];
    if (list is List) {
      return list
          .map((e) => MeasureSession.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data.containsKey('vertices') || data.containsKey('roomName')) {
      return [MeasureSession.fromJson(data)];
    }
  } else if (data is List) {
    return data
        .map((e) => MeasureSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw const FormatException('Formato del file non riconosciuto');
}

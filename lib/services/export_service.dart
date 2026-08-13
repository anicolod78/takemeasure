import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/measure_session.dart';
import '../widgets/measure_painter.dart';
import 'backup.dart';

/// Esportazione e condivisione delle sessioni.
class ExportService {
  /// Genera un file di backup con tutte le sessioni e apre la condivisione.
  Future<void> shareBackup(List<MeasureSession> sessions) async {
    final now = DateTime.now();
    final content = encodeBackup(sessions, now);
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/takemeasure_backup_${_stamp(now)}.json');
    await file.writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Backup misurazioni Take Measure',
      ),
    );
  }

  String _stamp(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}';
  }

  /// Genera un PNG del disegno e apre il foglio di condivisione.
  Future<void> shareAsPng(MeasureSession session) async {
    final bytes = await renderSessionToPng(session);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_safeName(session.roomName)}.png');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        subject: 'Misure ${session.roomName}',
        text: 'Disegno misure: ${session.roomName}',
      ),
    );
  }

  /// Esporta la sessione come file JSON e apre il foglio di condivisione.
  Future<void> shareAsJson(MeasureSession session) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_safeName(session.roomName)}.json');
    await file.writeAsString(session.encode());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Dati misure ${session.roomName}',
      ),
    );
  }

  String _safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^\w\-]+'), '_').trim();
    return cleaned.isEmpty ? 'misure' : cleaned;
  }
}

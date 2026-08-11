import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/measure_session.dart';
import '../widgets/measure_painter.dart';

/// Esportazione e condivisione delle sessioni.
class ExportService {
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

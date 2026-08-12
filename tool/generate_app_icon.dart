import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Genera i PNG sorgente per l'icona dell'app (righello + squadra, line-art).
//
// Esegui con:  flutter test tool/generate_app_icon.dart
//
// Produce:
//   assets/icon/app_icon.png             (1024, con sfondo)
//   assets/icon/app_icon_foreground.png  (1024, trasparente, per icona adattiva)

const _white = Color(0xFFFFFFFF);
const _bgTop = Color(0xFF2196F3);
const _bgBottom = Color(0xFF0D47A1);

void main() {
  testWidgets('genera icona app', (tester) async {
    await tester.runAsync(() async {
      await _savePng('assets/icon/app_icon.png', 1024,
          background: true, content: 0.68);
      // Content alto: l'icona adattiva applica già un inset del 16%.
      await _savePng('assets/icon/app_icon_foreground.png', 1024,
          background: false, content: 0.90);
    });
  });
}

Future<void> _savePng(String path, int size,
    {required bool background, required double content}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _drawIcon(canvas, size.toDouble(), background: background, content: content);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
  // ignore: avoid_print
  print('Scritto $path (${data.lengthInBytes} byte)');
}

void _drawIcon(Canvas c, double s,
    {required bool background, required double content}) {
  if (background) {
    final rect = Rect.fromLTWH(0, 0, s, s);
    final bg = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(s, s),
        const [_bgTop, _bgBottom],
      );
    c.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(s * 0.22)),
      bg,
    );
  }

  c.save();
  c.translate(s / 2, s / 2);
  c.scale(content);
  _drawCrossedTools(c, s);
  c.restore();
}

Paint _stroke(double w) => Paint()
  ..color = _white
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

void _ticks(Canvas c, Paint p, Offset a, Offset b, int count, double major,
    double minor,
    {int every = 2}) {
  final dir = b - a;
  final dist = dir.distance;
  if (dist == 0) return;
  final u = dir / dist;
  final n = Offset(-u.dy, u.dx);
  for (int i = 0; i <= count; i++) {
    final pt = a + dir * (i / count);
    final len = (i % every == 0) ? major : minor;
    c.drawLine(pt, pt + n * len, p);
  }
}

/// Righello e squadra incrociati, in outline bianco (disegno "pieno": al
/// content 1.0 occupa quasi tutta l'icona).
void _drawCrossedTools(Canvas c, double s) {
  // Righello (dietro): rettangolo stondato in outline, con tacche.
  c.save();
  c.rotate(-20 * pi / 180);
  final rr = RRect.fromRectAndRadius(
    Rect.fromCenter(
        center: Offset(0, s * 0.15), width: s * 0.92, height: s * 0.17),
    Radius.circular(s * 0.02),
  );
  c.drawRRect(rr, _stroke(s * 0.026));
  _ticks(
    c,
    _stroke(s * 0.016),
    Offset(-s * 0.40, s * 0.065),
    Offset(s * 0.40, s * 0.065),
    10,
    s * 0.05,
    s * 0.028,
  );
  c.restore();

  // Squadra (davanti): triangolo rettangolo in outline.
  final k = s * 0.34;
  final a = Offset(-k, k * 0.7);
  final b = Offset(k, k * 0.7);
  final top = Offset(-k, -k * 1.05);
  c.drawPath(
    Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(top.dx, top.dy)
      ..close(),
    _stroke(s * 0.03),
  );
}

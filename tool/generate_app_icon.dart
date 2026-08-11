import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Genera i PNG sorgente per l'icona dell'app (righello + squadra).
//
// Esegui con:  flutter test tool/generate_app_icon.dart
//
// Produce:
//   assets/icon/app_icon.png             (1024, con sfondo)
//   assets/icon/app_icon_foreground.png  (1024, trasparente, per icona adattiva)

const _cream = Color(0xFFFFF6DC);
const _amber = Color(0xFFE6A93B);
const _ink = Color(0xFF0B346B);
const _white = Color(0xFFFFFFFF);

void main() {
  testWidgets('genera icona app', (tester) async {
    await tester.runAsync(() async {
      await _savePng('assets/icon/app_icon.png', 1024,
          background: true, content: 0.80);
      // Content alto: l'icona adattiva applica già un inset del 16%.
      await _savePng('assets/icon/app_icon_foreground.png', 1024,
          background: false, content: 0.88);
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
        const [Color(0xFF2196F3), Color(0xFF0D47A1)],
      );
    c.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(s * 0.22)),
      bg,
    );
  }

  c.save();
  c.translate(s / 2, s / 2);
  c.scale(content);
  _drawRuler(c, s);
  _drawSetSquare(c, s);
  c.restore();
}

void _drawRuler(Canvas c, double s) {
  c.save();
  c.rotate(-20 * pi / 180);

  final rulerRect = Rect.fromCenter(
    center: Offset(0, s * 0.16),
    width: s * 0.92,
    height: s * 0.17,
  );
  final rr = RRect.fromRectAndRadius(rulerRect, Radius.circular(s * 0.02));

  // Ombra leggera.
  c.drawRRect(
    rr.shift(Offset(s * 0.012, s * 0.02)),
    Paint()..color = const Color(0x33000000),
  );

  c.drawRRect(rr, Paint()..color = _cream);
  c.drawRRect(
    rr,
    Paint()
      ..color = _amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.012,
  );

  // Tacche lungo il bordo superiore del righello.
  final tickPaint = Paint()
    ..color = _ink
    ..strokeWidth = s * 0.008
    ..strokeCap = StrokeCap.round;
  final top = rulerRect.top;
  final left = rulerRect.left + s * 0.05;
  final right = rulerRect.right - s * 0.05;
  const count = 14;
  for (int i = 0; i <= count; i++) {
    final x = left + (right - left) * (i / count);
    final major = i % 2 == 0;
    final len = major ? s * 0.06 : s * 0.035;
    c.drawLine(Offset(x, top), Offset(x, top + len), tickPaint);
  }

  c.restore();
}

void _drawSetSquare(Canvas c, double s) {
  // Squadra: triangolo rettangolo cavo, angolo retto in basso a sinistra.
  final a = Offset(-s * 0.33, s * 0.31); // angolo retto
  final b = Offset(s * 0.37, s * 0.31); // base destra
  final cc = Offset(-s * 0.33, -s * 0.39); // vertice alto

  final outer = Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(cc.dx, cc.dy)
    ..close();

  // Triangolo interno (foro) scalato verso il baricentro.
  final centroid = Offset(
    (a.dx + b.dx + cc.dx) / 3,
    (a.dy + b.dy + cc.dy) / 3,
  );
  Offset toward(Offset p, double k) => Offset(
        centroid.dx + (p.dx - centroid.dx) * k,
        centroid.dy + (p.dy - centroid.dy) * k,
      );
  const k = 0.52;
  final inner = Path()
    ..moveTo(toward(a, k).dx, toward(a, k).dy)
    ..lineTo(toward(b, k).dx, toward(b, k).dy)
    ..lineTo(toward(cc, k).dx, toward(cc, k).dy)
    ..close();

  final frame = Path.combine(PathOperation.difference, outer, inner);

  // Ombra.
  c.drawPath(
    frame.shift(Offset(s * 0.012, s * 0.02)),
    Paint()..color = const Color(0x33000000),
  );

  // Corpo semitrasparente così il righello resta visibile nel foro.
  c.drawPath(frame, Paint()..color = _white.withValues(alpha: 0.92));

  // Contorni.
  final edge = Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.013
    ..strokeJoin = StrokeJoin.round;
  c.drawPath(outer, edge);
  c.drawPath(inner, edge);

  // Tacche lungo la base (cateto inferiore).
  final tickPaint = Paint()
    ..color = _ink
    ..strokeWidth = s * 0.008
    ..strokeCap = StrokeCap.round;
  final x0 = a.dx + s * 0.05;
  final x1 = b.dx - s * 0.05;
  const count = 10;
  for (int i = 0; i <= count; i++) {
    final x = x0 + (x1 - x0) * (i / count);
    final len = i % 2 == 0 ? s * 0.05 : s * 0.03;
    c.drawLine(Offset(x, a.dy), Offset(x, a.dy - len), tickPaint);
  }
}

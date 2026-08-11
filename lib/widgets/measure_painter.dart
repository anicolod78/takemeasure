import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/measure_session.dart';
import '../services/geometry.dart';

/// Colori usati dal disegno, così che editor ed esportazione siano coerenti.
class MeasureColors {
  final Color grid;
  final Color line;
  final Color fill;
  final Color vertex;
  final Color startVertex;
  final Color highlight;
  final Color lengthText;
  final Color heightText;
  final Color lengthBox;
  final Color heightBox;

  const MeasureColors({
    required this.grid,
    required this.line,
    required this.fill,
    required this.vertex,
    required this.startVertex,
    required this.highlight,
    required this.lengthText,
    required this.heightText,
    required this.lengthBox,
    required this.heightBox,
  });

  static const light = MeasureColors(
    grid: Color(0xFFE0E0E0),
    line: Color(0xFF1565C0),
    fill: Color(0x221565C0),
    vertex: Color(0xFF0D47A1),
    startVertex: Color(0xFF2E7D32),
    highlight: Color(0xFFD32F2F),
    lengthText: Colors.white,
    heightText: Colors.white,
    lengthBox: Color(0xFF1565C0),
    heightBox: Color(0xFFEF6C00),
  );
}

/// Disegna il poligono della stanza con le misure dei segmenti e le altezze.
///
/// Le posizioni dei vertici ([points], in coordinate canvas) sono calcolate
/// esternamente (layout schematico o in scala reale), così il painter è
/// indipendente dalla logica geometrica.
class MeasurePainter extends CustomPainter {
  final MeasureSession session;
  final List<Offset> points;

  final bool showGrid;
  final Offset? gridOrigin;
  final double? gridCellSize;

  /// Indice del vertice da evidenziare (es. l'ultimo inserito), o null.
  final int? highlightVertexIndex;

  final MeasureColors colors;

  MeasurePainter({
    required this.session,
    required this.points,
    this.showGrid = true,
    this.gridOrigin,
    this.gridCellSize,
    this.highlightVertexIndex,
    this.colors = MeasureColors.light,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid && gridOrigin != null && gridCellSize != null) {
      _paintGrid(canvas, size, gridOrigin!, gridCellSize!);
    }

    if (points.isEmpty) return;

    // Riempimento se il poligono è chiuso.
    if (session.closed && points.length >= 3) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = colors.fill);
    }

    final linePaint = Paint()
      ..color = colors.line
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final segCount = session.segmentCount;

    // Segmenti.
    for (int i = 0; i < segCount; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      canvas.drawLine(a, b, linePaint);
    }

    // Etichette lunghezza (al centro di ogni segmento).
    for (int i = 0; i < segCount; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final len = session.vertices[i].lengthToNextCm;
      final label = len == null ? '? cm' : '${formatCm(len)} cm';

      final dir = b - a;
      final dist = dir.distance == 0 ? 1 : dir.distance;
      final normal = Offset(-dir.dy / dist, dir.dx / dist);
      final pos = mid + normal * 16;
      _drawLabel(canvas, pos, label, colors.lengthBox, colors.lengthText);
    }

    // Vertici + etichette altezza.
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isStart = i == 0;
      final isHighlight = highlightVertexIndex == i;

      canvas.drawCircle(
        p,
        isHighlight ? 8 : 6,
        Paint()
          ..color = isHighlight
              ? colors.highlight
              : (isStart ? colors.startVertex : colors.vertex),
      );
      canvas.drawCircle(
        p,
        isHighlight ? 8 : 6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      final h = session.vertices[i].heightCm;
      if (h != null) {
        _drawLabel(
          canvas,
          p + const Offset(10, -22),
          'h ${formatCm(h)}',
          colors.heightBox,
          colors.heightText,
        );
      }
    }
  }

  void _paintGrid(Canvas canvas, Size size, Offset origin, double cell) {
    final paint = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;
    final startX = origin.dx % cell;
    for (double x = startX; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final startY = origin.dy % cell;
    for (double y = startY; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    String text,
    Color boxColor,
    Color textColor,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + 10,
      height: tp.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = boxColor,
    );
    tp.paint(canvas, Offset(rect.left + 5, rect.top + 3));
  }

  @override
  bool shouldRepaint(covariant MeasurePainter old) => true;
}

/// Formatta un valore in cm senza decimali superflui.
String formatCm(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

/// Formatta metri con la virgola come separatore decimale (italiano).
String _formatMeters(double cm) =>
    (cm / 100).toStringAsFixed(2).replaceAll('.', ',');

/// Renderizza il poligono in un'immagine PNG in scala reale, cropperata sui suoi
/// limiti, con intestazione (nome stanza, data, perimetro, area).
Future<Uint8List> renderSessionToPng(
  MeasureSession session, {
  double padding = 80,
}) async {
  final recorder = ui.PictureRecorder();

  // Layout in cm (1 px = 1 cm), poi scalato per una risoluzione gradevole.
  final cmPts = layoutPoints(
    session,
    origin: Offset.zero,
    cellSize: 1,
    toScale: true,
    pxPerCm: 1,
  );

  final stats = computeStats(session);

  double factor = 2;
  Rect bb = pointBounds(cmPts);
  final maxDim = bb.longestSide;
  if (maxDim > 0) {
    factor = (1200 / maxDim).clamp(0.5, 4).toDouble();
  }

  final scaled = cmPts.map((p) => p * factor).toList();
  bb = pointBounds(scaled);

  const headerH = 96.0;
  final contentW = scaled.isEmpty ? 200.0 : bb.width;
  final contentH = scaled.isEmpty ? 120.0 : bb.height;
  final width = contentW + padding * 2;
  final height = contentH + padding * 2 + headerH;

  // Trasla i punti sotto l'intestazione, con margine.
  final shift = Offset(padding - bb.left, padding + headerH - bb.top);
  final points = scaled.map((p) => p + shift).toList();

  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = Colors.white,
  );

  // Intestazione.
  final infoParts = <String>[];
  if (stats.perimeterCm != null) {
    infoParts.add(
        'Perimetro: ${stats.perimeterComplete ? '' : '≥ '}${_formatMeters(stats.perimeterCm!)} m');
  }
  if (stats.areaM2 != null) {
    infoParts.add('Area: ${stats.areaM2!.toStringAsFixed(2).replaceAll('.', ',')} m²');
  }

  final header = TextPainter(
    text: TextSpan(
      children: [
        TextSpan(
          text: '${session.roomName}\n',
          style: const TextStyle(
            color: Color(0xFF212121),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(
          text: '${_formatDate(session.updatedAt)}\n',
          style: const TextStyle(color: Color(0xFF757575), fontSize: 14),
        ),
        TextSpan(
          text: infoParts.join('     '),
          style: const TextStyle(
            color: Color(0xFF1565C0),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width - 40);
  header.paint(canvas, const Offset(20, 16));

  MeasurePainter(
    session: session,
    points: points,
    showGrid: false,
  ).paint(canvas, Size(width, height));

  final picture = recorder.endRecording();
  final img = await picture.toImage(width.ceil(), height.ceil());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
}

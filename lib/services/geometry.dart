import 'dart:math';
import 'dart:ui';

import '../models/measure_session.dart';

/// Vettore direzione unitario da (dx,dy). Restituisce zero se nullo.
Offset unitDir(double dx, double dy) {
  if (dx == 0 && dy == 0) return Offset.zero;
  final len = sqrt(dx * dx + dy * dy);
  return Offset(dx / len, dy / len);
}

/// Calcola le posizioni (in coordinate canvas) dei vertici del poligono.
///
/// - [toScale] = false: layout schematico, posizione = griglia * [cellSize].
/// - [toScale] = true: layout in scala reale. La direzione di ogni lato deriva
///   dalla griglia (0°/45°/90°...), mentre la lunghezza deriva dalla misura in
///   cm inserita. I lati non ancora misurati usano una lunghezza di ripiego
///   ([defaultCmPerCell] cm per cella di griglia).
List<Offset> layoutPoints(
  MeasureSession s, {
  required Offset origin,
  required double cellSize,
  required bool toScale,
  double pxPerCm = 1,
  double defaultCmPerCell = 100,
}) {
  final verts = s.vertices;
  if (verts.isEmpty) return const [];

  if (!toScale) {
    return verts
        .map((v) => Offset(origin.dx + v.gx * cellSize, origin.dy + v.gy * cellSize))
        .toList();
  }

  final pts = <Offset>[origin];
  for (int i = 1; i < verts.length; i++) {
    final prev = verts[i - 1];
    final cur = verts[i];
    final gdx = cur.gx - prev.gx;
    final gdy = cur.gy - prev.gy;
    final dir = unitDir(gdx, gdy);
    final lenCm = prev.lengthToNextCm ??
        (sqrt(gdx * gdx + gdy * gdy) * defaultCmPerCell);
    pts.add(pts[i - 1] + dir * (lenCm * pxPerCm));
  }
  return pts;
}

/// Limiti (bounding box) di un elenco di punti.
Rect pointBounds(List<Offset> pts) {
  if (pts.isEmpty) return Rect.zero;
  double minX = pts.first.dx, minY = pts.first.dy;
  double maxX = minX, maxY = minY;
  for (final p in pts) {
    minX = min(minX, p.dx);
    minY = min(minY, p.dy);
    maxX = max(maxX, p.dx);
    maxY = max(maxY, p.dy);
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Statistiche calcolate della stanza.
class RoomStats {
  /// Perimetro totale in cm (somma delle misure inserite), o null se nessuna.
  final double? perimeterCm;

  /// True se tutti i lati hanno una misura.
  final bool perimeterComplete;

  /// Area in metri quadri, o null se non calcolabile
  /// (serve poligono chiuso e tutti i lati del percorso misurati).
  final double? areaM2;

  /// Altezza media (cm) degli angoli con altezza definita, o null.
  final double? heightAvgCm;

  /// True se tutti gli angoli hanno la stessa altezza (volume esatto).
  final bool heightUniform;

  /// Volume in metri cubi (area × altezza media), o null se non calcolabile.
  final double? volumeM3;

  const RoomStats({
    required this.perimeterCm,
    required this.perimeterComplete,
    required this.areaM2,
    required this.heightAvgCm,
    required this.heightUniform,
    required this.volumeM3,
  });
}

RoomStats computeStats(MeasureSession s) {
  final n = s.segmentCount;
  double sum = 0;
  bool any = false;
  bool complete = n > 0;
  for (int i = 0; i < n; i++) {
    final l = s.vertices[i].lengthToNextCm;
    if (l != null) {
      sum += l;
      any = true;
    } else {
      complete = false;
    }
  }

  // Altezze.
  final heights =
      s.vertices.map((v) => v.heightCm).whereType<double>().toList();
  double? avgH;
  bool uniform = false;
  if (heights.isNotEmpty) {
    avgH = heights.reduce((a, b) => a + b) / heights.length;
    uniform = heights.every((h) => (h - heights.first).abs() < 0.001);
  }

  final area = _areaM2(s);
  final volume = (area != null && avgH != null) ? area * (avgH / 100) : null;

  return RoomStats(
    perimeterCm: any ? sum : null,
    perimeterComplete: complete,
    areaM2: area,
    heightAvgCm: avgH,
    heightUniform: uniform,
    volumeM3: volume,
  );
}

double? _areaM2(MeasureSession s) {
  if (!s.closed) return null;
  final n = s.vertices.length;
  if (n < 3) return null;

  // Servono le misure dei lati del percorso (0..n-2) per posizionare i vertici.
  for (int i = 0; i < n - 1; i++) {
    if (s.vertices[i].lengthToNextCm == null) return null;
  }

  final pts = <Offset>[Offset.zero];
  for (int i = 1; i < n; i++) {
    final prev = s.vertices[i - 1];
    final cur = s.vertices[i];
    final dir = unitDir(cur.gx - prev.gx, cur.gy - prev.gy);
    pts.add(pts[i - 1] + dir * prev.lengthToNextCm!);
  }

  // Formula di Gauss (shoelace).
  double area2 = 0;
  for (int i = 0; i < n; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % n];
    area2 += a.dx * b.dy - b.dx * a.dy;
  }
  final areaCm2 = area2.abs() / 2;
  return areaCm2 / 10000.0; // cm² -> m²
}

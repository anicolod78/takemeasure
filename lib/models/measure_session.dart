import 'dart:convert';

/// Un vertice (angolo) del poligono della stanza.
///
/// Le coordinate [gx]/[gy] sono espresse in unità di griglia (interi logici):
/// definiscono la forma schematica del disegno. La misura reale del muro è
/// registrata in [lengthToNextCm] (segmento verso il vertice successivo), mentre
/// [heightCm] è l'altezza da terra registrata su questo angolo.
class Vertex {
  double gx;
  double gy;

  /// Altezza da terra registrata su questo angolo, in centimetri.
  double? heightCm;

  /// Lunghezza in centimetri del segmento che parte da questo vertice e
  /// raggiunge il vertice successivo (o, per l'ultimo vertice di un poligono
  /// chiuso, il segmento di chiusura verso il primo vertice).
  double? lengthToNextCm;

  Vertex({
    required this.gx,
    required this.gy,
    this.heightCm,
    this.lengthToNextCm,
  });

  Map<String, dynamic> toJson() => {
        'gx': gx,
        'gy': gy,
        'heightCm': heightCm,
        'lengthToNextCm': lengthToNextCm,
      };

  factory Vertex.fromJson(Map<String, dynamic> json) => Vertex(
        gx: (json['gx'] as num).toDouble(),
        gy: (json['gy'] as num).toDouble(),
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        lengthToNextCm: (json['lengthToNextCm'] as num?)?.toDouble(),
      );
}

/// Una sessione di misura per una stanza.
class MeasureSession {
  final String id;
  String roomName;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Vertici del poligono in ordine.
  List<Vertex> vertices;

  /// Se true il poligono è chiuso: l'ultimo vertice è collegato al primo.
  bool closed;

  MeasureSession({
    required this.id,
    required this.roomName,
    required this.createdAt,
    required this.updatedAt,
    List<Vertex>? vertices,
    this.closed = false,
  }) : vertices = vertices ?? [];

  /// Numero di segmenti (muri) definiti dal poligono.
  int get segmentCount {
    if (vertices.length < 2) return 0;
    return closed ? vertices.length : vertices.length - 1;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomName': roomName,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'closed': closed,
        'vertices': vertices.map((v) => v.toJson()).toList(),
      };

  factory MeasureSession.fromJson(Map<String, dynamic> json) => MeasureSession(
        id: json['id'] as String,
        roomName: json['roomName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        closed: json['closed'] as bool? ?? false,
        vertices: (json['vertices'] as List<dynamic>)
            .map((e) => Vertex.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String encode() => jsonEncode(toJson());

  factory MeasureSession.decode(String source) =>
      MeasureSession.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

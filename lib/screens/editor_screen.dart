import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/measure_session.dart';
import '../services/export_service.dart';
import '../services/geometry.dart';
import '../services/session_repository.dart';
import '../widgets/measure_painter.dart';

enum EditMode { draw, move, length, height }

class EditorScreen extends StatefulWidget {
  final MeasureSession session;

  const EditorScreen({super.key, required this.session});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const double _cellSize = 22;
  static const double _canvasSize = 6000;
  static const Offset _origin = Offset(_canvasSize / 2, _canvasSize / 2);
  static const double _baseTapThreshold = 26;

  final _repo = SessionRepository();
  final _export = ExportService();
  final _tc = TransformationController();

  late MeasureSession _session;
  EditMode _mode = EditMode.draw;
  bool _toScale = false;
  int? _dragIndex;
  Size _viewport = Size.zero;
  bool _viewInitialized = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    await _repo.upsert(_session);
  }

  // --- Geometria corrente --------------------------------------------------

  /// Posizioni dei vertici in coordinate canvas, secondo la vista attuale.
  List<Offset> _currentPoints() => layoutPoints(
        _session,
        origin: _origin,
        cellSize: _cellSize,
        toScale: _toScale,
      );

  double get _currentScale {
    final s = _tc.value.getMaxScaleOnAxis();
    return s == 0 ? 1 : s;
  }

  double get _tapThreshold => _baseTapThreshold / _currentScale;

  math.Point<int> _canvasToGrid(Offset canvas) => math.Point(
        ((canvas.dx - _origin.dx) / _cellSize).round(),
        ((canvas.dy - _origin.dy) / _cellSize).round(),
      );

  // --- Gestione tap --------------------------------------------------------

  void _onTapDown(TapDownDetails details) {
    final canvasPoint = details.localPosition;
    switch (_mode) {
      case EditMode.draw:
        _handleDrawTap(canvasPoint);
        break;
      case EditMode.move:
        break; // In modalità Sposta si usa il trascinamento.
      case EditMode.length:
        final i = _nearestSegment(canvasPoint);
        if (i != null) _editLength(i);
        break;
      case EditMode.height:
        final i = _nearestVertex(canvasPoint);
        if (i != null) _editHeight(i);
        break;
    }
  }

  void _handleDrawTap(Offset canvasPoint) {
    if (_toScale) {
      _snack('Disattiva la vista in scala per modificare la forma.');
      return;
    }
    if (_session.closed) return;

    final points = _currentPoints();

    // Snap-to-close: se tocco vicino al primo angolo (con almeno 3 angoli).
    if (points.length >= 3) {
      final d = (points.first - canvasPoint).distance;
      if (d < _tapThreshold * 1.4) {
        setState(() => _session.closed = true);
        _persist();
        return;
      }
    }

    final g = _canvasToGrid(canvasPoint);

    if (_session.vertices.isEmpty) {
      setState(() {
        _session.vertices
            .add(Vertex(gx: g.x.toDouble(), gy: g.y.toDouble()));
      });
      _persist();
      return;
    }

    final last = _session.vertices.last;
    final snapped =
        _snapTo45(last.gx, last.gy, g.x.toDouble(), g.y.toDouble());
    if (snapped == null) return;

    setState(() {
      _session.vertices.add(Vertex(gx: snapped.dx, gy: snapped.dy));
    });
    _persist();
  }

  /// Vincola il punto (tx,ty) a un angolo multiplo di 45° rispetto a (lx,ly).
  Offset? _snapTo45(double lx, double ly, double tx, double ty) {
    final dx = tx - lx;
    final dy = ty - ly;
    final adx = dx.abs();
    final ady = dy.abs();
    if (adx == 0 && ady == 0) return null;

    double ndx, ndy;
    if (adx > 2 * ady) {
      ndx = dx;
      ndy = 0;
    } else if (ady > 2 * adx) {
      ndx = 0;
      ndy = dy;
    } else {
      final mag = ((adx + ady) / 2).round().toDouble();
      if (mag == 0) return null;
      ndx = mag * (dx.isNegative ? -1 : 1);
      ndy = mag * (dy.isNegative ? -1 : 1);
    }
    if (ndx == 0 && ndy == 0) return null;
    return Offset(lx + ndx, ly + ndy);
  }

  // --- Spostamento / eliminazione angoli -----------------------------------

  void _onPanStart(DragStartDetails d) {
    if (_mode != EditMode.move) return;
    _dragIndex = _nearestVertex(d.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_mode != EditMode.move || _dragIndex == null) return;
    final g = _canvasToGrid(d.localPosition);
    setState(() {
      _session.vertices[_dragIndex!].gx = g.x.toDouble();
      _session.vertices[_dragIndex!].gy = g.y.toDouble();
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_dragIndex != null) {
      _dragIndex = null;
      _persist();
    }
  }

  void _onLongPressStart(LongPressStartDetails d) {
    if (_mode != EditMode.move) return;
    final i = _nearestVertex(d.localPosition);
    if (i != null) _confirmDeleteVertex(i);
  }

  Future<void> _confirmDeleteVertex(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Elimina angolo ${index + 1}'),
        content: const Text('Rimuovere questo angolo dalla forma?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _session.vertices.removeAt(index);
      // Il lato che entrava in questo vertice cambia: azzera la misura del
      // vertice precedente (o dell'ultimo, se ho rimosso il primo).
      if (_session.vertices.isNotEmpty) {
        final prev = index - 1;
        if (prev >= 0) {
          _session.vertices[prev].lengthToNextCm = null;
        } else {
          _session.vertices.last.lengthToNextCm = null;
        }
      }
      if (_session.vertices.length < 3) _session.closed = false;
    });
    _persist();
  }

  // --- Ricerca elementi vicini --------------------------------------------

  int? _nearestVertex(Offset canvasPoint) {
    final points = _currentPoints();
    int? best;
    double bestDist = _tapThreshold;
    for (int i = 0; i < points.length; i++) {
      final d = (points[i] - canvasPoint).distance;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  int? _nearestSegment(Offset canvasPoint) {
    final points = _currentPoints();
    int? best;
    double bestDist = _tapThreshold;
    final segCount = _session.segmentCount;
    for (int i = 0; i < segCount; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final d = _distanceToSegment(canvasPoint, a, b);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq == 0) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance;
  }

  // --- Dialoghi di modifica ------------------------------------------------

  Future<void> _editLength(int segIndex) async {
    final current = _session.vertices[segIndex].lengthToNextCm;
    final value = await _askNumber(
      title: 'Misura lato ${segIndex + 1}',
      label: 'Lunghezza (cm)',
      initial: current,
    );
    if (value == null) return;
    setState(() {
      _session.vertices[segIndex].lengthToNextCm =
          value.cleared ? null : value.value;
    });
    _persist();
  }

  Future<void> _editHeight(int vIndex) async {
    final current = _session.vertices[vIndex].heightCm;
    final value = await _askNumber(
      title: 'Altezza angolo ${vIndex + 1}',
      label: 'Altezza da terra (cm)',
      initial: current,
    );
    if (value == null) return;
    setState(() {
      _session.vertices[vIndex].heightCm = value.cleared ? null : value.value;
    });
    _persist();
  }

  Future<_NumberResult?> _askNumber({
    required String title,
    required String label,
    double? initial,
  }) {
    final controller = TextEditingController(
      text: initial == null ? '' : formatCm(initial),
    );
    return showDialog<_NumberResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: 'cm'),
          onSubmitted: (_) =>
              Navigator.pop(ctx, _parseResult(controller.text)),
        ),
        actions: [
          if (initial != null)
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, const _NumberResult.cleared()),
              child: const Text('Cancella'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, _parseResult(controller.text)),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  _NumberResult? _parseResult(String text) {
    final t = text.trim().replaceAll(',', '.');
    if (t.isEmpty) return const _NumberResult.cleared();
    final v = double.tryParse(t);
    if (v == null || v < 0) return null;
    return _NumberResult(v);
  }

  // --- Azioni barra --------------------------------------------------------

  void _undo() {
    if (_session.vertices.isEmpty) return;
    setState(() {
      if (_session.closed) {
        _session.closed = false;
      } else {
        _session.vertices.removeLast();
        if (_session.vertices.isNotEmpty) {
          _session.vertices.last.lengthToNextCm = null;
        }
      }
    });
    _persist();
  }

  void _toggleClose() {
    if (_session.vertices.length < 3) {
      _snack('Servono almeno 3 angoli per chiudere la forma.');
      return;
    }
    setState(() => _session.closed = !_session.closed);
    _persist();
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancella disegno'),
        content: const Text('Rimuovere tutti gli angoli e le misure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancella'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _session.vertices.clear();
        _session.closed = false;
      });
      _persist();
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _session.roomName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rinomina stanza'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      setState(() => _session.roomName = name.trim());
      _persist();
    }
  }

  Future<void> _exportPng() async {
    if (_session.vertices.isEmpty) {
      _snack('Disegna la forma prima di esportare.');
      return;
    }
    try {
      await _export.shareAsPng(_session);
    } catch (e) {
      _snack('Errore esportazione immagine: $e');
    }
  }

  Future<void> _exportJson() async {
    try {
      await _export.shareAsJson(_session);
    } catch (e) {
      _snack('Errore esportazione dati: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _toggleScale() {
    setState(() {
      _toScale = !_toScale;
      if (_toScale && (_mode == EditMode.draw || _mode == EditMode.move)) {
        _mode = EditMode.length;
      }
    });
    _fitToContent();
  }

  void _fitToContent() {
    if (_viewport == Size.zero) return;
    final points = _currentPoints();
    if (points.isEmpty) {
      setState(() => _tc.value = _centerMatrix());
      return;
    }
    final bb = pointBounds(points);
    final contentW = bb.width + 2 * _cellSize;
    final contentH = bb.height + 2 * _cellSize;
    final scale = math
        .min(_viewport.width / contentW, _viewport.height / contentH)
        .clamp(0.3, 3.0);

    final center = bb.center;
    final m = Matrix4.identity()
      ..translateByDouble(_viewport.width / 2, _viewport.height / 2, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    setState(() => _tc.value = m);
  }

  Matrix4 _centerMatrix() {
    return Matrix4.identity()
      ..translateByDouble(_viewport.width / 2, _viewport.height / 2, 0, 1)
      ..translateByDouble(-_origin.dx, -_origin.dy, 0, 1);
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _rename,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(_session.roomName)),
              const SizedBox(width: 6),
              const Icon(Icons.edit, size: 16),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: _toScale ? 'Vista schematica' : 'Vista in scala reale',
            isSelected: _toScale,
            icon: const Icon(Icons.aspect_ratio),
            selectedIcon: const Icon(Icons.aspect_ratio),
            onPressed: _toggleScale,
          ),
          IconButton(
            tooltip: 'Centra',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _fitToContent,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'png') _exportPng();
              if (v == 'json') _exportJson();
              if (v == 'clear') _clear();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'png',
                child: ListTile(
                  leading: Icon(Icons.image),
                  title: Text('Esporta immagine (PNG)'),
                ),
              ),
              const PopupMenuItem(
                value: 'json',
                child: ListTile(
                  leading: Icon(Icons.code),
                  title: Text('Esporta dati (JSON)'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep),
                  title: Text('Cancella disegno'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _statsBar(),
          _hintBar(),
          Expanded(child: _canvas()),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _statsBar() {
    final stats = computeStats(_session);
    String perim;
    if (stats.perimeterCm == null) {
      perim = '—';
    } else {
      final m = (stats.perimeterCm! / 100).toStringAsFixed(2).replaceAll('.', ',');
      perim = '${stats.perimeterComplete ? '' : '≥ '}$m m';
    }
    final area = stats.areaM2 == null
        ? '—'
        : '${stats.areaM2!.toStringAsFixed(2).replaceAll('.', ',')} m²';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(child: _statChip(Icons.straighten, 'Perimetro', perim)),
          const SizedBox(width: 8),
          Expanded(child: _statChip(Icons.crop_square, 'Area', area)),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hintBar() {
    String text;
    IconData icon;
    if (_toScale) {
      text = 'Vista in scala reale attiva. Modifica di forma disabilitata.';
      icon = Icons.aspect_ratio;
    } else {
      switch (_mode) {
        case EditMode.draw:
          text = _session.closed
              ? 'Forma chiusa. Usa Annulla per riaprirla.'
              : 'Tocca la griglia per aggiungere angoli (90°/45°). Tocca il primo angolo per chiudere.';
          icon = Icons.touch_app;
          break;
        case EditMode.move:
          text =
              'Trascina un angolo per spostarlo. Tieni premuto per eliminarlo.';
          icon = Icons.open_with;
          break;
        case EditMode.length:
          text = 'Tocca un lato per inserire la misura in cm.';
          icon = Icons.straighten;
          break;
        case EditMode.height:
          text = 'Tocca un angolo per registrare l\'altezza da terra.';
          icon = Icons.height;
          break;
      }
    }
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _canvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_viewInitialized) {
          _viewInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_session.vertices.isEmpty) {
              setState(() => _tc.value = _centerMatrix());
            } else {
              _fitToContent();
            }
          });
        }

        final points = _currentPoints();
        final highlight = (_mode == EditMode.draw &&
                !_toScale &&
                points.isNotEmpty &&
                !_session.closed)
            ? points.length - 1
            : null;

        return ClipRect(
          child: InteractiveViewer(
            transformationController: _tc,
            constrained: false,
            panEnabled: _mode != EditMode.move,
            minScale: 0.2,
            maxScale: 5,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: SizedBox(
              width: _canvasSize,
              height: _canvasSize,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _onTapDown,
                onPanStart: _mode == EditMode.move ? _onPanStart : null,
                onPanUpdate: _mode == EditMode.move ? _onPanUpdate : null,
                onPanEnd: _mode == EditMode.move ? _onPanEnd : null,
                onLongPressStart:
                    _mode == EditMode.move ? _onLongPressStart : null,
                child: CustomPaint(
                  size: const Size(_canvasSize, _canvasSize),
                  painter: MeasurePainter(
                    session: _session,
                    points: points,
                    showGrid: !_toScale,
                    gridOrigin: _origin,
                    gridCellSize: _cellSize,
                    highlightVertexIndex: highlight,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                _modeChip(EditMode.draw, Icons.edit, 'Disegna'),
                _modeChip(EditMode.move, Icons.open_with, 'Sposta'),
                _modeChip(EditMode.length, Icons.straighten, 'Misure'),
                _modeChip(EditMode.height, Icons.height, 'Altezze'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(
                  icon: Icons.undo,
                  label: 'Annulla',
                  onPressed: (_toScale || _session.vertices.isEmpty)
                      ? null
                      : _undo,
                ),
                _actionButton(
                  icon: _session.closed
                      ? Icons.lock_open
                      : Icons.check_circle_outline,
                  label: _session.closed ? 'Riapri' : 'Chiudi',
                  onPressed: (!_toScale && _session.vertices.length >= 3)
                      ? _toggleClose
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(EditMode mode, IconData icon, String label) {
    final disabled =
        _toScale && (mode == EditMode.draw || mode == EditMode.move);
    return ChoiceChip(
      avatar: Icon(icon,
          size: 18,
          color: _mode == mode
              ? Theme.of(context).colorScheme.onSecondaryContainer
              : null),
      label: Text(label),
      selected: _mode == mode,
      onSelected: disabled
          ? null
          : (_) => setState(() => _mode = mode),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}

/// Risultato del dialogo numerico: un valore, oppure la richiesta di cancellare.
class _NumberResult {
  final double value;
  final bool cleared;

  const _NumberResult(this.value) : cleared = false;
  const _NumberResult.cleared()
      : value = 0,
        cleared = true;
}

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/measure_session.dart';
import '../services/session_repository.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = SessionRepository();
  List<MeasureSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sessions = await _repo.loadAll();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _createSession() async {
    final name = await _askRoomName();
    if (name == null || name.trim().isEmpty) return;
    final now = DateTime.now();
    final session = MeasureSession(
      id: const Uuid().v4(),
      roomName: name.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _repo.upsert(session);
    if (!mounted) return;
    await _openEditor(session);
  }

  Future<String?> _askRoomName({String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome della stanza'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Es. Soggiorno, Camera 1...',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(MeasureSession session) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(session: session),
      ),
    );
    await _load();
  }

  Future<void> _deleteSession(MeasureSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina sessione'),
        content: Text('Eliminare "${session.roomName}"?'),
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
    if (ok == true) {
      await _repo.delete(session.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Le mie misure'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSession,
        icon: const Icon(Icons.add),
        label: const Text('Nuova stanza'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: _sessions.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final s = _sessions[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            s.roomName.isNotEmpty
                                ? s.roomName[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(s.roomName),
                        subtitle: Text(
                          '${s.segmentCount} lati · ${s.vertices.length} angoli · ${_formatDate(s.updatedAt)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteSession(s),
                        ),
                        onTap: () => _openEditor(s),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.straighten,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Nessuna sessione di misura',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tocca "Nuova stanza" per iniziare a disegnare e misurare.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

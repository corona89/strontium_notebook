import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/note.dart';
import '../state/app_controller.dart';
import 'dialogs.dart';

enum EditorMode { edit, preview, split }

class EditorPane extends StatefulWidget {
  const EditorPane({super.key});

  @override
  State<EditorPane> createState() => EditorPaneState();
}

class EditorPaneState extends State<EditorPane> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _tags = TextEditingController();
  Timer? _debounce;
  String? _boundId;
  EditorMode _mode = EditorMode.split;
  bool _dirty = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final note = context.watch<AppController>().selectedNote;
    _bind(note);
  }

  void _bind(Note? note) {
    if (note?.id == _boundId) return;
    if (_dirty && _boundId != null) {
      unawaited(save());
    }
    _boundId = note?.id;
    _title.text = note?.title ?? '';
    _body.text = note?.body ?? '';
    _tags.text = note?.tags.join(', ') ?? '';
    _dirty = false;
  }

  Future<void> save() async {
    final app = context.read<AppController>();
    final id = _boundId;
    if (id == null) return;
    _debounce?.cancel();
    await app.saveNote(
      id: id,
      title: _title.text,
      body: _body.text,
      tags: _parseTags(_tags.text),
    );
    if (mounted) setState(() => _dirty = false);
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _scheduleSave() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1400), save);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final note = app.selectedNote;
    if (note == null) {
      return const Center(child: Text(S.emptyEditor));
    }

    final wide = MediaQuery.sizeOf(context).width >= 900;
    final mode = wide ? _mode : (_mode == EditorMode.split ? EditorMode.edit : _mode);

    return Column(
      children: [
        Material(
          elevation: 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: note.favorite ? S.unfavorite : S.favorite,
                  onPressed: () => app.toggleFavorite(note.id),
                  icon: Icon(
                    note.favorite ? Icons.star : Icons.star_border,
                    color: note.favorite ? Colors.amber.shade700 : null,
                  ),
                ),
                IconButton(
                  tooltip: S.save,
                  onPressed: save,
                  icon: const Icon(Icons.save_outlined),
                ),
                SegmentedButton<EditorMode>(
                  segments: const [
                    ButtonSegment(
                      value: EditorMode.edit,
                      label: Text(S.edit),
                      icon: Icon(Icons.edit_outlined),
                    ),
                    ButtonSegment(
                      value: EditorMode.split,
                      label: Text(S.split),
                      icon: Icon(Icons.vertical_split),
                    ),
                    ButtonSegment(
                      value: EditorMode.preview,
                      label: Text(S.preview),
                      icon: Icon(Icons.visibility_outlined),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const Spacer(),
                if (_dirty)
                  Text(S.save, style: Theme.of(context).textTheme.labelSmall)
                else
                  Text(S.saved, style: Theme.of(context).textTheme.labelSmall),
                PopupMenuButton<String>(
                  onSelected: (v) => _menu(context, app, note, v),
                  itemBuilder: (context) => [
                    if (note.trashed) ...const [
                      PopupMenuItem(value: 'restore', child: Text(S.restoreNote)),
                      PopupMenuItem(
                        value: 'forever',
                        child: Text(S.deleteForever),
                      ),
                    ] else ...const [
                      PopupMenuItem(value: 'rename', child: Text(S.renameNote)),
                      PopupMenuItem(value: 'move', child: Text(S.moveNote)),
                      PopupMenuItem(value: 'delete', child: Text(S.deleteNote)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _title,
            style: Theme.of(context).textTheme.headlineSmall,
            decoration: const InputDecoration(hintText: S.titleHint),
            onChanged: (_) {
              setState(() {});
              _scheduleSave();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _tags,
            decoration: const InputDecoration(
              hintText: S.tagsHint,
              prefixIcon: Icon(Icons.sell_outlined, size: 18),
            ),
            onChanged: (_) => _scheduleSave(),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _bodyArea(mode)),
      ],
    );
  }

  Widget _bodyArea(EditorMode mode) {
    final editor = TextField(
      controller: _body,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(fontFamily: 'monospace', height: 1.45),
      decoration: const InputDecoration(
        hintText: S.bodyHint,
        contentPadding: EdgeInsets.all(16),
      ),
      onChanged: (_) {
        setState(() {});
        _scheduleSave();
      },
    );
    final preview = Markdown(
      data: _body.text.isEmpty ? '_${S.bodyHint}_' : _body.text,
      selectable: true,
      padding: const EdgeInsets.all(16),
    );
    switch (mode) {
      case EditorMode.edit:
        return editor;
      case EditorMode.preview:
        return preview;
      case EditorMode.split:
        return Row(
          children: [
            Expanded(child: editor),
            const VerticalDivider(width: 1),
            Expanded(child: preview),
          ],
        );
    }
  }

  Future<void> _menu(
    BuildContext context,
    AppController app,
    Note note,
    String value,
  ) async {
    switch (value) {
      case 'rename':
        final name = await promptText(
          context,
          title: S.renameNote,
          initial: note.title,
        );
        if (name != null && name.trim().isNotEmpty) {
          _title.text = name.trim();
          await save();
        }
      case 'move':
        final dest = await pickNotebook(
          context,
          notebooks: app.notebooks,
          current: note.notebookId,
        );
        if (dest != null) await app.moveNote(note.id, dest);
      case 'delete':
        final ok = await confirm(
          context,
          title: S.deleteNote,
          message: S.confirmDeleteNote,
        );
        if (ok) await app.trashNote(note.id);
      case 'restore':
        await app.restoreNote(note.id);
      case 'forever':
        final ok = await confirm(
          context,
          title: S.deleteForever,
          message: S.confirmDeleteForever,
        );
        if (ok) await app.deleteForever(note.id);
    }
  }
}

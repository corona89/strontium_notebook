import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/ids.dart';
import '../models/note.dart';
import '../state/app_controller.dart';
import 'dialogs.dart';

class NoteListPane extends StatefulWidget {
  const NoteListPane({
    super.key,
    this.onOpenNote,
    this.searchFocus,
  });

  final ValueChanged<Note>? onOpenNote;
  final FocusNode? searchFocus;

  @override
  State<NoteListPane> createState() => _NoteListPaneState();
}

class _NoteListPaneState extends State<NoteListPane> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: context.read<AppController>().searchQuery,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final notes = app.visibleNotes;
    final fmt = DateFormat.yMMMd('ko').add_Hm();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: widget.searchFocus,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: S.searchHint,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: app.setSearch,
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                tooltip: S.newNote,
                onPressed: () async {
                  final note = await app.createNote();
                  widget.onOpenNote?.call(note);
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _heading(app),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Text(
                    app.selectedNotebookId == SpecialIds.trash
                        ? S.emptyTrash
                        : (app.searchQuery.isEmpty ? S.emptyNotes : S.emptySearch),
                  ),
                )
              : ListView.separated(
                  itemCount: notes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final selected = note.id == app.selectedNoteId;
                    return ListTile(
                      selected: selected,
                      selectedTileColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      title: Text(
                        note.title.isEmpty ? S.untitled : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (note.favorite) '★',
                          fmt.format(note.updated.toLocal()),
                          if (note.tags.isNotEmpty) note.tags.join(', '),
                          note.body.trim().replaceAll(RegExp(r'\s+'), ' '),
                        ].where((e) => e.isNotEmpty).join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        app.selectNote(note.id);
                        widget.onOpenNote?.call(note);
                      },
                      onLongPress: () => _menu(context, app, note),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _heading(AppController app) {
    switch (app.selectedNotebookId) {
      case SpecialIds.all:
        return S.allNotes;
      case SpecialIds.inbox:
        return S.inbox;
      case SpecialIds.favorites:
        return S.favorites;
      case SpecialIds.trash:
        return S.trash;
      default:
        final tag = SpecialIds.tagName(app.selectedNotebookId);
        if (tag != null) return tag;
        return app.notebookById(app.selectedNotebookId)?.name ?? S.notebooks;
    }
  }

  Future<void> _menu(BuildContext context, AppController app, Note note) async {
    if (note.trashed) {
      final forever = await confirm(
        context,
        title: S.deleteForever,
        message: S.confirmDeleteForever,
      );
      if (forever) await app.deleteForever(note.id);
      return;
    }
    final dest = await pickNotebook(
      context,
      notebooks: app.notebooks,
      current: note.notebookId,
    );
    if (dest != null) await app.moveNote(note.id, dest);
  }
}

import '../models/ids.dart';
import '../models/note.dart';
import '../models/notebook.dart';

class NoteQuery {
  const NoteQuery({
    required this.notebookId,
    this.search = '',
    this.includeTrashed = false,
  });

  final String notebookId;
  final String search;
  final bool includeTrashed;
}

class NoteSearch {
  const NoteSearch();

  List<Note> filter({
    required List<Note> notes,
    required List<Notebook> notebooks,
    required NoteQuery query,
  }) {
    final q = query.search.trim().toLowerCase();
    final descendants = query.notebookId == SpecialIds.all ||
            SpecialIds.isVirtual(query.notebookId)
        ? <String>{}
        : _descendants(notebooks, query.notebookId);

    return notes.where((note) {
      final inTrashView = query.notebookId == SpecialIds.trash;
      if (inTrashView) {
        if (!note.trashed) return false;
      } else {
        if (note.trashed && !query.includeTrashed) return false;
      }

      switch (query.notebookId) {
        case SpecialIds.all:
          break;
        case SpecialIds.inbox:
          if (note.notebookId != SpecialIds.inbox) return false;
        case SpecialIds.favorites:
          if (!note.favorite) return false;
        case SpecialIds.trash:
          break;
        default:
          final tag = SpecialIds.tagName(query.notebookId);
          if (tag != null) {
            if (!note.tags.contains(tag)) return false;
          } else if (note.notebookId != query.notebookId &&
              !descendants.contains(note.notebookId)) {
            return false;
          }
      }

      if (q.isEmpty) return true;
      return note.title.toLowerCase().contains(q) ||
          note.body.toLowerCase().contains(q) ||
          note.tags.any((t) => t.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => b.updated.compareTo(a.updated));
  }

  Set<String> allTags(List<Note> notes) {
    final tags = <String>{};
    for (final note in notes.where((n) => !n.trashed)) {
      tags.addAll(note.tags);
    }
    return tags;
  }

  static Set<String> _descendants(List<Notebook> notebooks, String rootId) {
    final byParent = <String?, List<Notebook>>{};
    for (final nb in notebooks.where((n) => !n.trashed)) {
      byParent.putIfAbsent(nb.parentId, () => []).add(nb);
    }
    final out = <String>{};
    final stack = [rootId];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      for (final child in byParent[id] ?? const <Notebook>[]) {
        if (out.add(child.id)) stack.add(child.id);
      }
    }
    return out;
  }
}

String sanitizeFileName(String title, String id) {
  var slug = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), '_');
  slug = slug.replaceAll(RegExp(r'\s+'), ' ');
  if (slug.isEmpty) slug = 'untitled';
  if (slug.length > 48) slug = slug.substring(0, 48);
  final short = id.length <= 8 ? id : id.substring(0, 8);
  return '$slug-$short.md';
}

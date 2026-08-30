import 'package:uuid/uuid.dart';

import '../l10n/strings.dart';
import '../models/ids.dart';
import '../models/note.dart';
import '../models/note_document.dart';
import '../models/notebook.dart';
import 'drive_api.dart';
import 'local_cache.dart';
import 'note_search.dart';
import 'sync_engine.dart';

class SyncResult {
  const SyncResult({
    required this.snapshot,
    this.pulled = 0,
    this.pushed = 0,
    this.conflicts = 0,
    this.message = '',
  });

  final CacheSnapshot snapshot;
  final int pulled;
  final int pushed;
  final int conflicts;
  final String message;
}

/// Drive 트리와 로컬 캐시를 맞춘다. 충돌 시 진 쪽을 충돌 사본으로 남긴다.
class SyncService {
  SyncService({required this.drive, SyncEngine? engine})
      : engine = engine ?? const SyncEngine();

  final DriveApi drive;
  final SyncEngine engine;
  final _uuid = const Uuid();

  Future<SyncResult> sync(CacheSnapshot local) async {
    final rootId = await drive.ensureRootFolder();
    local.rootFolderId = rootId;

    final tree = await drive.listTree(rootId);
    _mergeFolders(local, tree);

    var pulled = 0;
    var pushed = 0;
    var conflicts = 0;

    final remoteById = {for (final f in tree.files) f.id: f};
    final localByDrive = <String, Note>{
      for (final n in local.notes)
        if (n.driveFileId != null) n.driveFileId!: n,
    };

    for (final remote in tree.files) {
      final existing = localByDrive[remote.id];
      if (existing == null) {
        await _pullNew(local, tree, remote);
        pulled++;
        continue;
      }
      final raw = await drive.download(remote.id);
      final doc = NoteDocument.parse(raw);
      final remoteUpdated = _newer(doc.updated, remote.modifiedTime);
      final same = existing.title ==
              (doc.title.isEmpty ? existing.title : doc.title) &&
          existing.body == doc.body &&
          _sameTags(existing.tags, doc.tags) &&
          existing.favorite == doc.favorite &&
          existing.trashed == remote.trashed;
      final verdict = engine.decide(
        localExists: true,
        remoteExists: true,
        localDirty: existing.dirty,
        localUpdated: existing.updated,
        remoteUpdated: remoteUpdated,
        contentsDiffer: !same,
        remoteDeletedKnown: false,
      );
      final result = await _apply(
        local,
        tree,
        existing,
        remote,
        verdict,
        remoteDoc: doc,
      );
      pulled += result.pulled;
      pushed += result.pushed;
      conflicts += result.conflicts;
    }

    for (final note in List<Note>.from(local.notes)) {
      if (note.trashed) {
        if (note.dirty && note.driveFileId != null) {
          try {
            await drive.trash(note.driveFileId!);
            _replace(local, note.copyWith(dirty: false));
            pushed++;
          } catch (_) {}
        } else if (note.dirty && note.driveFileId == null) {
          // 업로드된 적 없는 로컬 휴지통은 Drive에 올리지 않는다.
        }
        continue;
      }
      if (note.driveFileId != null && remoteById.containsKey(note.driveFileId)) {
        continue;
      }
      final verdict = engine.decide(
        localExists: true,
        remoteExists: false,
        localDirty: note.dirty,
        localUpdated: note.updated,
        remoteUpdated: null,
        contentsDiffer: true,
        remoteDeletedKnown: note.driveFileId != null,
      );
      if (verdict.op == SyncOp.trashLocal) {
        _replace(local, note.copyWith(trashed: true, dirty: false));
        continue;
      }
      if (verdict.op == SyncOp.push ||
          verdict.op == SyncOp.pushKeepRemoteConflict) {
        await _push(local, tree, note);
        pushed++;
      }
    }

    for (var i = 0; i < local.notebooks.length; i++) {
      final nb = local.notebooks[i];
      if (nb.trashed) {
        if (nb.driveFolderId != null && nb.dirty) {
          try {
            await drive.trash(nb.driveFolderId!);
            local.notebooks[i] = nb.copyWith(dirty: false);
          } catch (_) {}
        }
        continue;
      }
      if (nb.driveFolderId != null) continue;
      final parentDrive = _parentDriveId(local, tree, nb.parentId);
      final created = await drive.createFolder(
        name: nb.name,
        parentId: parentDrive,
      );
      local.notebooks[i] = nb.copyWith(
        driveFolderId: created.id,
        dirty: false,
      );
    }

    local.lastSync = DateTime.now().toUtc();
    return SyncResult(
      snapshot: local,
      pulled: pulled,
      pushed: pushed,
      conflicts: conflicts,
      message: S.synced,
    );
  }

  void _mergeFolders(CacheSnapshot local, DriveTree tree) {
    final byDrive = {
      for (final n in local.notebooks)
        if (n.driveFolderId != null) n.driveFolderId!: n,
    };
    for (final folder in tree.folders) {
      final existing = byDrive[folder.id];
      if (existing != null) {
        if (!existing.dirty) {
          final idx = local.notebooks.indexWhere((n) => n.id == existing.id);
          local.notebooks[idx] = existing.copyWith(
            name: folder.name,
            parentId: _localParent(local, tree, folder.parentId),
          );
        }
        continue;
      }
      local.notebooks.add(
        Notebook(
          id: _uuid.v4(),
          name: folder.name,
          parentId: _localParent(local, tree, folder.parentId),
          driveFolderId: folder.id,
        ),
      );
    }
  }

  String? _localParent(CacheSnapshot local, DriveTree tree, String? driveParent) {
    if (driveParent == null || driveParent == tree.rootId) return null;
    for (final n in local.notebooks) {
      if (n.driveFolderId == driveParent) return n.id;
    }
    return null;
  }

  String _parentDriveId(CacheSnapshot local, DriveTree tree, String? notebookId) {
    if (notebookId == null ||
        notebookId == SpecialIds.inbox ||
        SpecialIds.isVirtual(notebookId)) {
      return tree.rootId;
    }
    final nb = local.notebooks.cast<Notebook?>().firstWhere(
          (n) => n!.id == notebookId,
          orElse: () => null,
        );
    return nb?.driveFolderId ?? tree.rootId;
  }

  Future<void> _pullNew(
    CacheSnapshot local,
    DriveTree tree,
    DriveMarkdown remote,
  ) async {
    final raw = await drive.download(remote.id);
    final doc = NoteDocument.parse(raw);
    final notebookId = _notebookIdForParent(local, tree, remote.parentId);
    local.notes.add(
      Note(
        id: _uuid.v4(),
        notebookId: notebookId,
        title: doc.title.isEmpty ? _titleFromName(remote.name) : doc.title,
        body: doc.body,
        updated: _newer(doc.updated, remote.modifiedTime),
        fileName: remote.name,
        tags: doc.tags,
        favorite: doc.favorite,
        driveFileId: remote.id,
        remoteModified: remote.modifiedTime,
        trashed: remote.trashed,
      ),
    );
  }

  Future<({int pulled, int pushed, int conflicts})> _apply(
    CacheSnapshot local,
    DriveTree tree,
    Note localNote,
    DriveMarkdown remote,
    SyncVerdict verdict, {
    required NoteDocument remoteDoc,
  }) async {
    var pulled = 0;
    var pushed = 0;
    var conflicts = 0;
    switch (verdict.op) {
      case SyncOp.skip:
        if (remote.trashed != localNote.trashed && !localNote.dirty) {
          _replace(local, localNote.copyWith(trashed: remote.trashed));
        }
      case SyncOp.pull:
        _overwriteFromRemote(local, tree, localNote, remote, remoteDoc);
        pulled++;
      case SyncOp.pullKeepLocalConflict:
        _addConflictCopy(local, localNote);
        _overwriteFromRemote(local, tree, localNote, remote, remoteDoc);
        pulled++;
        conflicts++;
      case SyncOp.push:
      case SyncOp.pushKeepRemoteConflict:
        if (verdict.op == SyncOp.pushKeepRemoteConflict) {
          _addConflictCopy(
            local,
            localNote.copyWith(
              title: remoteDoc.title.isEmpty ? localNote.title : remoteDoc.title,
              body: remoteDoc.body,
              tags: remoteDoc.tags,
              favorite: remoteDoc.favorite,
              updated: remoteDoc.updated,
            ),
          );
          conflicts++;
        }
        await _push(local, tree, localNote, remoteId: remote.id);
        pushed++;
      case SyncOp.trashLocal:
        _replace(local, localNote.copyWith(trashed: true, dirty: false));
    }
    return (pulled: pulled, pushed: pushed, conflicts: conflicts);
  }

  void _overwriteFromRemote(
    CacheSnapshot local,
    DriveTree tree,
    Note localNote,
    DriveMarkdown remote,
    NoteDocument doc,
  ) {
    _replace(
      local,
      localNote.copyWith(
        title: doc.title.isEmpty ? _titleFromName(remote.name) : doc.title,
        body: doc.body,
        updated: _newer(doc.updated, remote.modifiedTime),
        fileName: remote.name,
        tags: doc.tags,
        favorite: doc.favorite,
        notebookId: _notebookIdForParent(local, tree, remote.parentId),
        driveFileId: remote.id,
        remoteModified: remote.modifiedTime,
        dirty: false,
        trashed: remote.trashed,
      ),
    );
  }

  Future<void> _push(
    CacheSnapshot local,
    DriveTree tree,
    Note note, {
    String? remoteId,
  }) async {
    final doc = NoteDocument(
      title: note.title,
      body: note.body,
      updated: note.updated,
      tags: note.tags,
      favorite: note.favorite,
    );
    final parent = _parentDriveId(local, tree, note.notebookId);
    final name = note.fileName.isEmpty
        ? sanitizeFileName(note.title, note.id)
        : note.fileName;
    final id = remoteId ?? note.driveFileId;
    if (id == null) {
      final created = await drive.createMarkdown(
        parentId: parent,
        name: name,
        content: doc.encode(),
      );
      _replace(
        local,
        note.copyWith(
          driveFileId: created.id,
          fileName: name,
          dirty: false,
          remoteModified: created.modifiedTime?.toUtc(),
        ),
      );
      return;
    }
    try {
      await drive.moveFile(id, parent);
    } catch (_) {
      // 부모를 못 옮기면 내용만이라도 올린다.
    }
    final updated = await drive.updateMarkdown(
      fileId: id,
      content: doc.encode(),
      name: name,
    );
    _replace(
      local,
      note.copyWith(
        dirty: false,
        fileName: name,
        remoteModified: updated.modifiedTime?.toUtc(),
      ),
    );
  }

  void _addConflictCopy(CacheSnapshot local, Note source) {
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '');
    final id = _uuid.v4();
    local.notes.add(
      Note(
        id: id,
        notebookId: source.notebookId,
        title: '${source.title} (${S.conflictCopy})',
        body: source.body,
        updated: DateTime.now().toUtc(),
        fileName: sanitizeFileName('${source.title}-conflict-$stamp', id),
        tags: {...source.tags, S.conflictCopy}.toList(),
        favorite: source.favorite,
        dirty: true,
      ),
    );
  }

  void _replace(CacheSnapshot local, Note note) {
    final i = local.notes.indexWhere((n) => n.id == note.id);
    if (i >= 0) {
      local.notes[i] = note;
    } else {
      local.notes.add(note);
    }
  }

  String _notebookIdForParent(
    CacheSnapshot local,
    DriveTree tree,
    String parentId,
  ) {
    if (parentId == tree.rootId) return SpecialIds.inbox;
    for (final n in local.notebooks) {
      if (n.driveFolderId == parentId) return n.id;
    }
    return SpecialIds.inbox;
  }

  DateTime _newer(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }

  String _titleFromName(String name) {
    var t = name;
    if (t.toLowerCase().endsWith('.md')) {
      t = t.substring(0, t.length - 3);
    }
    return t;
  }
}

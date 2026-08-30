import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../l10n/strings.dart';
import '../models/ids.dart';
import '../models/note.dart';
import '../models/notebook.dart';
import '../models/oauth_config.dart';
import '../services/auth_service.dart';
import '../services/drive_api.dart';
import '../services/local_cache.dart';
import '../services/note_search.dart';
import '../services/oauth_config_store.dart';
import '../services/sync_service.dart';

enum AppPhase { loading, connect, ready }

class AppController extends ChangeNotifier {
  AppController({
    required this.cache,
    required this.auth,
    required this.oauth,
    CacheSnapshot? snapshot,
  }) : snapshot = snapshot ??
            CacheSnapshot(
              rootFolderId: DriveConstants.knownFolderId,
              notebooks: [],
              notes: [],
            );

  final LocalCache cache;
  final AuthService auth;
  final OauthConfig oauth;
  CacheSnapshot snapshot;
  final _uuid = const Uuid();
  final _search = const NoteSearch();

  AppPhase phase = AppPhase.loading;
  String selectedNotebookId = SpecialIds.all;
  String? selectedNoteId;
  String searchQuery = '';
  String? status;
  String? error;
  bool syncing = false;
  bool offline = false;

  static Future<AppController> bootstrap() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'strontium_notebook'));
    final cache = LocalCache(dir);
    final snapshot = await cache.load();
    final oauth = await const OauthConfigStore().load(extraDir: dir);
    final auth = AuthService(config: oauth);
    final controller = AppController(
      cache: cache,
      auth: auth,
      oauth: oauth,
      snapshot: snapshot,
    );
    try {
      await auth.restore();
    } catch (_) {}
    if (auth.isSignedIn) {
      controller.phase = AppPhase.ready;
      await controller.syncNow();
    } else if (snapshot.notes.isNotEmpty || snapshot.notebooks.isNotEmpty) {
      controller.phase = AppPhase.ready;
      controller.offline = true;
      controller.status = S.offline;
    } else {
      controller.phase = AppPhase.connect;
    }
    controller.notifyListeners();
    return controller;
  }

  bool get signedIn => auth.isSignedIn;

  String? get accountEmail => auth.session?.email;

  List<Notebook> get notebooks =>
      snapshot.notebooks.where((n) => !n.trashed).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<Note> get visibleNotes => _search.filter(
        notes: snapshot.notes,
        notebooks: snapshot.notebooks,
        query: NoteQuery(
          notebookId: selectedNotebookId,
          search: searchQuery,
        ),
      );

  Set<String> get tags => _search.allTags(snapshot.notes);

  Note? get selectedNote {
    if (selectedNoteId == null) return null;
    for (final n in snapshot.notes) {
      if (n.id == selectedNoteId) return n;
    }
    return null;
  }

  Notebook? notebookById(String id) {
    for (final n in snapshot.notebooks) {
      if (n.id == id) return n;
    }
    return null;
  }

  Future<void> persist() => cache.save(snapshot);

  Future<void> startOffline() async {
    phase = AppPhase.ready;
    offline = true;
    status = S.offline;
    error = null;
    notifyListeners();
  }

  Future<void> connectDrive() async {
    error = null;
    status = S.connecting;
    notifyListeners();
    try {
      await auth.signIn();
      phase = AppPhase.ready;
      offline = false;
      status = null;
      notifyListeners();
      await syncNow();
    } on AuthCancelled {
      status = null;
      notifyListeners();
    } on AuthConfigMissing {
      error = S.oauthMissing;
      status = null;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      status = null;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await auth.signOut();
    offline = true;
    status = S.notSignedIn;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (!auth.isSignedIn) {
      offline = true;
      status = S.offline;
      notifyListeners();
      return;
    }
    syncing = true;
    error = null;
    status = S.syncing;
    notifyListeners();
    try {
      final api = DriveApi(auth.session!.client);
      final result = await SyncService(drive: api).sync(snapshot);
      snapshot = result.snapshot;
      await persist();
      offline = false;
      status = result.conflicts > 0
          ? '${S.synced} · 충돌 사본 ${result.conflicts}'
          : S.synced;
    } on SocketException {
      offline = true;
      status = S.offline;
    } catch (e) {
      error = e.toString();
      status = S.offline;
      offline = true;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  void selectNotebook(String id) {
    selectedNotebookId = id;
    selectedNoteId = null;
    notifyListeners();
  }

  void selectNote(String? id) {
    selectedNoteId = id;
    notifyListeners();
  }

  void setSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  Future<Notebook> createNotebook({
    required String name,
    String? parentId,
  }) async {
    final nb = Notebook(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? S.notebooks : name.trim(),
      parentId: parentId,
      dirty: true,
    );
    snapshot.notebooks.add(nb);
    await persist();
    notifyListeners();
    if (signedIn) await syncNow();
    return nb;
  }

  Future<void> renameNotebook(String id, String name) async {
    final i = snapshot.notebooks.indexWhere((n) => n.id == id);
    if (i < 0) return;
    snapshot.notebooks[i] =
        snapshot.notebooks[i].copyWith(name: name.trim(), dirty: true);
    await persist();
    notifyListeners();
    if (signedIn) {
      final driveId = snapshot.notebooks[i].driveFolderId;
      if (driveId != null) {
        try {
          await DriveApi(auth.session!.client).rename(driveId, name.trim());
          snapshot.notebooks[i] = snapshot.notebooks[i].copyWith(dirty: false);
          await persist();
        } catch (_) {
          await syncNow();
        }
      } else {
        await syncNow();
      }
    }
    notifyListeners();
  }

  Future<void> deleteNotebook(String id) async {
    final i = snapshot.notebooks.indexWhere((n) => n.id == id);
    if (i < 0) return;
    snapshot.notebooks[i] =
        snapshot.notebooks[i].copyWith(trashed: true, dirty: true);
    for (var n = 0; n < snapshot.notes.length; n++) {
      if (snapshot.notes[n].notebookId == id) {
        snapshot.notes[n] =
            snapshot.notes[n].copyWith(trashed: true, dirty: true);
      }
    }
    if (selectedNotebookId == id) selectedNotebookId = SpecialIds.all;
    await persist();
    notifyListeners();
    if (signedIn) await syncNow();
  }

  Future<Note> createNote({String? notebookId, String? title}) async {
    final dest = _realNotebookId(notebookId ?? selectedNotebookId);
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final note = Note(
      id: id,
      notebookId: dest,
      title: title?.trim().isNotEmpty == true ? title!.trim() : S.untitled,
      body: '',
      updated: now,
      fileName: sanitizeFileName(title ?? S.untitled, id),
      dirty: true,
    );
    snapshot.notes.add(note);
    selectedNoteId = id;
    await persist();
    notifyListeners();
    return note;
  }

  Future<void> saveNote({
    required String id,
    String? title,
    String? body,
    List<String>? tags,
    bool? favorite,
    String? notebookId,
    String? fileName,
  }) async {
    final i = snapshot.notes.indexWhere((n) => n.id == id);
    if (i < 0) return;
    final prev = snapshot.notes[i];
    var nextTitle = title ?? prev.title;
    if (nextTitle.trim().isEmpty) nextTitle = S.untitled;
    snapshot.notes[i] = prev.copyWith(
      title: nextTitle,
      body: body ?? prev.body,
      tags: tags ?? prev.tags,
      favorite: favorite ?? prev.favorite,
      notebookId: notebookId ?? prev.notebookId,
      fileName: fileName ??
          (title != null ? sanitizeFileName(nextTitle, id) : prev.fileName),
      updated: DateTime.now().toUtc(),
      dirty: true,
    );
    await persist();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final note = snapshot.notes.cast<Note?>().firstWhere(
          (n) => n!.id == id,
          orElse: () => null,
        );
    if (note == null) return;
    await saveNote(id: id, favorite: !note.favorite);
  }

  Future<void> moveNote(String id, String notebookId) async {
    await saveNote(id: id, notebookId: _realNotebookId(notebookId));
    if (signedIn) await syncNow();
  }

  Future<void> trashNote(String id) async {
    final i = snapshot.notes.indexWhere((n) => n.id == id);
    if (i < 0) return;
    snapshot.notes[i] = snapshot.notes[i].copyWith(
      trashed: true,
      dirty: true,
      updated: DateTime.now().toUtc(),
    );
    if (selectedNoteId == id) selectedNoteId = null;
    await persist();
    notifyListeners();
    if (signedIn) await syncNow();
  }

  Future<void> restoreNote(String id) async {
    final i = snapshot.notes.indexWhere((n) => n.id == id);
    if (i < 0) return;
    snapshot.notes[i] = snapshot.notes[i].copyWith(
      trashed: false,
      dirty: true,
      updated: DateTime.now().toUtc(),
    );
    await persist();
    notifyListeners();
    if (signedIn) {
      final driveId = snapshot.notes[i].driveFileId;
      if (driveId != null) {
        try {
          await DriveApi(auth.session!.client).untrash(driveId);
          snapshot.notes[i] = snapshot.notes[i].copyWith(dirty: false);
          await persist();
        } catch (_) {
          await syncNow();
        }
      }
    }
    notifyListeners();
  }

  Future<void> deleteForever(String id) async {
    final i = snapshot.notes.indexWhere((n) => n.id == id);
    if (i < 0) return;
    final driveId = snapshot.notes[i].driveFileId;
    snapshot.notes.removeAt(i);
    if (selectedNoteId == id) selectedNoteId = null;
    await persist();
    notifyListeners();
    if (signedIn && driveId != null) {
      try {
        await DriveApi(auth.session!.client).deleteForever(driveId);
      } catch (_) {}
    }
  }

  String _realNotebookId(String id) {
    if (id == SpecialIds.inbox || !SpecialIds.isVirtual(id)) return id;
    return SpecialIds.inbox;
  }
}

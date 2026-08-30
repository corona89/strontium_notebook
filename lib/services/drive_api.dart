import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../models/ids.dart';

class DriveFolder {
  const DriveFolder({
    required this.id,
    required this.name,
    required this.parentId,
  });

  final String id;
  final String name;
  final String? parentId;
}

class DriveMarkdown {
  const DriveMarkdown({
    required this.id,
    required this.name,
    required this.parentId,
    required this.modifiedTime,
    required this.trashed,
  });

  final String id;
  final String name;
  final String parentId;
  final DateTime modifiedTime;
  final bool trashed;
}

class DriveTree {
  const DriveTree({
    required this.rootId,
    required this.folders,
    required this.files,
  });

  final String rootId;
  final List<DriveFolder> folders;
  final List<DriveMarkdown> files;
}

/// Drive API v3. 기존 `strontium_notebook` 폴더를 id → 이름 → 생성 순으로 연다.
class DriveApi {
  DriveApi(http.Client client) : _api = drive.DriveApi(client);

  final drive.DriveApi _api;

  Future<String> ensureRootFolder() async {
    final known = await _getFolder(DriveConstants.knownFolderId);
    if (known != null && known.trashed != true) {
      return known.id!;
    }

    final found = await _findFolderByName(DriveConstants.folderName);
    if (found != null) return found;

    final created = await _api.files.create(
      drive.File()
        ..name = DriveConstants.folderName
        ..mimeType = DriveConstants.folderMime,
      $fields: 'id,name',
    );
    return created.id!;
  }

  Future<DriveTree> listTree(String rootId) async {
    final folders = <DriveFolder>[];
    final files = <DriveMarkdown>[];
    final queue = <String>[rootId];
    final seen = <String>{rootId};

    while (queue.isNotEmpty) {
      final parent = queue.removeAt(0);
      final children = await _listChildren(parent);
      for (final f in children) {
        final id = f.id;
        if (id == null) continue;
        final isFolder = f.mimeType == DriveConstants.folderMime;
        final name = f.name ?? '';
        if (isFolder) {
          if (name == DriveConstants.trashFolderName) continue;
          folders.add(
            DriveFolder(
              id: id,
              name: name,
              parentId: parent == rootId ? null : parent,
            ),
          );
          if (seen.add(id)) queue.add(id);
        } else if (name.toLowerCase().endsWith('.md')) {
          files.add(
            DriveMarkdown(
              id: id,
              name: name,
              parentId: parent,
              modifiedTime: f.modifiedTime?.toUtc() ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              trashed: f.trashed == true,
            ),
          );
        }
      }
    }

    final trashed = await _listTrashedMarkdown(rootId);
    files.addAll(trashed);
    return DriveTree(rootId: rootId, folders: folders, files: files);
  }

  Future<String> download(String fileId) async {
    final media = await _api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final chunks = <int>[];
    await for (final chunk in media.stream) {
      chunks.addAll(chunk);
    }
    return utf8.decode(chunks);
  }

  Future<drive.File> createMarkdown({
    required String parentId,
    required String name,
    required String content,
  }) {
    final bytes = utf8.encode(content);
    return _api.files.create(
      drive.File()
        ..name = name
        ..parents = [parentId]
        ..mimeType = DriveConstants.markdownMime,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      $fields: 'id,name,modifiedTime,parents',
    );
  }

  Future<drive.File> updateMarkdown({
    required String fileId,
    required String content,
    String? name,
    String? addParent,
    String? removeParent,
  }) {
    final bytes = utf8.encode(content);
    return _api.files.update(
      drive.File()..name = name,
      fileId,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      addParents: addParent,
      removeParents: removeParent,
      $fields: 'id,name,modifiedTime,parents,trashed',
    );
  }

  Future<drive.File> createFolder({
    required String name,
    String? parentId,
  }) {
    return _api.files.create(
      drive.File()
        ..name = name
        ..parents = parentId == null ? null : [parentId]
        ..mimeType = DriveConstants.folderMime,
      $fields: 'id,name,parents',
    );
  }

  Future<void> moveFile(String fileId, String newParentId) async {
    final file = await _api.files.get(fileId, $fields: 'parents') as drive.File;
    final stale = (file.parents ?? const <String>[])
        .where((p) => p != newParentId)
        .join(',');
    await _api.files.update(
      drive.File(),
      fileId,
      addParents: newParentId,
      removeParents: stale.isEmpty ? null : stale,
    );
  }

  Future<void> rename(String fileId, String name) async {
    await _api.files.update(drive.File()..name = name, fileId);
  }

  Future<void> trash(String fileId) async {
    await _api.files.update(drive.File()..trashed = true, fileId);
  }

  Future<void> untrash(String fileId) async {
    await _api.files.update(drive.File()..trashed = false, fileId);
  }

  Future<void> deleteForever(String fileId) async {
    await _api.files.delete(fileId);
  }

  Future<drive.File?> _getFolder(String id) async {
    try {
      final file = await _api.files.get(
        id,
        $fields: 'id,name,mimeType,trashed',
      ) as drive.File;
      if (file.mimeType != DriveConstants.folderMime) return null;
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _findFolderByName(String name) async {
    final escaped = name.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    String? pageToken;
    do {
      final result = await _api.files.list(
        q: "name = '$escaped' and mimeType = '${DriveConstants.folderMime}' "
            'and trashed = false',
        spaces: 'drive',
        pageToken: pageToken,
        $fields: 'nextPageToken,files(id,name)',
        pageSize: 20,
      );
      final files = result.files ?? const <drive.File>[];
      for (final f in files) {
        if (f.id == DriveConstants.knownFolderId) return f.id;
      }
      if (files.isNotEmpty) return files.first.id;
      pageToken = result.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return null;
  }

  Future<List<drive.File>> _listChildren(String parentId) async {
    final out = <drive.File>[];
    String? pageToken;
    do {
      final result = await _api.files.list(
        q: "'$parentId' in parents and trashed = false",
        spaces: 'drive',
        pageToken: pageToken,
        pageSize: 100,
        $fields: 'nextPageToken,files(id,name,mimeType,modifiedTime,trashed,parents)',
      );
      out.addAll(result.files ?? const []);
      pageToken = result.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return out;
  }

  Future<List<DriveMarkdown>> _listTrashedMarkdown(String rootId) async {
    final out = <DriveMarkdown>[];
    String? pageToken;
    do {
      final result = await _api.files.list(
        q: "trashed = true and mimeType != '${DriveConstants.folderMime}'",
        spaces: 'drive',
        pageToken: pageToken,
        pageSize: 100,
        $fields: 'nextPageToken,files(id,name,mimeType,modifiedTime,trashed,parents)',
      );
      for (final f in result.files ?? const <drive.File>[]) {
        final name = f.name ?? '';
        if (!name.toLowerCase().endsWith('.md')) continue;
        final parents = f.parents ?? const <String>[];
        if (parents.isEmpty) continue;
        out.add(
          DriveMarkdown(
            id: f.id!,
            name: name,
            parentId: parents.first,
            modifiedTime: f.modifiedTime?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            trashed: true,
          ),
        );
      }
      pageToken = result.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return out;
  }
}

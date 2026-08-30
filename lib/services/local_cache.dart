import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/ids.dart';
import '../models/note.dart';
import '../models/notebook.dart';

class CacheSnapshot {
  CacheSnapshot({
    required this.rootFolderId,
    required this.notebooks,
    required this.notes,
    this.lastSync,
  });

  String? rootFolderId;
  List<Notebook> notebooks;
  List<Note> notes;
  DateTime? lastSync;

  Map<String, dynamic> toJson() => {
        'rootFolderId': rootFolderId,
        'lastSync': lastSync?.toUtc().toIso8601String(),
        'notebooks': notebooks.map((e) => e.toJson()).toList(),
        'notes': notes.map((e) => e.toJson()).toList(),
      };

  factory CacheSnapshot.fromJson(Map<String, dynamic> json) {
    return CacheSnapshot(
      rootFolderId: json['rootFolderId'] as String?,
      lastSync: DateTime.tryParse(json['lastSync'] as String? ?? '')?.toUtc(),
      notebooks: (json['notebooks'] as List<dynamic>? ?? [])
          .map((e) => Notebook.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      notes: (json['notes'] as List<dynamic>? ?? [])
          .map((e) => Note.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// 앱 지원 디렉터리의 index.json. 오프라인에서 노트북/노트를 그대로 쓴다.
class LocalCache {
  LocalCache(this.directory);

  final Directory directory;

  File get _index => File(p.join(directory.path, 'index.json'));

  Future<CacheSnapshot> load() async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    if (!await _index.exists()) {
      return CacheSnapshot(rootFolderId: DriveConstants.knownFolderId, notebooks: [], notes: []);
    }
    try {
      final json = jsonDecode(await _index.readAsString());
      if (json is Map) {
        return CacheSnapshot.fromJson(json.cast<String, dynamic>());
      }
    } catch (_) {}
    return CacheSnapshot(rootFolderId: DriveConstants.knownFolderId, notebooks: [], notes: []);
  }

  Future<void> save(CacheSnapshot snapshot) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    await _index.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );
  }
}

class Note {
  const Note({
    required this.id,
    required this.notebookId,
    required this.title,
    required this.body,
    required this.updated,
    required this.fileName,
    this.tags = const [],
    this.favorite = false,
    this.driveFileId,
    this.remoteModified,
    this.dirty = false,
    this.trashed = false,
  });

  final String id;
  final String notebookId;
  final String title;
  final String body;
  final DateTime updated;
  final String fileName;
  final List<String> tags;
  final bool favorite;
  final String? driveFileId;
  final DateTime? remoteModified;
  final bool dirty;
  final bool trashed;

  Note copyWith({
    String? id,
    String? notebookId,
    String? title,
    String? body,
    DateTime? updated,
    String? fileName,
    List<String>? tags,
    bool? favorite,
    String? driveFileId,
    DateTime? remoteModified,
    bool? dirty,
    bool? trashed,
    bool clearDrive = false,
  }) {
    return Note(
      id: id ?? this.id,
      notebookId: notebookId ?? this.notebookId,
      title: title ?? this.title,
      body: body ?? this.body,
      updated: updated ?? this.updated,
      fileName: fileName ?? this.fileName,
      tags: tags ?? this.tags,
      favorite: favorite ?? this.favorite,
      driveFileId: clearDrive ? null : (driveFileId ?? this.driveFileId),
      remoteModified: remoteModified ?? this.remoteModified,
      dirty: dirty ?? this.dirty,
      trashed: trashed ?? this.trashed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notebookId': notebookId,
        'title': title,
        'body': body,
        'updated': updated.toUtc().toIso8601String(),
        'fileName': fileName,
        'tags': tags,
        'favorite': favorite,
        'driveFileId': driveFileId,
        'remoteModified': remoteModified?.toUtc().toIso8601String(),
        'dirty': dirty,
        'trashed': trashed,
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      notebookId: json['notebookId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      updated: DateTime.tryParse(json['updated'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      fileName: json['fileName'] as String? ?? 'note.md',
      tags: (json['tags'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      favorite: json['favorite'] == true,
      driveFileId: json['driveFileId'] as String?,
      remoteModified:
          DateTime.tryParse(json['remoteModified'] as String? ?? '')?.toUtc(),
      dirty: json['dirty'] == true,
      trashed: json['trashed'] == true,
    );
  }
}

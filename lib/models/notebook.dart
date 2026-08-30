class Notebook {
  const Notebook({
    required this.id,
    required this.name,
    this.parentId,
    this.driveFolderId,
    this.dirty = false,
    this.trashed = false,
  });

  final String id;
  final String name;
  final String? parentId;
  final String? driveFolderId;
  final bool dirty;
  final bool trashed;

  Notebook copyWith({
    String? id,
    String? name,
    String? parentId,
    String? driveFolderId,
    bool? dirty,
    bool? trashed,
    bool clearParent = false,
    bool clearDrive = false,
  }) {
    return Notebook(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      driveFolderId: clearDrive ? null : (driveFolderId ?? this.driveFolderId),
      dirty: dirty ?? this.dirty,
      trashed: trashed ?? this.trashed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parentId': parentId,
        'driveFolderId': driveFolderId,
        'dirty': dirty,
        'trashed': trashed,
      };

  factory Notebook.fromJson(Map<String, dynamic> json) {
    return Notebook(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      parentId: json['parentId'] as String?,
      driveFolderId: json['driveFolderId'] as String?,
      dirty: json['dirty'] == true,
      trashed: json['trashed'] == true,
    );
  }
}

import 'package:yaml/yaml.dart';

/// `.md` 파일의 YAML 프론트매터 + 본문.
class NoteDocument {
  const NoteDocument({
    required this.title,
    required this.body,
    required this.updated,
    this.tags = const [],
    this.favorite = false,
    this.extra = const {},
  });

  final String title;
  final String body;
  final DateTime updated;
  final List<String> tags;
  final bool favorite;
  final Map<String, dynamic> extra;

  static final _frontmatter = RegExp(
    r'^---\r?\n([\s\S]*?)\r?\n---\r?\n?',
  );

  static NoteDocument parse(String raw) {
    final match = _frontmatter.firstMatch(raw);
    if (match == null) {
      return NoteDocument(
        title: _firstHeading(raw),
        body: raw,
        updated: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    }
    final yamlBlock = match.group(1) ?? '';
    final body = raw.substring(match.end);
    Map<dynamic, dynamic> map = {};
    try {
      final loaded = loadYaml(yamlBlock);
      if (loaded is YamlMap) {
        map = loaded;
      }
    } catch (_) {
      // 깨진 프론트매터는 본문에 그대로 두고 최소 필드로 복구한다.
      return NoteDocument(
        title: _firstHeading(body),
        body: raw,
        updated: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    }

    final tags = <String>[];
    final rawTags = map['tags'];
    if (rawTags is YamlList) {
      tags.addAll(rawTags.map((e) => '$e'.trim()).where((e) => e.isNotEmpty));
    } else if (rawTags is String && rawTags.trim().isNotEmpty) {
      tags.addAll(
        rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }

    final extra = <String, dynamic>{};
    map.forEach((key, value) {
      final k = '$key';
      if (k == 'title' || k == 'tags' || k == 'updated' || k == 'favorite') {
        return;
      }
      extra[k] = _unwrapYaml(value);
    });

    return NoteDocument(
      title: '${map['title'] ?? ''}'.trim(),
      body: body,
      updated: _parseTime(map['updated']),
      tags: tags,
      favorite: map['favorite'] == true || map['favorite'] == 'true',
      extra: extra,
    );
  }

  String encode() {
    final tagList = tags.map(_yamlScalar).join(', ');
    final extraLines = extra.entries
        .map((e) => '${e.key}: ${_yamlScalar(e.value)}')
        .join('\n');
    final extraBlock = extraLines.isEmpty ? '' : '$extraLines\n';
    return '---\n'
        'title: ${_yamlScalar(title)}\n'
        'tags: [$tagList]\n'
        'updated: ${updated.toUtc().toIso8601String()}\n'
        'favorite: $favorite\n'
        '$extraBlock'
        '---\n'
        '$body';
  }

  NoteDocument copyWith({
    String? title,
    String? body,
    DateTime? updated,
    List<String>? tags,
    bool? favorite,
    Map<String, dynamic>? extra,
  }) {
    return NoteDocument(
      title: title ?? this.title,
      body: body ?? this.body,
      updated: updated ?? this.updated,
      tags: tags ?? this.tags,
      favorite: favorite ?? this.favorite,
      extra: extra ?? this.extra,
    );
  }

  static DateTime _parseTime(Object? value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    final parsed = DateTime.tryParse('$value');
    return parsed?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static String _firstHeading(String raw) {
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.startsWith('# ')) return t.substring(2).trim();
      if (t.isNotEmpty) return t.length > 40 ? t.substring(0, 40) : t;
    }
    return '';
  }

  static dynamic _unwrapYaml(dynamic value) {
    if (value is YamlMap) {
      return {for (final e in value.entries) '${e.key}': _unwrapYaml(e.value)};
    }
    if (value is YamlList) {
      return value.map(_unwrapYaml).toList();
    }
    return value;
  }

  static String _yamlScalar(Object? value) {
    if (value is bool || value is num) return '$value';
    final s = '$value';
    if (s.isEmpty) return '""';
    if (RegExp(r'[:#\[\]\{\},\n]').hasMatch(s) || s.contains('"')) {
      return '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
    }
    return s;
  }
}

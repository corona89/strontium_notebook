import 'package:flutter_test/flutter_test.dart';
import 'package:strontium_notebook/models/note_document.dart';

void main() {
  test('프론트매터 왕복', () {
    final original = NoteDocument(
      title: '회의: 다음 주',
      body: '# 안녕\n\n본문입니다.\n',
      updated: DateTime.utc(2026, 8, 30, 3, 18),
      tags: const ['일', '계획'],
      favorite: true,
    );
    final parsed = NoteDocument.parse(original.encode());
    expect(parsed.title, original.title);
    expect(parsed.body, original.body);
    expect(parsed.tags, original.tags);
    expect(parsed.favorite, isTrue);
    expect(parsed.updated.toUtc(), original.updated);
  });

  test('프론트매터 없는 마크다운', () {
    final parsed = NoteDocument.parse('# 제목\n\n내용');
    expect(parsed.title, '제목');
    expect(parsed.body, contains('내용'));
  });

  test('깨진 YAML은 본문으로 보존', () {
    const raw = '---\ntitle: [깨짐\n---\n남겨야 함';
    final parsed = NoteDocument.parse(raw);
    expect(parsed.body, contains('남겨야 함'));
  });
}

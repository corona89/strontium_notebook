import 'package:flutter_test/flutter_test.dart';
import 'package:strontium_notebook/models/ids.dart';
import 'package:strontium_notebook/models/note.dart';
import 'package:strontium_notebook/models/notebook.dart';
import 'package:strontium_notebook/services/note_search.dart';

Note _note({
  required String id,
  required String notebookId,
  required String title,
  String body = '',
  List<String> tags = const [],
  bool favorite = false,
  bool trashed = false,
}) {
  return Note(
    id: id,
    notebookId: notebookId,
    title: title,
    body: body,
    updated: DateTime.utc(2026, 1, 1),
    fileName: '$id.md',
    tags: tags,
    favorite: favorite,
    trashed: trashed,
  );
}

void main() {
  const search = NoteSearch();
  const parent = Notebook(id: 'p', name: '부모');
  const child = Notebook(id: 'c', name: '자식', parentId: 'p');

  final notes = [
    _note(id: '1', notebookId: 'p', title: '알파', body: '본문 하나'),
    _note(id: '2', notebookId: 'c', title: '베타', body: '검색어 포함'),
    _note(
      id: '3',
      notebookId: SpecialIds.inbox,
      title: '즐겨찾기',
      favorite: true,
      tags: const ['중요'],
    ),
    _note(id: '4', notebookId: 'p', title: '휴지', trashed: true),
  ];

  test('노트북과 하위 노트북 노트를 함께 본다', () {
    final found = search.filter(
      notes: notes,
      notebooks: const [parent, child],
      query: const NoteQuery(notebookId: 'p'),
    );
    expect(found.map((e) => e.id), containsAll(['1', '2']));
    expect(found.map((e) => e.id), isNot(contains('4')));
  });

  test('제목·본문 검색', () {
    final found = search.filter(
      notes: notes,
      notebooks: const [parent, child],
      query: const NoteQuery(notebookId: SpecialIds.all, search: '검색어'),
    );
    expect(found.single.id, '2');
  });

  test('즐겨찾기와 태그', () {
    final fav = search.filter(
      notes: notes,
      notebooks: const [parent, child],
      query: const NoteQuery(notebookId: SpecialIds.favorites),
    );
    expect(fav.single.id, '3');
    final tagged = search.filter(
      notes: notes,
      notebooks: const [parent, child],
      query: NoteQuery(notebookId: SpecialIds.tagId('중요')),
    );
    expect(tagged.single.id, '3');
  });

  test('파일 이름 살균', () {
    expect(sanitizeFileName(r'a/b:c', 'abcdefghijk'), 'a_b_c-abcdefgh.md');
  });
}

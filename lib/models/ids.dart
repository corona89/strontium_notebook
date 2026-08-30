/// 가상 노트북(Drive 폴더가 아닌 필터)과 루트 받은 노트 id.
class SpecialIds {
  SpecialIds._();

  static const all = '__all__';
  static const inbox = '__inbox__';
  static const favorites = '__favorites__';
  static const trash = '__trash__';
  static const tagPrefix = 'tag:';

  static bool isVirtual(String id) =>
      id == all ||
      id == inbox ||
      id == favorites ||
      id == trash ||
      id.startsWith(tagPrefix);

  static String tagId(String tag) => '$tagPrefix$tag';

  static String? tagName(String id) =>
      id.startsWith(tagPrefix) ? id.substring(tagPrefix.length) : null;
}

class DriveConstants {
  DriveConstants._();

  static const folderName = 'strontium_notebook';
  static const knownFolderId = '1O26lVqSkJdIDXBQgPg3tR4m23aeahdY3';
  static const trashFolderName = '_trash';
  static const driveScope = 'https://www.googleapis.com/auth/drive';
  static const folderMime = 'application/vnd.google-apps.folder';
  static const markdownMime = 'text/markdown';
}

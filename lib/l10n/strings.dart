/// 앱 전역 한국어 문자열. 별도 회원가입 없이 Drive 연동만 사용한다.
class S {
  S._();

  static const appTitle = 'strontium_notebook';
  static const appNameKo = '스트론튬 노트북';
  static const tagline = '노트는 내 기기에 두고, Google Drive의 strontium_notebook 폴더와 동기화합니다.';

  static const connectDrive = 'Google Drive 연결';
  static const continueOffline = '오프라인으로 시작';
  static const connecting = '연결하는 중…';
  static const signOut = '연결 해제';
  static const signedInAs = '연결됨';
  static const notSignedIn = 'Drive에 연결되지 않음';
  static const oauthMissing =
      'google_oauth.json이 없습니다. README의 Google Cloud OAuth 안내를 따라 데스크톱 클라이언트 ID/시크릿을 설정하세요.';

  /// 저장소에 올린 APK를 서명한 키스토어의 SHA-1. 사용자 PC의 debug.keystore가 아니다.
  static const apkSigningSha1 =
      'D0:C7:38:F8:F3:E2:CC:37:D7:20:0A:62:42:7D:23:C9:2D:02:16:25';

  static const signInDeveloperError =
      'Google 로그인이 거부되었습니다 (DEVELOPER_ERROR, 코드 10).\n'
      'Cloud Console에서 Android OAuth 클라이언트를 만들고 '
      '패키지 이름 `com.strontium.strontium_notebook`과 '
      '이 APK를 서명한 SHA-1을 등록하세요:\n'
      '$apkSigningSha1\n'
      'PC에서 `keytool`로 찍은 로컬 debug.keystore 지문은 쓰지 마세요. '
      '저장소의 apk/strontium-notebook.apk 와 서명이 다릅니다.';

  static const allNotes = '모든 노트';
  static const inbox = '받은 노트';
  static const favorites = '즐겨찾기';
  static const tags = '태그';
  static const trash = '휴지통';
  static const notebooks = '노트북';
  static const newNotebook = '새 노트북';
  static const renameNotebook = '노트북 이름 변경';
  static const deleteNotebook = '노트북 삭제';
  static const newNote = '새 노트';
  static const renameNote = '노트 이름 변경';
  static const deleteNote = '노트를 휴지통으로';
  static const restoreNote = '복원';
  static const deleteForever = '영구 삭제';
  static const moveNote = '노트북으로 이동';
  static const emptyNotebooks = '노트북이 없습니다. + 로 만들어 보세요.';
  static const emptyNotes = '노트가 없습니다.';
  static const emptySearch = '검색 결과가 없습니다.';
  static const emptyTrash = '휴지통이 비어 있습니다.';
  static const emptyEditor = '왼쪽에서 노트를 고르거나 새 노트를 만드세요.';
  static const searchHint = '제목·본문 검색';
  static const titleHint = '제목';
  static const bodyHint = '마크다운으로 작성하세요.';
  static const tagsHint = '태그 (쉼표로 구분)';
  static const nameHint = '이름';
  static const save = '저장';
  static const saved = '저장됨';
  static const cancel = '취소';
  static const ok = '확인';
  static const edit = '편집';
  static const preview = '미리보기';
  static const split = '분할';
  static const sync = '동기화';
  static const syncing = '동기화 중…';
  static const synced = '동기화 완료';
  static const offline = '오프라인 — 로컬 캐시 사용';
  static const favorite = '즐겨찾기';
  static const unfavorite = '즐겨찾기 해제';
  static const confirmDeleteNotebook =
      '이 노트북과 안의 노트를 휴지통으로 보낼까요? Drive에서도 휴지통으로 이동합니다.';
  static const confirmDeleteNote = '이 노트를 휴지통으로 보낼까요?';
  static const confirmDeleteForever = '영구 삭제하면 되돌릴 수 없습니다. 계속할까요?';
  static const conflictCopy = '충돌 사본';
  static const untitled = '제목 없음';
  static const parentNotebook = '상위 노트북';
  static const noneParent = '(최상위)';
  static const lastWriteWins = '충돌 시 최신 updated 시각이 이깁니다. 진 쪽은 충돌 사본으로 남깁니다.';
  static const scopeNote =
      '기존 Drive 폴더를 쓰려면 drive 범위가 필요합니다. drive.file만으로는 앱이 만들지 않은 폴더가 보이지 않습니다.';
}

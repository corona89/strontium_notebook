# strontium_notebook

**스트론튬 노트북** — PC(Linux·Windows)와 Android에서 쓰는 UpNote 스타일 노트 앱입니다.  
앱 자체 회원가입/로그인은 없습니다. 유일한 인증은 **Google Drive용 Google 로그인**입니다.

노트는 기기의 로컬 캐시에 두고, 로그인되어 있고 온라인이면 Google Drive 폴더 `strontium_notebook`과 동기화합니다.

## Drive 폴더

| 항목 | 값 |
| --- | --- |
| 폴더 이름 | `strontium_notebook` |
| 기존 폴더 id | `1O26lVqSkJdIDXBQgPg3tR4m23aeahdY3` |
| URL | https://drive.google.com/drive/folders/1O26lVqSkJdIDXBQgPg3tR4m23aeahdY3 |

앱은 다음 순서로 루트 폴더를 찾습니다.

1. 저장된 id, 없으면 위 알려진 id로 `files.get`
2. 실패하면 이름 `strontium_notebook` 인 폴더를 Drive에서 검색
3. 둘 다 없으면 같은 이름으로 폴더를 새로 만듦

매핑:

- Drive **폴더** → 노트북 (중첩 폴더 = 중첩 노트북)
- Drive **`.md` 파일** → 노트
- `_trash` 이름 폴더는 무시하고, 삭제는 Drive **휴지통**(`trashed`)을 사용합니다. 앱의 휴지통 보기에서 복원·영구 삭제할 수 있습니다.

### OAuth 범위

기본값은 **`https://www.googleapis.com/auth/drive`** 입니다.

`drive.file`만 쓰면 이 앱이 **만들지 않은** 기존 폴더(`1O26lVqSkJdIDXBQgPg3tR4m23aeahdY3`)가 보이지 않습니다.  
이미 Drive 웹에서 만들어 둔 폴더를 쓰려면 `drive` 범위가 필요합니다. `drive.metadata` + `drive.file` 조합으로는 다른 앱/웹이 만든 파일을 수정할 수 없습니다.

## 노트 파일 형식

```markdown
---
title: 제목
tags: [태그1, 태그2]
updated: 2026-08-30T03:18:00.000Z
favorite: false
---

마크다운 본문
```

동기화는 frontmatter의 `updated`를 기준으로 **마지막 쓰기가 이깁니다**.  
진 쪽 내용은 같은 노트북에 `(충돌 사본)` 노트로 남겨 데이터가 조용히 사라지지 않게 합니다.

오프라인에서는 로컬 캐시(`index.json`)만 사용하고, 다시 연결되면 밀어 올립니다.

## 준비

- Flutter 3.24+ (개발 시 3.44.9 / Dart 3.12 확인)
- Android: JDK 17+, Android SDK, minSdk **26**
- Linux 데스크톱: `clang`, `g++`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `libstdc++-14-dev`
- Windows 데스크톱: Visual Studio (Desktop development with C++)

```bash
flutter pub get
```

## Google Cloud OAuth

1. [Google Cloud Console](https://console.cloud.google.com/)에서 프로젝트를 만들고 **Google Drive API**를 사용 설정합니다.
2. OAuth 동의 화면을 구성합니다. 테스트 사용자로 Drive 폴더 소유 계정(예: `cpar2002@gmail.com`)을 넣습니다.
3. 사용자 인증 정보 → OAuth 클라이언트 ID:
   - **Android**: 패키지 `com.strontium.strontium_notebook`. 디버그/릴리스 키스토어 SHA-1을 등록합니다.
     ```bash
     keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore
     ```
   - **데스크톱**: 애플리케이션 유형 “데스크톱”. 클라이언트 ID와 시크릿을 받습니다. 루프백(`http://127.0.0.1`) 리다이렉트는 데스크톱 클라이언트에서 허용됩니다.
   - (권장) **웹** 클라이언트: Android `google_sign_in`의 `serverClientId`로 씁니다.
4. 예시를 복사한 뒤 **실제 값을 넣습니다. 이 파일은 git에 올리지 마세요.**

```bash
cp google_oauth.json.example google_oauth.json
```

앱이 파일을 찾는 위치:

- 프로젝트 루트 `google_oauth.json` (`flutter run` 개발용)
- 환경 변수 `GOOGLE_OAUTH_JSON` (파일 경로)
- `~/.config/strontium_notebook/google_oauth.json`
- 실행 파일과 같은 폴더
- 앱 지원 디렉터리
- 컴파일 타임 `--dart-define=DESKTOP_CLIENT_ID=...` 등

`google_oauth.json` / `android/app/google-services.json` / 키스토어는 `.gitignore`에 있습니다.

첫 실행 화면에는 **Google Drive 연결** 버튼만 있습니다. 이메일/비밀번호 폼은 없습니다.  
데스크톱은 브라우저로 Google 동의 화면을 엽니다. Android는 계정 선택 UI를 씁니다.

OAuth 설정 전에는 **오프라인으로 시작**으로 로컬 노트만 사용할 수 있습니다.

## 실행

### Linux

```bash
flutter run -d linux
```

릴리스 바이너리:

```bash
flutter build linux --release
# build/linux/x64/release/bundle/strontium_notebook
```

### Windows

```bash
flutter run -d windows
flutter build windows --release
```

### Android

```bash
flutter run -d <device>
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

이 저장소의 CI는 Linux 데스크톱 빌드를 돌립니다. APK는 로컬에 Android SDK가 있을 때 위 명령으로 만듭니다.

## 기능 (MVP)

- 데스크톱 3단 / 좁은 화면 적응 레이아웃: 노트북 | 노트 목록 | 편집기
- 노트북 생성·이름 변경·삭제, Drive 하위 폴더로 중첩
- 노트 생성·편집·이름 변경·삭제·노트북 이동
- 마크다운 편집 + 미리보기(분할 보기)
- 제목/본문/태그 검색, 태그, 즐겨찾기
- 빠른 새 노트, 휴지통
- 로컬 캐시 + Drive 동기화
- 데스크톱 단축키: `Ctrl+N` 새 노트, `Ctrl+F` 검색, `Ctrl+S` 저장 (macOS는 `⌘`)

## 개발

```bash
flutter analyze
flutter test
```

분석 경고가 남아 있으면 이 README나 PR에 이유를 적습니다. 오류는 수정합니다.

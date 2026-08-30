import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strontium_notebook/app.dart';
import 'package:strontium_notebook/l10n/strings.dart';
import 'package:strontium_notebook/models/note.dart';
import 'package:strontium_notebook/models/oauth_config.dart';
import 'package:strontium_notebook/screens/connect_screen.dart';
import 'package:strontium_notebook/services/auth_service.dart';
import 'package:strontium_notebook/services/local_cache.dart';
import 'package:strontium_notebook/state/app_controller.dart';

AppController _controller({
  AppPhase phase = AppPhase.connect,
  List<Note> notes = const [],
}) {
  SharedPreferences.setMockInitialValues({});
  final dir = Directory.systemTemp.createTempSync('snb-');
  return AppController(
    cache: LocalCache(dir),
    auth: AuthService(config: const OauthConfig()),
    oauth: const OauthConfig(),
    snapshot: CacheSnapshot(
      rootFolderId: 'root',
      notebooks: [],
      notes: notes,
    ),
  )..phase = phase;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('ko');
  });

  testWidgets('첫 화면은 Google Drive 연결만 보여 준다', (tester) async {
    await tester.pumpWidget(NotebookApp(controller: _controller()));
    expect(find.text(S.connectDrive), findsOneWidget);
    expect(find.text(S.continueOffline), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('비밀번호'), findsNothing);
  });

  testWidgets('오프라인 시작 후 세 영역 골격이 뜬다', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(NotebookApp(controller: controller));
    await tester.tap(find.text(S.continueOffline));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectScreen), findsNothing);
    expect(find.text(S.allNotes), findsWidgets);
    expect(find.text(S.emptyEditor), findsOneWidget);
    expect(find.text(S.searchHint), findsOneWidget);
  });
}

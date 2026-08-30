import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/strings.dart';
import 'screens/connect_screen.dart';
import 'screens/home_screen.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';

class NotebookApp extends StatelessWidget {
  const NotebookApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppController>.value(
      value: controller,
      child: MaterialApp(
        title: S.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final phase = context.watch<AppController>().phase;
    switch (phase) {
      case AppPhase.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AppPhase.connect:
        return const ConnectScreen();
      case AppPhase.ready:
        return const HomeScreen();
    }
  }
}

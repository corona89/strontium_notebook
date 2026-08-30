import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_controller.dart';
import '../widgets/editor_pane.dart';
import '../widgets/note_list_pane.dart';
import '../widgets/notebook_pane.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchFocus = FocusNode();
  final _editorKey = GlobalKey<EditorPaneState>();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _newNote() async {
    await context.read<AppController>().createNote();
  }

  Future<void> _save() => _editorKey.currentState?.save() ?? Future<void>.value();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _newNote,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _newNote,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1100) {
              return _desktop(app);
            }
            if (constraints.maxWidth >= 720) {
              return _tablet(app);
            }
            return _phone(app);
          },
        ),
      ),
    );
  }

  Widget _statusBar(AppController app) {
    final text = app.error ?? app.status;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Material(
      color: app.error != null
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _desktop(AppController app) {
    return Scaffold(
      body: Column(
        children: [
          _statusBar(app),
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 260, child: NotebookPane()),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 320,
                  child: NoteListPane(searchFocus: _searchFocus),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: EditorPane(key: _editorKey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tablet(AppController app) {
    return Scaffold(
      drawer: const Drawer(child: NotebookPane()),
      appBar: AppBar(
        title: const Text(S.appTitle),
        actions: [
          IconButton(
            tooltip: S.sync,
            onPressed: app.syncing ? null : app.syncNow,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(
        children: [
          _statusBar(app),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 300,
                  child: NoteListPane(searchFocus: _searchFocus),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: EditorPane(key: _editorKey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _phone(AppController app) {
    final editing = app.selectedNote != null;
    return Scaffold(
      drawer: const Drawer(child: NotebookPane()),
      appBar: AppBar(
        title: Text(editing ? (app.selectedNote?.title ?? S.appTitle) : S.appTitle),
        leading: editing
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => app.selectNote(null),
              )
            : null,
        actions: [
          IconButton(
            tooltip: S.sync,
            onPressed: app.syncing ? null : app.syncNow,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: editing
          ? null
          : FloatingActionButton(
              tooltip: S.newNote,
              onPressed: _newNote,
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          _statusBar(app),
          Expanded(
            child: editing
                ? EditorPane(key: _editorKey)
                : NoteListPane(
                    searchFocus: _searchFocus,
                    onOpenNote: (note) => app.selectNote(note.id),
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/ids.dart';
import '../models/notebook.dart';
import '../state/app_controller.dart';
import 'dialogs.dart';

class NotebookPane extends StatelessWidget {
  const NotebookPane({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLow,
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(
              S.appNameKo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              app.signedIn
                  ? '${S.signedInAs} ${app.accountEmail ?? ''}'
                  : S.notSignedIn,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: S.sync,
              onPressed: app.syncing ? null : app.syncNow,
              icon: app.syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _item(
                  context,
                  app,
                  id: SpecialIds.all,
                  icon: Icons.notes,
                  label: S.allNotes,
                ),
                _item(
                  context,
                  app,
                  id: SpecialIds.inbox,
                  icon: Icons.inbox_outlined,
                  label: S.inbox,
                ),
                _item(
                  context,
                  app,
                  id: SpecialIds.favorites,
                  icon: Icons.star_outline,
                  label: S.favorites,
                ),
                _item(
                  context,
                  app,
                  id: SpecialIds.trash,
                  icon: Icons.delete_outline,
                  label: S.trash,
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          S.notebooks,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: S.newNotebook,
                        onPressed: () => _createNotebook(context, app),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                if (app.notebooks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(S.emptyNotebooks),
                  )
                else
                  ..._tree(context, app, app.notebooks, null, 0),
                if (app.tags.isNotEmpty) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      S.tags,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  for (final tag in app.tags.toList()..sort())
                    _item(
                      context,
                      app,
                      id: SpecialIds.tagId(tag),
                      icon: Icons.sell_outlined,
                      label: tag,
                    ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          if (app.signedIn)
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout),
              title: const Text(S.signOut),
              onTap: app.disconnect,
            )
          else
            ListTile(
              dense: true,
              leading: const Icon(Icons.cloud_outlined),
              title: const Text(S.connectDrive),
              onTap: app.connectDrive,
            ),
        ],
      ),
    );
  }

  List<Widget> _tree(
    BuildContext context,
    AppController app,
    List<Notebook> all,
    String? parent,
    int depth,
  ) {
    final children = all.where((n) => n.parentId == parent).toList();
    final widgets = <Widget>[];
    for (final nb in children) {
      widgets.add(
        _item(
          context,
          app,
          id: nb.id,
          icon: Icons.folder_outlined,
          label: nb.name,
          indent: depth,
          notebook: nb,
        ),
      );
      widgets.addAll(_tree(context, app, all, nb.id, depth + 1));
    }
    return widgets;
  }

  Widget _item(
    BuildContext context,
    AppController app, {
    required String id,
    required IconData icon,
    required String label,
    int indent = 0,
    Notebook? notebook,
  }) {
    final selected = app.selectedNotebookId == id;
    return ListTile(
      selected: selected,
      dense: true,
      contentPadding: EdgeInsets.only(left: 16.0 + indent * 16, right: 8),
      leading: Icon(icon, size: 20),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
      onTap: () => app.selectNotebook(id),
      trailing: notebook == null
          ? null
          : PopupMenuButton<String>(
              onSelected: (value) => _onNotebookMenu(context, app, notebook, value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text(S.renameNotebook)),
                PopupMenuItem(value: 'delete', child: Text(S.deleteNotebook)),
              ],
            ),
    );
  }

  Future<void> _createNotebook(BuildContext context, AppController app) async {
    final created = await promptNotebook(
      context,
      notebooks: app.notebooks,
      parentId: SpecialIds.isVirtual(app.selectedNotebookId)
          ? null
          : app.selectedNotebookId,
    );
    if (created == null || created.name.trim().isEmpty) return;
    await app.createNotebook(name: created.name, parentId: created.parentId);
  }

  Future<void> _onNotebookMenu(
    BuildContext context,
    AppController app,
    Notebook notebook,
    String value,
  ) async {
    if (value == 'rename') {
      final name = await promptText(
        context,
        title: S.renameNotebook,
        initial: notebook.name,
      );
      if (name != null && name.trim().isNotEmpty) {
        await app.renameNotebook(notebook.id, name);
      }
    } else if (value == 'delete') {
      final ok = await confirm(
        context,
        title: S.deleteNotebook,
        message: S.confirmDeleteNotebook,
      );
      if (ok) await app.deleteNotebook(notebook.id);
    }
  }
}

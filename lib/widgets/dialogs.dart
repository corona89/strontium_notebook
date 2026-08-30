import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/ids.dart';
import '../models/notebook.dart';

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? initial,
  String hint = S.nameHint,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text(S.ok),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(S.ok),
          ),
        ],
      );
    },
  );
  return ok == true;
}

Future<String?> pickNotebook(
  BuildContext context, {
  required List<Notebook> notebooks,
  String? current,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: const Text(S.moveNote),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, SpecialIds.inbox),
            child: const Text(S.inbox),
          ),
          for (final nb in notebooks)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, nb.id),
              child: Text(
                nb.id == current ? '${nb.name} ✓' : nb.name,
              ),
            ),
        ],
      );
    },
  );
}

Future<({String name, String? parentId})?> promptNotebook(
  BuildContext context, {
  required List<Notebook> notebooks,
  String? initialName,
  String? parentId,
}) async {
  final controller = TextEditingController(text: initialName ?? '');
  String? selectedParent = parentId;
  final result = await showDialog<({String name, String? parentId})>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(S.newNotebook),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: S.nameHint),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  // ignore: deprecated_member_use
                  value: selectedParent,
                  decoration: const InputDecoration(labelText: S.parentNotebook),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(S.noneParent),
                    ),
                    for (final nb in notebooks)
                      DropdownMenuItem<String?>(
                        value: nb.id,
                        child: Text(nb.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => selectedParent = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(S.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  (name: controller.text, parentId: selectedParent),
                ),
                child: const Text(S.ok),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  return result;
}

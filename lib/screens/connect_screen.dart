import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_controller.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded, size: 72, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  S.appTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  S.appNameKo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  S.tagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  S.scopeNote,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: app.syncing || app.status == S.connecting
                      ? null
                      : app.connectDrive,
                  icon: const Icon(Icons.cloud_outlined),
                  label: Text(
                    app.status == S.connecting ? S.connecting : S.connectDrive,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: app.startOffline,
                  child: const Text(S.continueOffline),
                ),
                if (app.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    app.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

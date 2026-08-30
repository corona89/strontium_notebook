import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/oauth_config.dart';

class OauthConfigStore {
  const OauthConfigStore();

  Future<OauthConfig> load({Directory? extraDir}) async {
    var config = OauthConfig.fromDefines();
    final candidates = <File>[];
    if (extraDir != null) {
      candidates.add(File(p.join(extraDir.path, 'google_oauth.json')));
    }
    candidates.add(File(p.join(Directory.current.path, 'google_oauth.json')));
    final exe = Platform.resolvedExecutable;
    candidates.add(File(p.join(p.dirname(exe), 'google_oauth.json')));
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (home.isNotEmpty) {
      candidates.add(
        File(p.join(home, '.config', 'strontium_notebook', 'google_oauth.json')),
      );
    }
    final envPath = Platform.environment['GOOGLE_OAUTH_JSON'];
    if (envPath != null && envPath.isNotEmpty) {
      candidates.insert(0, File(envPath));
    }

    for (final file in candidates) {
      if (!await file.exists()) continue;
      try {
        final json = jsonDecode(await file.readAsString());
        if (json is Map<String, dynamic>) {
          config = config.merge(OauthConfig.fromJson(json));
          break;
        }
        if (json is Map) {
          config = config.merge(
            OauthConfig.fromJson(json.cast<String, dynamic>()),
          );
          break;
        }
      } catch (_) {
        // 다음 후보를 계속 본다.
      }
    }
    return config;
  }
}

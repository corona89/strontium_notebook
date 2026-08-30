class OauthConfig {
  const OauthConfig({
    this.androidClientId,
    this.desktopClientId,
    this.desktopClientSecret,
    this.serverClientId,
  });

  final String? androidClientId;
  final String? desktopClientId;
  final String? desktopClientSecret;
  final String? serverClientId;

  bool get hasDesktop =>
      (desktopClientId != null && desktopClientId!.isNotEmpty) &&
      (desktopClientSecret != null && desktopClientSecret!.isNotEmpty);

  bool get hasAndroid =>
      (androidClientId != null && androidClientId!.isNotEmpty) ||
      (serverClientId != null && serverClientId!.isNotEmpty);

  factory OauthConfig.fromJson(Map<String, dynamic> json) {
    return OauthConfig(
      androidClientId: json['androidClientId'] as String?,
      desktopClientId: json['desktopClientId'] as String?,
      desktopClientSecret: json['desktopClientSecret'] as String?,
      serverClientId: json['serverClientId'] as String?,
    );
  }

  factory OauthConfig.fromDefines() {
    const android = String.fromEnvironment('ANDROID_CLIENT_ID');
    const desktopId = String.fromEnvironment('DESKTOP_CLIENT_ID');
    const desktopSecret = String.fromEnvironment('DESKTOP_CLIENT_SECRET');
    const server = String.fromEnvironment('SERVER_CLIENT_ID');
    return OauthConfig(
      androidClientId: android.isEmpty ? null : android,
      desktopClientId: desktopId.isEmpty ? null : desktopId,
      desktopClientSecret: desktopSecret.isEmpty ? null : desktopSecret,
      serverClientId: server.isEmpty ? null : server,
    );
  }

  OauthConfig merge(OauthConfig other) {
    return OauthConfig(
      androidClientId: _pick(other.androidClientId, androidClientId),
      desktopClientId: _pick(other.desktopClientId, desktopClientId),
      desktopClientSecret: _pick(other.desktopClientSecret, desktopClientSecret),
      serverClientId: _pick(other.serverClientId, serverClientId),
    );
  }

  static String? _pick(String? preferred, String? fallback) {
    if (preferred != null && preferred.isNotEmpty) return preferred;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }
}

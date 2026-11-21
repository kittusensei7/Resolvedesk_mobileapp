import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages application environment settings, compile-time flags, and API base URLs.
/// Follows Clean Architecture by isolating environment concerns from network clients.
class EnvironmentConfig {
  EnvironmentConfig._();

  static const String productionBaseUrl = 'https://paradesk.cloud/api';
  static const String defaultDevBaseUrl = 'http://127.0.0.1:4000/api';

  static const String _urlStorageKey = 'resolvedesk_api_url';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Optional compile-time flag via `--dart-define=API_BASE_URL=...`
  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Optional compile-time flag via `--dart-define=ENV=...`
  static const String _configuredEnv = String.fromEnvironment('ENV', defaultValue: '');

  /// Returns true if running in production mode or built as a release binary.
  static bool get isProduction =>
      kReleaseMode || _configuredEnv == 'production' || _configuredBaseUrl.contains('paradesk.cloud');

  /// Returns true if running in debug development mode.
  static bool get isDevelopment => !isProduction;

  /// Resolves the effective API base URL cleanly:
  ///
  /// 1. In **Release Mode** (`flutter build apk`):
  ///    Always returns [productionBaseUrl].
  ///
  /// 2. In **Explicit Production Profile** (`ResolveDesk Mobile (Live Production)`):
  ///    Always returns [productionBaseUrl] directly, ignoring old local storage.
  ///
  /// 3. In **Debug Mode** (`flutter run`):
  ///    Checks if developer switched URL via dialog; otherwise defaults to [defaultDevBaseUrl].
  static Future<String> getBaseUrl() async {
    // 1. Release APK is always hard-locked to production
    if (kReleaseMode) {
      return productionBaseUrl;
    }

    // 2. Explicit compile-time production run
    if (_configuredBaseUrl.isNotEmpty && _configuredBaseUrl.contains('paradesk.cloud')) {
      return normalizeUrl(productionBaseUrl);
    }

    // 3. Explicit compile-time dev run
    if (_configuredBaseUrl.isNotEmpty) {
      return normalizeUrl(_configuredBaseUrl);
    }

    // 4. Standard simple `flutter run` (Debug): check switcher or default to local dev
    final storedUrl = await _storage.read(key: _urlStorageKey);
    if (storedUrl != null && storedUrl.trim().isNotEmpty) {
      if (storedUrl.contains('200.141.13.247') || storedUrl.contains('193.203.160.66')) {
        await setBaseUrl(defaultDevBaseUrl);
        return normalizeUrl(defaultDevBaseUrl);
      }
      return normalizeUrl(storedUrl.trim());
    }

    return defaultDevBaseUrl;
  }

  /// Saves a custom base URL for local testing (available only during development).
  static Future<void> setBaseUrl(String url) async {
    if (kReleaseMode) {
      debugPrint('EnvironmentConfig: Overriding base URL is blocked in release mode.');
      return;
    }
    await _storage.write(key: _urlStorageKey, value: normalizeUrl(url));
  }

  /// Ensures URL does not have a trailing slash for consistency.
  static String normalizeUrl(String url) {
    final trimmed = url.trim();
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }
}

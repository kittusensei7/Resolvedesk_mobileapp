import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'environment_config.dart';
import '../pages/login_page.dart';
import '../services/notification_service.dart';
import '../services/permission_access.dart';

/// Centralized API Client and Session Manager.
/// Configures Dio instances, authentication headers, and automatic token expiry handling.
class ApiConfig {
  ApiConfig._();

  static const String defaultBaseUrl = EnvironmentConfig.productionBaseUrl;
  static const String usbBaseUrl = EnvironmentConfig.defaultDevBaseUrl;

  static const String _tokenKey = 'resolvedesk_token';
  static const String _userKey = 'resolvedesk_user_json';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static bool _isHandlingExpiry = false;

  /// Optional hook for mocking [HttpClientAdapter] in unit and widget tests.
  @visibleForTesting
  static HttpClientAdapter Function()? adapterFactory;

  /// Optional hook triggered when permission is denied (HTTP 403).
  @visibleForTesting
  static void Function()? onPermissionDenied;

  /// Optional hook triggered when session state changes.
  @visibleForTesting
  static void Function()? onSessionChanged;

  /// Resolves the current base URL from [EnvironmentConfig].
  static Future<String> getBaseUrl() => EnvironmentConfig.getBaseUrl();

  /// Updates the base URL in development mode.
  static Future<void> setBaseUrl(String url) => EnvironmentConfig.setBaseUrl(url);

  /// Retrieves the saved authentication JWT token.
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Saves the authentication JWT token.
  static Future<void> setToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    onSessionChanged?.call();
  }

  /// Saves user metadata JSON.
  static Future<void> setUser(Map<String, dynamic> user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user));
  }

  /// Retrieves user metadata JSON.
  static Future<Map<String, dynamic>?> getUser() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null && userJson.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(userJson) as Map);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Clears stored user credentials upon logout or session expiry.
  static Future<void> clearToken() async {
    PermissionAccess.clearCache();
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    onSessionChanged?.call();
  }

  /// Checks if a JWT token has expired by inspecting its `exp` claim.
  static bool isTokenExpired(String? token) {
    if (token == null || token.trim().isEmpty) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final normalized = base64Url.normalize(parts[1]);
      final payloadStr = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadStr);
      if (payload is! Map<String, dynamic> || !payload.containsKey('exp')) {
        return false;
      }

      final exp = payload['exp'];
      final expSeconds = exp is int ? exp : int.tryParse(exp.toString());
      if (expSeconds == null) return false;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000, isUtc: true);
      // Allow 10 seconds margin for clock skew
      return DateTime.now().toUtc().isAfter(expiryDate.subtract(const Duration(seconds: 10)));
    } catch (e) {
      debugPrint('Token expiry parsing error: $e');
      return true;
    }
  }

  /// Centralized session expiration handler with single-flight debounce.
  static Future<void> handleSessionExpired() async {
    if (_isHandlingExpiry) return;
    _isHandlingExpiry = true;

    try {
      debugPrint('⚠️ [Session Expired] Clearing token and redirecting to LoginPage.');
      await clearToken();

      final nav = NotificationService.navigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );

        final context = NotificationService.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.lock_clock_outlined, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Session expired. Please sign in again.',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xffdc2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error redirecting to login on session expiry: $e');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _isHandlingExpiry = false;
      });
    }
  }

  static Dio? _singletonDio;
  static String? _cachedBaseUrl;

  /// Resets the persistent Dio client. Hook for tests.
  @visibleForTesting
  static void resetDioClient() {
    _singletonDio?.close(force: true);
    _singletonDio = null;
    _cachedBaseUrl = null;
  }

  /// Builds or returns a persistent, pooled [Dio] HTTP client with Keep-Alive connection reuse.
  /// Reuses existing TCP sockets and TLS sessions, cutting 300-600ms latency on every request.
  static Future<Dio> getDio() async {
    var baseUrl = await getBaseUrl();
    if (!baseUrl.endsWith('/')) {
      baseUrl = '$baseUrl/';
    }

    if (_singletonDio != null) {
      if (_cachedBaseUrl != baseUrl) {
        _singletonDio!.options.baseUrl = baseUrl;
        _cachedBaseUrl = baseUrl;
      }
      return _singletonDio!;
    }

    _cachedBaseUrl = baseUrl;
    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 35),
      receiveTimeout: const Duration(seconds: 35),
      sendTimeout: const Duration(seconds: 35),
      headers: const {
        'Content-Type': 'application/json',
      },
    );

    final dio = Dio(options);
    if (adapterFactory != null) {
      dio.httpClientAdapter = adapterFactory!();
    }

    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (RequestOptions requestOptions, RequestInterceptorHandler handler) async {
          final token = await getToken();
          final user = await getUser();
          final originalRole = user?['originalRole'] ?? user?['role'];
          final activeRole = ['dual', 'technician_sales'].contains(originalRole)
              ? 'technician'
              : user?['role'];

          if (token != null && token.isNotEmpty) {
            requestOptions.headers['Authorization'] = 'Bearer $token';
          }
          if (activeRole != null) {
            requestOptions.headers['x-active-role'] = activeRole;
          }
          return handler.next(requestOptions);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode == 403) {
            onPermissionDenied?.call();
          }
          if (error.response?.statusCode == 401) {
            onSessionChanged?.call();
            final path = error.requestOptions.path;
            final isAuthLogin = path.contains('auth/login') || path.contains('auth/signin') || path.endsWith('login');
            if (!isAuthLogin) {
              handleSessionExpired();
            }
          }
          return handler.next(error);
        },
      ),
    );

    _singletonDio = dio;
    return dio;
  }
}

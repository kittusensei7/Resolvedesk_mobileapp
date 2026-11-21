import 'package:dio/dio.dart';
import '../config/api_config.dart';

class PermissionAccess {
  const PermissionAccess(this.privileges, {this.isSuperadmin = false, this.revision = ''});
  const PermissionAccess.empty() : this(const {});
  final Map<String, dynamic> privileges;
  final bool isSuperadmin;
  final String revision;

  static PermissionAccess? _cached;

  /// Returns cached permissions instantly (0ms) if already loaded;
  /// otherwise fetches from the server and caches the result.
  /// Pass [forceRefresh: true] to bypass cache (e.g. on Pull-to-Refresh).
  static Future<PermissionAccess> load({bool forceRefresh = false, CancelToken? cancelToken}) async {
    if (!forceRefresh && _cached != null) {
      return _cached!;
    }

    final dio = await ApiConfig.getDio();
    final response = await dio.get('permissions/my-permissions', cancelToken: cancelToken);
    final data = Map<String, dynamic>.from(response.data as Map);
    final instance = PermissionAccess(
      Map<String, dynamic>.from(data['privileges'] as Map),
      isSuperadmin: data['isSuperadmin'] == true,
      revision: data['revision'].toString(),
    );
    _cached = instance;
    return instance;
  }

  /// Clears in-memory permissions cache (used during logout).
  static void clearCache() {
    _cached = null;
  }

  bool can(String feature, [String action = 'view']) {
    final row = privileges[feature];
    return isSuperadmin || (row is Map && row[action] == true);
  }
}

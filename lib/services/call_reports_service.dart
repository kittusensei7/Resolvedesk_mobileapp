import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/call_report.dart';

class CallReportsService {
  const CallReportsService();

  // Recheck after secure-storage awaits, immediately before dispatching a request.
  Future<Dio> _client(bool Function() allowed) async {
    final dio = await ApiConfig.getDio();
    _checkAccess(allowed);
    return dio;
  }

  void _checkAccess(bool Function() allowed) {
    if (!allowed()) throw StateError('Call report access is unavailable');
  }

  List<CallReport> _reports(Object? data) {
    if (data is! List) {
      throw const FormatException('Invalid call reports response');
    }
    return data.map((row) {
      if (row is! Map) throw const FormatException('Invalid call report');
      return CallReport.fromJson(Map<String, dynamic>.from(row));
    }).toList();
  }

  Future<List<CallReport>> list({
    required CancelToken cancelToken,
    required bool Function() allowed,
    String search = '',
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final dio = await _client(allowed);
    _checkAccess(allowed);
    final response = await dio.get(
      'call-reports',
      cancelToken: cancelToken,
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (fromDate != null) 'fromDate': callReportDateValue(fromDate),
        if (toDate != null) 'toDate': callReportDateValue(toDate),
      },
    );
    return _reports(response.data);
  }

  Future<CallReport> get(
    int id, {
    required CancelToken cancelToken,
    required bool Function() allowed,
  }) async {
    final dio = await _client(allowed);
    _checkAccess(allowed);
    final response = await dio.get(
      'call-reports/$id',
      cancelToken: cancelToken,
    );
    if (response.data is! Map) {
      throw const FormatException('Invalid call report response');
    }
    return CallReport.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<CallReport>> history(
    CallReport report, {
    required CancelToken cancelToken,
    required bool Function() allowed,
  }) async {
    final dio = await _client(allowed);
    _checkAccess(allowed);
    final response = await dio.get(
      'call-reports/history',
      cancelToken: cancelToken,
      queryParameters: {
        'orgName': report.organizationName.trim(),
        if (report.userId != null) 'userId': report.userId,
      },
    );
    return _reports(response.data);
  }

  Future<void> save(
    CallReportInput input, {
    int? id,
    required bool Function() allowed,
  }) async {
    final validation = input.validate();
    if (validation != null) throw FormatException(validation);
    final dio = await _client(allowed);
    _checkAccess(allowed);
    if (id == null) {
      await dio.post('call-reports', data: input.toJson());
    } else {
      await dio.put('call-reports/$id', data: input.toJson());
    }
  }

  Future<void> delete(int id, {required bool Function() allowed}) async {
    final dio = await _client(allowed);
    _checkAccess(allowed);
    await dio.delete('call-reports/$id');
  }

  static String errorMessage(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
    }
    if (error is FormatException) return error.message;
    return fallback;
  }
}

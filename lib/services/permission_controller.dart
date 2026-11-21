import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'permission_access.dart';

enum PermissionStatus { signedOut, loading, ready, failed }

/// Session-owned access state. Backend grants remain the only source of truth.
class PermissionController extends ChangeNotifier with WidgetsBindingObserver {
  PermissionController({
    Future<PermissionAccess> Function(CancelToken)? loader,
    DateTime Function()? now,
    this.refreshInterval = const Duration(seconds: 15),
    this.observeLifecycle = true,
  }) : _loader =
           loader ?? ((token) => PermissionAccess.load(cancelToken: token)),
       _now = now ?? DateTime.now {
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
  }

  final Future<PermissionAccess> Function(CancelToken) _loader;
  final DateTime Function() _now;
  final bool observeLifecycle;
  final Duration refreshInterval;
  PermissionStatus status = PermissionStatus.signedOut;
  PermissionAccess? access;
  String? session;
  DateTime? _loadedAt;
  Future<void>? _pending;
  CancelToken? _cancel;
  Timer? _timer;
  int _generation = 0;
  bool _foreground = true, _disposed = false;
  DateTime? _lastDeniedRefresh;
  int get generation => _generation;
  bool get ready => status == PermissionStatus.ready;
  bool can(String feature, [String action = 'view']) =>
      ready && (access?.can(feature, action) ?? false);
  bool get hasMobileAccess => [
    'tech_dashboard',
    'service_calls',
    'installations',
    'enquiries',
    'call_reports',
  ].any((feature) => can(feature));

  void startSession(String identity) {
    if (session == identity && status != PermissionStatus.signedOut) return;
    clearSession();
    session = identity;
    status = PermissionStatus.loading;
    notifyListeners();
    _startPolling();
    unawaited(refresh());
  }

  void clearSession() {
    _generation++;
    _cancel?.cancel('Permission session ended');
    _cancel = null;
    _pending = null;
    _timer?.cancel();
    _timer = null;
    session = null;
    access = null;
    _loadedAt = null;
    _lastDeniedRefresh = null;
    status = PermissionStatus.signedOut;
    if (!_disposed) notifyListeners();
  }

  Future<void> ensureFresh() {
    if (_pending != null) return _pending!;
    if (ready &&
        _loadedAt != null &&
        _now().difference(_loadedAt!) < refreshInterval) {
      return Future.value();
    }
    return refresh();
  }

  Future<void> refresh() {
    if (_disposed || session == null) return Future.value();
    if (_pending != null) return _pending!;
    final generation = _generation;
    final token = CancelToken();
    _cancel = token;
    final completer = Completer<void>();
    _pending = completer.future;
    if (access == null) {
      status = PermissionStatus.loading;
      notifyListeners();
    }
    () async {
      try {
        final result = await _loader(token);
        if (_disposed || generation != _generation || token.isCancelled) return;
        access = result;
        _loadedAt = _now();
        status = PermissionStatus.ready;
      } catch (_) {
        if (_disposed || generation != _generation || token.isCancelled) return;
        status = PermissionStatus.failed;
      } finally {
        if (!_disposed && generation == _generation) {
          _pending = null;
          _cancel = null;
          notifyListeners();
        }
        completer.complete();
      }
    }();
    return completer.future;
  }

  /// One refresh per denial burst. Never retries the rejected business request.
  void permissionDenied() {
    if (session == null || _disposed) return;
    final now = _now();
    if (_lastDeniedRefresh != null &&
        now.difference(_lastDeniedRefresh!) < const Duration(seconds: 2)) {
      return;
    }
    _lastDeniedRefresh = now;
    status = PermissionStatus.failed;
    notifyListeners();
    unawaited(refresh());
  }

  void _startPolling() {
    _timer?.cancel();
    if (!_foreground || session == null || _disposed) return;
    _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _startPolling();
      unawaited(refresh());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    clearSession();
    if (observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/permission_controller.dart';

class PermissionRead {
  PermissionRead(this.token, this.generation, this.sessionGeneration);
  final CancelToken token;
  final int generation, sessionGeneration;
}

/// Shared read lifetime; screen state (including local form drafts) stays owned
/// by its existing State object, never by the global revision number.
mixin PermissionAware<T extends StatefulWidget> on State<T> {
  PermissionController get permissions => context.read<PermissionController>();
  String get permissionFeature;
  String get permissionReadAction => 'view';
  void clearProtectedData();
  Future<void> reloadProtectedData();
  void permissionStateChanged() {}
  CancelToken? _readToken;
  int _readGeneration = 0;
  bool _readAttempted = false;
  bool _wasAllowed = false;
  PermissionController? _boundPermissions;
  late final int permissionSessionGeneration;

  void bindPermissions() {
    _boundPermissions = permissions;
    permissionSessionGeneration = permissions.generation;
    _wasAllowed = permissions.can(permissionFeature, permissionReadAction);
    permissions.addListener(_permissionChanged);
  }

  void _permissionChanged() {
    if (!mounted) return;
    final sameSession = permissionSessionGeneration == permissions.generation;
    final allowed = sameSession && permissions.can(permissionFeature, permissionReadAction);
    if (!allowed) {
      _readGeneration++;
      _readToken?.cancel('Access unavailable');
      if (!sameSession || !permissions.can(permissionFeature)) clearProtectedData();
    }
    final restored = allowed && !_wasAllowed && _readAttempted;
    _wasAllowed = allowed;
    permissionStateChanged();
    setState(() {});
    if (restored) unawaited(reloadProtectedData());
  }

  Future<PermissionRead?> beginPermissionRead([String action = 'view']) async {
    await permissions.ensureFresh();
    if (!mounted || permissionSessionGeneration != permissions.generation) return null;
    _readAttempted = true;
    if (!permissions.can(permissionFeature, action)) return null;
    _readToken?.cancel('Read superseded');
    final token = CancelToken();
    _readToken = token;
    return PermissionRead(token, ++_readGeneration, permissions.generation);
  }

  bool currentPermissionRead(PermissionRead read, [String action = 'view']) =>
      mounted &&
      !read.token.isCancelled &&
      read.generation == _readGeneration &&
      read.sessionGeneration == permissions.generation &&
      permissions.can(permissionFeature, action);

  Future<bool> requirePermission([String action = 'view']) async {
    await permissions.ensureFresh();
    if (!mounted || permissionSessionGeneration != permissions.generation) return false;
    if (permissions.can(permissionFeature, action)) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Access is unavailable. Your work has not been submitted.',
        ),
      ),
    );
    return false;
  }

  @override
  void dispose() {
    _boundPermissions?.removeListener(_permissionChanged);
    _readToken?.cancel('Screen closed');
    super.dispose();
  }
}

class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.feature,
    required this.child,
    this.writeAction,
    this.writeAllowed,
    this.sessionGeneration,
  });
  final String feature;
  final Widget child;
  final String? writeAction;
  final bool Function(PermissionController)? writeAllowed;
  final int? sessionGeneration;

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionController>();
    if (sessionGeneration != null && sessionGeneration != permissions.generation) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text(
        'Your session has changed. Close this screen and continue with your current account.', textAlign: TextAlign.center)));
    }
    if (!permissions.ready) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (permissions.status == PermissionStatus.loading)
                const CircularProgressIndicator()
              else ...[
                const Icon(Icons.lock_outline, size: 32),
                const SizedBox(height: 12),
                const Text(
                  'Unable to verify access. Please retry.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: permissions.refresh,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (!permissions.can(feature)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 32),
              const SizedBox(height: 12),
              const Text(
                'You no longer have access to this section. Contact Helpdesk.',
                textAlign: TextAlign.center,
              ),
              if (Navigator.of(context).canPop())
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Back'),
                ),
            ],
          ),
        ),
      );
    }
    final editable =
        writeAllowed?.call(permissions) ??
        (writeAction == null || permissions.can(feature, writeAction!));
    if (editable) return child;
    return Column(
      children: [
        const Material(
          color: Color(0xfffff7ed),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your access has changed. This draft is kept while this form stays open, but editing and saving are disabled.',
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Disable form sections without swallowing the enclosing list's scroll gestures.
class PermissionFormSection extends StatelessWidget {
  const PermissionFormSection({
    super.key,
    required this.feature,
    required this.action,
    required this.child,
    this.writeAllowed,
  });
  final String feature, action;
  final Widget child;
  final bool Function(PermissionController)? writeAllowed;
  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionController>();
    final enabled =
        writeAllowed?.call(permissions) ?? permissions.can(feature, action);
    return ExcludeFocus(
      excluding: !enabled,
      child: AbsorbPointer(absorbing: !enabled, child: child),
    );
  }
}

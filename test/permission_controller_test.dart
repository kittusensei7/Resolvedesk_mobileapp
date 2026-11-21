import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resolvedesk_mobileapp/services/permission_access.dart';
import 'package:resolvedesk_mobileapp/services/permission_controller.dart';

const allowed = PermissionAccess({
  'service_calls': {'view': true, 'add': true},
}, revision: '1');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'one pending load serves login and simultaneous screen requests',
    () async {
      final reply = Completer<PermissionAccess>();
      var calls = 0;
      final controller = PermissionController(
        loader: (_) {
          calls++;
          return reply.future;
        },
        observeLifecycle: false,
      );
      addTearDown(controller.dispose);
      controller.startSession('one');
      final first = controller.ensureFresh(), second = controller.ensureFresh();
      expect(identical(first, second), true);
      expect(calls, 1);
      reply.complete(allowed);
      await first;
      expect(controller.can('service_calls', 'add'), true);
      await controller.ensureFresh();
      expect(calls, 1);
    },
  );
  test(
    'refresh failure blocks previous grants; retry restores access',
    () async {
      var fail = false;
      final controller = PermissionController(
        loader: (_) async {
          if (fail) throw Exception('offline');
          return allowed;
        },
        observeLifecycle: false,
      );
      addTearDown(controller.dispose);
      controller.startSession('one');
      await controller.ensureFresh();
      fail = true;
      await controller.refresh();
      expect(controller.status, PermissionStatus.failed);
      expect(controller.can('service_calls'), false);
      fail = false;
      await controller.refresh();
      expect(controller.can('service_calls'), true);
    },
  );
  test(
    'logout and account changes cancel and reject former responses',
    () async {
      final replies = [
        Completer<PermissionAccess>(),
        Completer<PermissionAccess>(),
      ];
      var calls = 0;
      final tokens = [];
      final controller = PermissionController(
        loader: (token) {
          tokens.add(token);
          return replies[calls++].future;
        },
        observeLifecycle: false,
      );
      addTearDown(controller.dispose);
      controller.startSession('old');
      final old = controller.ensureFresh();
      controller.startSession('new');
      final current = controller.ensureFresh();
      replies[0].complete(allowed);
      await old;
      expect(tokens[0].isCancelled, true);
      expect(controller.can('service_calls'), false);
      replies[1].complete(const PermissionAccess({}));
      await current;
      expect(controller.session, 'new');
      expect(controller.hasMobileAccess, false);
      controller.clearSession();
      expect(tokens[1].isCancelled, false);
      expect(controller.access, null);
      expect(controller.status, PermissionStatus.signedOut);
    },
  );
  test('freshness expires at 15 seconds and requests are shared', () async {
    var time = DateTime(2026), calls = 0;
    final controller = PermissionController(
      loader: (_) async {
        calls++;
        return allowed;
      },
      now: () => time,
      observeLifecycle: false,
    );
    addTearDown(controller.dispose);
    controller.startSession('one');
    await controller.ensureFresh();
    time = time.add(const Duration(seconds: 14));
    await controller.ensureFresh();
    expect(calls, 1);
    time = time.add(const Duration(seconds: 1));
    await controller.ensureFresh();
    expect(calls, 2);
  });
  test('denial bursts refresh once without retrying business writes', () async {
    var calls = 0;
    final controller = PermissionController(
      loader: (_) async {
        calls++;
        return allowed;
      },
      observeLifecycle: false,
    );
    addTearDown(controller.dispose);
    controller.startSession('one');
    await controller.ensureFresh();
    controller.permissionDenied();
    controller.permissionDenied();
    controller.permissionDenied();
    await controller.ensureFresh();
    expect(calls, 2);
    expect(controller.session, 'one');
  });
  testWidgets(
    'polling pauses in background and resumes with immediate refresh',
    (tester) async {
      var calls = 0;
      final controller = PermissionController(
        loader: (_) async {
          calls++;
          return allowed;
        },
        observeLifecycle: false,
      );
      controller.startSession('one');
      await tester.pump();
      expect(calls, 1);
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 31));
      expect(calls, 1);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 2);
      await tester.pump(const Duration(seconds: 15));
      expect(calls, 3);
      controller.dispose();
      await tester.pump(const Duration(seconds: 16));
      expect(calls, 3);
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:resolvedesk_mobileapp/config/api_config.dart';
import 'package:resolvedesk_mobileapp/pages/create_installation_report_page.dart';
import 'package:resolvedesk_mobileapp/pages/create_service_report_page.dart';
import 'package:resolvedesk_mobileapp/pages/enquiries_page.dart';
import 'package:resolvedesk_mobileapp/pages/installation_reports_page.dart';
import 'package:resolvedesk_mobileapp/pages/service_call_reports_page.dart';
import 'package:resolvedesk_mobileapp/pages/complaint_details_page.dart';
import 'package:resolvedesk_mobileapp/services/permission_access.dart';
import 'package:resolvedesk_mobileapp/services/permission_controller.dart';
import 'package:resolvedesk_mobileapp/services/notification_service.dart';
import 'package:resolvedesk_mobileapp/pages/technician_dashboard_page.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.reply);
  final Future<ResponseBody> Function(RequestOptions) reply;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) => reply(options);
  @override
  void close({bool force = false}) {}
}

PermissionAccess grant({
  bool view = true,
  bool add = true,
  String revision = '1',
}) => PermissionAccess({
  'installations': {'view': view, 'add': add, 'edit': add},
  'service_calls': {'view': view, 'add': add, 'edit': add},
  'enquiries': {'view': view, 'add': add},
}, revision: revision);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = Platform.environment['PERMISSION_REVIEW_FONT_DIR'];
    if (fonts != null) {
      for (final font in {
        'Roboto': 'roboto-regular.ttf',
        'MaterialIcons': 'materialicons-regular.otf',
      }.entries) {
        final loader = FontLoader(font.key);
        loader.addFont(
          Future.value(
            ByteData.sublistView(
              await File('$fonts/${font.value}').readAsBytes(),
            ),
          ),
        );
        await loader.load();
      }
    }
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'resolvedesk_token': 'test-token',
      'resolvedesk_user_json': jsonEncode({'id': 2, 'role': 'dual'}),
      'resolvedesk_api_url': 'http://localhost:4000/api',
    });
  });
  tearDown(() {
    ApiConfig.adapterFactory = null;
    ApiConfig.onPermissionDenied = null;
    ApiConfig.onSessionChanged = null;
  });
  Future<void> host(
    WidgetTester tester,
    PermissionController controller,
    Widget child, {
    Key? boundary,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          navigatorKey: NotificationService.navigatorKey,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff2457d6),
            ),
          ),
          home: RepaintBoundary(key: boundary, child: child),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> finishBackgroundChecks(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final page in <String, Widget>{
    'enquiries': const EnquiriesPage(),
    'installations': const InstallationReportsPage(),
    'service_calls': const ServiceCallReportsPage(),
    'notification detail': const ComplaintDetailsPage(complaintId: 1),
  }.entries) {
    testWidgets('direct ${page.key} entry with no View never fetches data', (
      tester,
    ) async {
      var calls = 0;
      ApiConfig.adapterFactory = () => Adapter((_) async {
        calls++;
        return ResponseBody.fromString('[]', 200);
      });
      final controller = PermissionController(
        loader: (_) async => const PermissionAccess({}),
        observeLifecycle: false,
      );
      controller.startSession('one');
      await controller.ensureFresh();
      await host(tester, controller, page.value);
      expect(find.textContaining('no longer have access'), findsOneWidget);
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
  testWidgets(
    'form draft survives Add removal, unrelated revision and restoration',
    (tester) async {
      var snapshot = grant();
      final controller = PermissionController(
        loader: (_) async => snapshot,
        observeLifecycle: false,
      );
      controller.startSession('one');
      await controller.ensureFresh();
      await host(tester, controller, const CreateInstallationReportPage());
      await tester.enterText(
        find.byType(TextFormField).first,
        'Draft customer',
      );
      final draft = tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!;
      snapshot = grant(revision: '2');
      await controller.refresh();
      await tester.pump();
      expect(draft.text, 'Draft customer');
      snapshot = grant(add: false, revision: '3');
      await controller.refresh();
      await tester.pump();
      expect(
        find.textContaining('editing and saving are disabled'),
        findsOneWidget,
      );
      final save = find.widgetWithText(
        FilledButton,
        'Save Installation Report',
      );
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(save).onPressed, null);
      expect(draft.text, 'Draft customer');
      snapshot = grant(view: false, add: false, revision: '4');
      await controller.refresh();
      await tester.pump();
      expect(find.text('Draft customer'), findsNothing);
      snapshot = grant(revision: '5');
      await controller.refresh();
      await tester.pump();
      expect(draft.text, 'Draft customer');
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'failed refresh pauses content; Retry restores the existing draft',
    (tester) async {
      var fail = false;
      final controller = PermissionController(
        loader: (_) async {
          if (fail) throw Exception('offline');
          return grant();
        },
        observeLifecycle: false,
      );
      controller.startSession('one');
      await controller.ensureFresh();
      await host(tester, controller, const CreateInstallationReportPage());
      await tester.enterText(find.byType(TextFormField).first, 'Unsent');
      fail = true;
      await controller.refresh();
      await tester.pump();
      expect(find.text('Unsent'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Unsent'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets('late enquiry response cannot repopulate revoked data', (
    tester,
  ) async {
    var snapshot = grant();
    final response = Completer<ResponseBody>();
    var calls = 0;
    ApiConfig.adapterFactory = () => Adapter((_) {
      calls++;
      return response.future;
    });
    final controller = PermissionController(
      loader: (_) async => snapshot,
      observeLifecycle: false,
    );
    controller.startSession('one');
    await controller.ensureFresh();
    await host(tester, controller, const EnquiriesPage());
    await tester.pump();
    await tester.runAsync(() async {
      for (var i = 0; i < 20 && calls == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    for (var i = 0; i < 5 && calls == 0; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(
      calls,
      1,
      reason: tester.allWidgets
          .whereType<Text>()
          .map((text) => text.data)
          .join(' | '),
    );
    snapshot = const PermissionAccess({});
    await controller.refresh();
    await tester.pump();
    response.complete(
      ResponseBody.fromString(
        '[{"company":"Revoked secret"}]',
        200,
        headers: {
          'content-type': ['application/json'],
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Revoked secret'), findsNothing);
    expect(find.textContaining('no longer have access'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets(
    'notification navigation checks access before pushing a complaint',
    (tester) async {
      var calls = 0;
      ApiConfig.adapterFactory = () => Adapter((_) async {
        calls++;
        return ResponseBody.fromString('[]', 200);
      });
      final controller = PermissionController(
        loader: (_) async => const PermissionAccess({}),
        observeLifecycle: false,
      );
      controller.startSession('one');
      await controller.ensureFresh();
      await host(tester, controller, const Scaffold(body: Text('Home')));
      NotificationService.navigateToComplaint('42');
      await tester.pump();
      expect(find.byType(ComplaintDetailsPage), findsNothing);
      expect(calls, 0);
      expect(
        find.textContaining('no longer have access to this complaint'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets('unrelated revision does not recreate the active dashboard tab', (
    tester,
  ) async {
    var snapshot = grant();
    ApiConfig.adapterFactory = () => Adapter(
      (request) async => ResponseBody.fromString(
        request.path == 'app-version' ? '{"versionCode":13}' : '[]',
        200,
        headers: {
          'content-type': ['application/json'],
        },
      ),
    );
    final controller = PermissionController(
      loader: (_) async => snapshot,
      observeLifecycle: false,
    );
    controller.startSession('one');
    await controller.ensureFresh();
    await host(
      tester,
      controller,
      const TechnicianDashboardPage(
        user: {'id': 2, 'username': 'Test technician'},
      ),
    );
    await finishBackgroundChecks(tester);
    await tester.tap(find.text('Installations').last);
    await tester.pump();
    final before = tester.state(find.byType(InstallationReportsPage));
    snapshot = grant(revision: '900');
    await controller.refresh();
    await tester.pump();
    expect(
      identical(before, tester.state(find.byType(InstallationReportsPage))),
      true,
    );
    await finishBackgroundChecks(tester);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.pump();
  });
  testWidgets(
    'all optional features off leaves a no-access message and logout',
    (tester) async {
      ApiConfig.adapterFactory = () => Adapter(
        (request) async => ResponseBody.fromString(
          request.path == 'app-version' ? '{"versionCode":13}' : '[]',
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      final controller = PermissionController(
        loader: (_) async => const PermissionAccess({}),
        observeLifecycle: false,
      );
      controller.startSession('one');
      await controller.ensureFresh();
      await host(
        tester,
        controller,
        const TechnicianDashboardPage(
          user: {'id': 2, 'username': 'Test technician'},
        ),
      );
      await finishBackgroundChecks(tester);
      expect(
        find.text('No mobile sections are enabled. Contact Helpdesk.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.logout), findsWidgets);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.pump();
    },
  );
  test('old-session 401 cannot clear a newly signed-in account', () async {
    final response = Completer<ResponseBody>();
    ApiConfig.adapterFactory = () => Adapter((_) => response.future);
    final old = await ApiConfig.getDio();
    final pending = old.get('enquiries');
    final assertion = expectLater(pending, throwsA(isA<DioException>()));
    await ApiConfig.setToken('new-session-token');
    response.complete(
      ResponseBody.fromString(
        '{}',
        401,
        headers: {
          'content-type': ['application/json'],
        },
      ),
    );
    await assertion;
    expect(await ApiConfig.getToken(), 'new-session-token');
  });
  test(
    'structured 403 refreshes once, preserves login and never retries a POST',
    () async {
      var calls = 0, loads = 0;
      final controller = PermissionController(
        loader: (_) async {
          loads++;
          return grant();
        },
        observeLifecycle: false,
      );
      addTearDown(controller.dispose);
      controller.startSession('one');
      await controller.ensureFresh();
      ApiConfig.onPermissionDenied = controller.permissionDenied;
      ApiConfig.adapterFactory = () => Adapter((request) async {
        calls++;
        expect(request.headers['x-active-role'], 'technician');
        return ResponseBody.fromString(
          '{"code":"PERMISSION_DENIED","message":"Denied"}',
          403,
          headers: {
            'content-type': ['application/json'],
          },
        );
      });
      final dio = await ApiConfig.getDio();
      await expectLater(
        dio.post('enquiries', data: {}),
        throwsA(isA<DioException>()),
      );
      await controller.ensureFresh();
      expect(calls, 1);
      expect(loads, 2);
      expect(await ApiConfig.getToken(), 'test-token');
    },
  );
  testWidgets(
    'view-only service form never fetches Add-only complaint lookup',
    (tester) async {
      // This case verifies request authorization, independently of the Ahem
      // test font's oversized labels in the existing service-form layout.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      ApiConfig.adapterFactory = () => Adapter((_) async {
        calls++;
        return ResponseBody.fromString('[]', 200);
      });
      final controller = PermissionController(
        loader: (_) async => grant(add: false),
        observeLifecycle: false,
      );
      controller.startSession('one');
      await controller.ensureFresh();
      await host(tester, controller, const CreateServiceReportPage());
      await finishBackgroundChecks(tester);
      expect(calls, 0);
      expect(
        find.textContaining('editing and saving are disabled'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'revoking Delete while confirmation is open prevents the DELETE request',
    (tester) async {
      var snapshot = const PermissionAccess({
        'service_calls': {'view': true, 'delete': true},
      });
      var writes = 0;
      ApiConfig.adapterFactory = () => Adapter((request) async {
        if (request.method != 'GET') writes++;
        return ResponseBody.fromString(
          '[{"id":8,"customer_name":"Demo Client"}]',
          200,
          headers: {
            'content-type': ['application/json'],
          },
        );
      });
      final controller = PermissionController(
        loader: (_) async => snapshot,
        observeLifecycle: false,
      );
      controller.startSession('one');
      await controller.ensureFresh();
      await host(tester, controller, const ServiceCallReportsPage());
      await finishBackgroundChecks(tester);
      final remove = find.widgetWithText(OutlinedButton, 'Delete');
      await tester.scrollUntilVisible(
        remove,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.text('Delete Service Report'), findsOneWidget);
      snapshot = const PermissionAccess({
        'service_calls': {'view': true, 'delete': false},
      });
      await controller.refresh();
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await finishBackgroundChecks(tester);
      expect(writes, 0);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets('an old form cannot expose its draft to a replacement session', (tester) async {
    final controller = PermissionController(loader: (_) async => grant(), observeLifecycle: false);
    controller.startSession('old-user');
    await controller.ensureFresh();
    await host(tester, controller, const CreateInstallationReportPage());
    await tester.enterText(find.byType(TextFormField).first, 'Old user draft');
    controller.startSession('new-user');
    await controller.ensureFresh();
    await tester.pump();
    expect(find.text('Old user draft'), findsNothing);
    expect(find.textContaining('Your session has changed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  for (final width in [390.0, 1024.0]) {
    testWidgets(
      'permission draft layout has no overflow at ${width.toInt()}px',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = PermissionController(
          loader: (_) async => grant(add: false),
          observeLifecycle: false,
        );
        controller.startSession('one');
        await controller.ensureFresh();
        final boundary = GlobalKey();
        await host(
          tester,
          controller,
          const CreateInstallationReportPage(),
          boundary: boundary,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        final output = Platform.environment['PERMISSION_SCREENSHOT_DIR'];
        if (output != null) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(output).create(recursive: true);
            await File(
              '$output/mobile-permissions-${width.toInt()}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}

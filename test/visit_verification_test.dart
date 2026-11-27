import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:resolvedesk_mobileapp/models/visit_verification_models.dart';
import 'package:resolvedesk_mobileapp/services/visit_location_service.dart';
import 'package:resolvedesk_mobileapp/services/visit_photo_service.dart';
import 'package:resolvedesk_mobileapp/services/visit_verification_controller.dart';
import 'package:resolvedesk_mobileapp/widgets/visit_verification_sheet.dart';

class _StubHttpAdapter implements HttpClientAdapter {
  _StubHttpAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

Dio _buildStubDio(Future<ResponseBody> Function(RequestOptions) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local/api'));
  dio.httpClientAdapter = _StubHttpAdapter(handler);
  return dio;
}

Position _pos(double lat, double lng, double accuracy) => Position(
  longitude: lng,
  latitude: lat,
  timestamp: DateTime(2026, 11, 26, 12, 0),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  test('formatVisitGeofenceLabel matches shared Web geofence labels', () {
    expect(formatVisitGeofenceLabel(null), 'No Visit Logged');
    expect(formatVisitGeofenceLabel({'is_location_flagged': false}), 'Verified (On-Site)');
    expect(
      formatVisitGeofenceLabel({
        'is_location_flagged': true,
        'location_flag_reason': 'Missing GPS coordinates for on-site verification',
      }),
      'Flagged (Missing GPS)',
    );
    expect(
      formatVisitGeofenceLabel({
        'is_location_flagged': 1,
        'location_flag_reason': 'Resolved 720m from check-in site (exceeds 250m limit)',
      }),
      'Flagged (> 250m)',
    );
  });

  test('VisitLocationService handles GPS OFF, permission denial, and refined lock', () async {
    final gpsOffSvc = VisitLocationService(
      isLocationServiceEnabled: () async => false,
    );
    VisitLocationState? errState;
    String? errMsg;
    await gpsOffSvc.acquireBestPosition(
      onReading: (_) {},
      onFinal: (_) => fail('Should not lock when GPS is off'),
      onError: (s, m) {
        errState = s;
        errMsg = m;
      },
      isCancelled: () => false,
    );
    expect(errState, VisitLocationState.serviceDisabled);
    expect(errMsg, contains('Turn On GPS'));

    // Permanently denied check
    final deniedForeverSvc = VisitLocationService(
      isLocationServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.deniedForever,
    );
    await deniedForeverSvc.acquireBestPosition(
      onReading: (_) {},
      onFinal: (_) => fail('Should not lock when permanently denied'),
      onError: (s, _) => errState = s,
      isCancelled: () => false,
    );
    expect(errState, VisitLocationState.permissionDeniedForever);

    // Stream refines 500m coarse fix down to 14m tight fix
    final streamCtrl = StreamController<Position>();
    final readings = <VisitGpsFix>[];
    VisitGpsFix? finalFix;

    final streamSvc = VisitLocationService(
      isLocationServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () async => LocationPermission.whileInUse,
      getPositionStream: (_) => streamCtrl.stream,
    );

    await streamSvc.acquireBestPosition(
      onReading: readings.add,
      onFinal: (f) => finalFix = f,
      onError: (_, m) => fail('Unexpected error: $m'),
      isCancelled: () => false,
    );

    streamCtrl.add(_pos(17.710001, 83.300001, 500));
    await Future<void>.delayed(Duration.zero);
    streamCtrl.add(_pos(17.713803, 83.302137, 14));
    await Future<void>.delayed(Duration.zero);

    expect(readings.length, 2);
    expect(readings.first.isApproximate, true);
    expect(finalFix?.lat, 17.713803);
    expect(finalFix?.accuracyMeters, 14);
    expect(finalFix?.isApproximate, false);
    await streamCtrl.close();
  });

  test('VisitLocationService uses Android Placemark format cleanly and falls back to backend Google API', () async {
    final formatted = VisitLocationService.formatPlacemarkAddress([
      const Placemark(
        name: '12-4-13/2',
        subThoroughfare: '12-4-13/2',
        thoroughfare: 'Hotel Green Park Road',
        subLocality: 'Prakasaraopeta',
        locality: 'Visakhapatnam',
        postalCode: '530020',
      ),
    ]);
    expect(
      formatted,
      '12-4-13/2, Hotel Green Park Road, Prakasaraopeta, Visakhapatnam, 530020',
    );

    // Strips raw Plus Codes and falls back to backend Google Geocoding when native returns sparse parts
    final dio = _buildStubDio((req) async {
      expect(req.path, '/complaints/reverse-geocode');
      return ResponseBody.fromString(
        jsonEncode({'address': '12-4-13/2, Green Park Road, Prakasaraopeta, 530020', 'source': 'google'}),
        200,
        headers: {'content-type': ['application/json']},
      );
    });
    final svc = VisitLocationService(
      dioProvider: () async => dio,
      placemarkLookup: (_, _) async => const [
        Placemark(name: 'P872+GVG', locality: 'Visakhapatnam'),
      ],
    );
    final addr = await svc.reverseGeocode(17.713809, 83.302244);
    expect(addr, '12-4-13/2, Green Park Road, Prakasaraopeta, 530020');

    final failingDio = _buildStubDio((_) async => throw DioException(requestOptions: RequestOptions()));
    final fallbackSvc = VisitLocationService(
      dioProvider: () async => failingDio,
      placemarkLookup: (_, _) async => const [],
    );
    expect(await fallbackSvc.reverseGeocode(17.713803, 83.302137), '17.713803, 83.302137');
  });

  test('VisitLocationService fast-starts from fresh getLastKnownPosition (< 20s & <= 25m)', () async {
    VisitGpsFix? fastFix;
    final fastSvc = VisitLocationService(
      isLocationServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.whileInUse,
      getLastKnownPosition: () async => Position(
        longitude: 83.302244,
        latitude: 17.713809,
        timestamp: DateTime.now().subtract(const Duration(seconds: 4)),
        accuracy: 13,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
    await fastSvc.acquireBestPosition(
      onReading: (_) {},
      onFinal: (f) => fastFix = f,
      onError: (_, m) => fail('Unexpected error: $m'),
      isCancelled: () => false,
    );
    expect(fastFix?.lat, 17.713809);
    expect(fastFix?.accuracyMeters, 13);
  });

  test('VisitPhotoService handles camera permission states and watermark text formatting', () async {
    final deniedSvc = VisitPhotoService(
      checkCameraPermission: () async => PermissionStatus.denied,
      requestCameraPermission: () async => PermissionStatus.denied,
    );
    final deniedOutcome = await deniedSvc.captureAndWatermark(lat: 17.71, lng: 83.30);
    expect(deniedOutcome.state, VisitCameraState.permissionDenied);

    final foreverSvc = VisitPhotoService(
      checkCameraPermission: () async => PermissionStatus.permanentlyDenied,
      requestCameraPermission: () async => PermissionStatus.permanentlyDenied,
    );
    final foreverOutcome = await foreverSvc.captureAndWatermark();
    expect(foreverOutcome.state, VisitCameraState.permissionDeniedForever);

    final stamp = VisitPhotoService.buildWatermarkText(
      lat: 17.713803,
      lng: 83.302137,
      now: DateTime(2026, 11, 26, 14, 5),
    );
    expect(stamp, 'ResolveDesk Verified | 26 Nov 2026 2:05 pm | Lat: 17.713803, Lng: 83.302137');
  });

  testWidgets('VisitVerificationSheet renders GPS OFF recovery & allows switching to Remote work', (
    tester,
  ) async {
    final dio = _buildStubDio((req) async {
      if (req.path == '/complaints/visit-policy') {
        return ResponseBody.fromString(
          jsonEncode({'geofenceRadiusMeters': 500, 'strictGpsRequired': true}),
          200,
          headers: {'content-type': ['application/json']},
        );
      }
      return ResponseBody.fromString('{}', 200, headers: {'content-type': ['application/json']});
    });

    final locationSvc = VisitLocationService(
      dioProvider: () async => dio,
      isLocationServiceEnabled: () async => false,
    );
    final controller = VisitVerificationController(
      complaintId: 99,
      mode: VisitVerificationMode.checkin,
      locationService: locationSvc,
      dioProvider: () async => dio,
    );

    VisitVerificationResult? sheetResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  sheetResult = await VisitVerificationSheet.show(
                    context,
                    complaintId: 99,
                    mode: VisitVerificationMode.checkin,
                    complaintSummary: 'CMP-2026-00099 • Retail Supermarket',
                    controller: controller,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Phone Location (GPS) is Off'), findsOneWidget);
    expect(find.text('Turn On GPS'), findsOneWidget);
    expect(find.text('Turn On GPS First'), findsOneWidget);

    // Switch to Remote / In-Office: bypasses GPS & camera and enables Start Remote Work
    await tester.tap(find.text('Remote / In-Office'));
    await tester.pumpAndSettle();
    expect(find.text('Start Remote Work'), findsOneWidget);

    await tester.tap(find.text('Start Remote Work'));
    await tester.pumpAndSettle();

    expect(sheetResult?.supportType, 'Remote');
    expect(sheetResult?.alreadySubmittedCheckin, false);
  });
}

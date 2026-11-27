import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../config/api_config.dart';
import '../models/visit_verification_models.dart';

/// Encapsulates fast native GPS acquisition (`geolocator`),
/// free Android OS `Geocoder` (`geocoding`) address formatting
/// (Flat/Door No, Street, Sub-Locality, Locality, City, Pincode),
/// and backend `/complaints/reverse-geocode` fallback.
class VisitLocationService {
  VisitLocationService({
    Future<Dio> Function()? dioProvider,
    Future<bool> Function()? isLocationServiceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<Position> Function(LocationSettings)? getCurrentPosition,
    Stream<Position> Function(LocationSettings)? getPositionStream,
    Future<Position?> Function()? getLastKnownPosition,
    Future<bool> Function()? openLocationSettings,
    Future<bool> Function()? openAppSettings,
    Future<List<Placemark>> Function(double lat, double lng)? placemarkLookup,
  }) : _dioProvider = dioProvider ?? ApiConfig.getDio,
       _isLocationServiceEnabled =
           isLocationServiceEnabled ?? Geolocator.isLocationServiceEnabled,
       _checkPermission = checkPermission ?? Geolocator.checkPermission,
       _requestPermission = requestPermission ?? Geolocator.requestPermission,
       _getCurrentPosition =
           getCurrentPosition ??
           ((settings) =>
               Geolocator.getCurrentPosition(locationSettings: settings)),
       _getPositionStream =
           getPositionStream ??
           ((settings) =>
               Geolocator.getPositionStream(locationSettings: settings)),
       _getLastKnownPosition =
           getLastKnownPosition ?? Geolocator.getLastKnownPosition,
       _openLocationSettings =
           openLocationSettings ?? Geolocator.openLocationSettings,
       _openAppSettings = openAppSettings ?? Geolocator.openAppSettings,
       _placemarkLookup = placemarkLookup ?? _defaultPlacemarkLookup;

  static Future<List<Placemark>> _defaultPlacemarkLookup(
    double lat,
    double lng,
  ) => Geocoding().placemarkFromCoordinates(lat, lng);

  static const int targetAccuracyMeters = 25;
  static const int fastCacheMaxAccuracyMeters = 35;
  static const Duration fastCacheMaxAge = Duration(seconds: 20);
  static const int approximateAccuracyThresholdMeters = 300;
  static const Duration warmupDuration = Duration(milliseconds: 2500);
  static const Duration maxFixTimeout = Duration(seconds: 10);

  final Future<Dio> Function() _dioProvider;
  final Future<bool> Function() _isLocationServiceEnabled;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Future<Position> Function(LocationSettings) _getCurrentPosition;
  final Stream<Position> Function(LocationSettings) _getPositionStream;
  final Future<Position?> Function() _getLastKnownPosition;
  final Future<bool> Function() _openLocationSettings;
  final Future<bool> Function() _openAppSettings;
  final Future<List<Placemark>> Function(double lat, double lng)
  _placemarkLookup;

  static final RegExp _plusCodePattern = RegExp(
    r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}$',
    caseSensitive: false,
  );

  Future<VisitPolicy> fetchVisitPolicy() async {
    try {
      final dio = await _dioProvider();
      final res = await dio.get('/complaints/visit-policy');
      if (res.data is Map) {
        return VisitPolicy.fromJson(
          Map<String, dynamic>.from(res.data as Map),
        );
      }
    } catch (_) {}
    return const VisitPolicy();
  }

  /// Ensures device GPS hardware switch is ON and runtime permission is granted.
  Future<VisitLocationState> ensureLocationReady({
    bool requestIfNeeded = true,
  }) async {
    final serviceEnabled = await _isLocationServiceEnabled();
    if (!serviceEnabled) {
      return VisitLocationState.serviceDisabled;
    }

    var permission = await _checkPermission();
    if (permission == LocationPermission.denied && requestIfNeeded) {
      permission = await _requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return VisitLocationState.permissionDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return VisitLocationState.permissionDeniedForever;
    }

    return VisitLocationState.acquiring;
  }

  Future<bool> openLocationSettings() => _openLocationSettings();

  Future<bool> openAppSettings() => _openAppSettings();

  /// Fast-path + live Fused GPS stream:
  /// 1) Reuses fresh `getLastKnownPosition()` (< 20s & <= 35m) immediately so UI loads fast.
  /// 2) Streams `LocationAccuracy.high` for up to 2.5s to tighten down to <= 25m.
  Future<void> acquireBestPosition({
    required void Function(VisitGpsFix fix) onReading,
    required void Function(VisitGpsFix fix) onFinal,
    required void Function(VisitLocationState state, String message) onError,
    required bool Function() isCancelled,
    void Function(void Function() cancel)? onCancelHandle,
  }) async {
    final readyState = await ensureLocationReady();
    if (isCancelled()) return;

    if (readyState == VisitLocationState.serviceDisabled) {
      onError(
        VisitLocationState.serviceDisabled,
        'Phone Location (GPS) is turned off. Tap "Turn On GPS" to enable it.',
      );
      return;
    }
    if (readyState == VisitLocationState.permissionDenied) {
      onError(
        VisitLocationState.permissionDenied,
        'Location permission was denied. Tap "Allow Location" to grant access.',
      );
      return;
    }
    if (readyState == VisitLocationState.permissionDeniedForever) {
      onError(
        VisitLocationState.permissionDeniedForever,
        'Location permission is permanently denied in Android settings. Open App Settings to allow Precise Location.',
      );
      return;
    }

    final LocationSettings settings =
        defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: const Duration(milliseconds: 500),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          );

    bool settled = false;
    StreamSubscription<Position>? sub;
    Timer? warmupTimer;
    Timer? hardTimer;
    VisitGpsFix? bestFix;

    void clearResources() {
      warmupTimer?.cancel();
      warmupTimer = null;
      hardTimer?.cancel();
      hardTimer = null;
      sub?.cancel();
      sub = null;
    }

    void finishSuccess(VisitGpsFix fix) {
      if (settled || isCancelled()) {
        clearResources();
        return;
      }
      settled = true;
      clearResources();
      onFinal(fix);
    }

    // Fast-start using fresh cached OS Fused Location fix (< 20s old & <= 35m accuracy)
    try {
      final lastPos = await _getLastKnownPosition();
      if (!isCancelled() && lastPos != null) {
        final age = DateTime.now().difference(lastPos.timestamp).abs();
        final cachedFix = _toFix(lastPos);
        if (age <= fastCacheMaxAge &&
            cachedFix.accuracyMeters <= fastCacheMaxAccuracyMeters) {
          bestFix = cachedFix;
          onReading(cachedFix);
          if (cachedFix.accuracyMeters <= targetAccuracyMeters) {
            finishSuccess(cachedFix);
            return;
          }
        }
      }
    } catch (_) {}

    if (isCancelled() || settled) return;

    Future<void> tryFallbackOrFail(String fallbackReason) async {
      if (settled || isCancelled()) {
        clearResources();
        return;
      }
      if (bestFix != null) {
        finishSuccess(bestFix!);
        return;
      }

      clearResources();

      try {
        final mediumPos = await _getCurrentPosition(
          const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        if (!isCancelled() && !settled) {
          finishSuccess(_toFix(mediumPos));
          return;
        }
      } catch (_) {}

      try {
        final lastPos = await _getLastKnownPosition();
        if (lastPos != null && !isCancelled() && !settled) {
          finishSuccess(_toFix(lastPos));
          return;
        }
      } catch (_) {}

      if (!settled && !isCancelled()) {
        settled = true;
        onError(VisitLocationState.error, fallbackReason);
      }
    }

    onCancelHandle?.call(() {
      settled = true;
      clearResources();
    });

    hardTimer = Timer(maxFixTimeout, () {
      tryFallbackOrFail(
        'Unable to acquire GPS signal indoors. Move near a window and retry.',
      );
    });

    if (bestFix != null) {
      warmupTimer = Timer(warmupDuration, () {
        if (bestFix != null) finishSuccess(bestFix!);
      });
    }

    sub = _getPositionStream(settings).listen(
      (pos) {
        if (settled || isCancelled()) return;
        final fix = _toFix(pos);

        if (bestFix == null || fix.accuracyMeters <= bestFix!.accuracyMeters) {
          bestFix = fix;
          onReading(bestFix!);
        }

        if (bestFix!.accuracyMeters <= targetAccuracyMeters) {
          finishSuccess(bestFix!);
          return;
        }

        warmupTimer ??= Timer(warmupDuration, () {
          if (bestFix != null) finishSuccess(bestFix!);
        });
      },
      onError: (_) {
        tryFallbackOrFail(
          'GPS signal unavailable. Ensure Phone Location is ON and try again.',
        );
      },
      cancelOnError: false,
    );
  }

  /// Formats built-in Android `Geocoder` placemarks cleanly into:
  /// Flat / Door No, Road / Street, Sub-Locality, Locality, City, Pincode.
  static String formatPlacemarkAddress(List<Placemark> placemarks) {
    if (placemarks.isEmpty) return '';

    final p = placemarks.first;
    String? clean(String? raw) {
      final t = raw?.trim() ?? '';
      if (t.isEmpty || _plusCodePattern.hasMatch(t)) return null;
      return t;
    }

    final doorOrFlat = clean(p.subThoroughfare) ?? clean(p.name);
    final road =
        clean(p.thoroughfare) ??
        ((clean(p.street) != null && clean(p.street) != doorOrFlat)
            ? clean(p.street)
            : null);
    final subLocality = clean(p.subLocality);
    final city = clean(p.locality) ?? clean(p.subAdministrativeArea);
    final postalCode = clean(p.postalCode);

    final candidates = <String?>[
      doorOrFlat,
      road,
      subLocality,
      city,
      postalCode,
    ];

    final deduped = <String>[];
    final seen = <String>{};
    for (final raw in candidates) {
      if (raw == null) continue;
      final key = raw.toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        deduped.add(raw);
      }
    }
    return deduped.join(', ');
  }

  /// Resolves address using Android's free built-in `android.location.Geocoder` first (~150ms),
  /// falling back/enriching from backend `/complaints/reverse-geocode` (Google Geocoding API)
  /// when OS Geocoder is unavailable or coarse (< 3 segments).
  Future<String> reverseGeocode(double lat, double lng) async {
    String? nativeAddress;
    try {
      final placemarks = await _placemarkLookup(lat, lng);
      final formatted = formatPlacemarkAddress(placemarks);
      if (formatted.isNotEmpty) {
        nativeAddress = formatted;
        final partsCount = formatted.split(',').length;
        if (partsCount >= 3) {
          return formatted;
        }
      }
    } catch (_) {}

    try {
      final dio = await _dioProvider();
      final res = await dio.get(
        '/complaints/reverse-geocode',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      if (res.data is Map) {
        final backendAddr = res.data['address']?.toString().trim();
        if (backendAddr != null && backendAddr.isNotEmpty) {
          if (nativeAddress == null ||
              backendAddr.split(',').length > nativeAddress.split(',').length) {
            return backendAddr;
          }
        }
      }
    } catch (_) {}

    return nativeAddress ??
        '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  VisitGpsFix _toFix(Position pos) {
    final accuracy = pos.accuracy.isFinite ? pos.accuracy.round() : 999;
    return VisitGpsFix(
      lat: double.parse(pos.latitude.toStringAsFixed(6)),
      lng: double.parse(pos.longitude.toStringAsFixed(6)),
      accuracyMeters: accuracy,
      isApproximate: accuracy > approximateAccuracyThresholdMeters,
    );
  }
}

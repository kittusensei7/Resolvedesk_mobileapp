// Domain models and state enums for mobile field visit verification (Sprint C).

enum VisitVerificationMode { checkin, resolution }

enum VisitLocationState {
  idle,
  acquiring,
  locked,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

enum VisitCameraState {
  idle,
  capturing,
  captured,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class VisitPolicy {
  const VisitPolicy({
    this.geofenceRadiusMeters = 500,
    this.strictGpsRequired = true,
  });

  final int geofenceRadiusMeters;
  final bool strictGpsRequired;

  factory VisitPolicy.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VisitPolicy();
    return VisitPolicy(
      geofenceRadiusMeters:
          int.tryParse(json['geofenceRadiusMeters']?.toString() ?? '') ?? 500,
      strictGpsRequired: json['strictGpsRequired'] is bool
          ? json['strictGpsRequired'] as bool
          : true,
    );
  }
}

class VisitGpsFix {
  const VisitGpsFix({
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    this.address = '',
    this.isApproximate = false,
  });

  final double lat;
  final double lng;
  final int accuracyMeters;
  final String address;
  final bool isApproximate;

  VisitGpsFix copyWith({
    double? lat,
    double? lng,
    int? accuracyMeters,
    String? address,
    bool? isApproximate,
  }) {
    return VisitGpsFix(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      address: address ?? this.address,
      isApproximate: isApproximate ?? this.isApproximate,
    );
  }

  String get coordinatesLabel => '$lat, $lng';
}

class VisitVerificationResult {
  const VisitVerificationResult({
    required this.supportType,
    this.photoBase64,
    this.lat,
    this.lng,
    this.address,
    this.accuracyMeters,
    this.alreadySubmittedCheckin = false,
  });

  final String supportType; // 'On-Site' | 'Remote' | 'In-Office'
  final String? photoBase64;
  final double? lat;
  final double? lng;
  final String? address;
  final int? accuracyMeters;
  final bool alreadySubmittedCheckin;
}

/// Derives consistent audit pill text matching shared/visitAuditLabels.js on Web.
String formatVisitGeofenceLabel(Map<String, dynamic>? visit) {
  if (visit == null) return 'No Visit Logged';
  final flagged =
      visit['is_location_flagged'] == true || visit['is_location_flagged'] == 1;
  if (!flagged) return 'Verified (On-Site)';

  final reason = visit['location_flag_reason']?.toString() ?? '';
  if (RegExp(r'missing\s+gps', caseSensitive: false).hasMatch(reason)) {
    return 'Flagged (Missing GPS)';
  }
  final match = RegExp(
    r'(?:exceeds|over|>)\s*(\d+)\s*m',
    caseSensitive: false,
  ).firstMatch(reason);
  if (match != null) {
    return 'Flagged (> ${match.group(1)}m)';
  }
  return 'Flagged (Location)';
}

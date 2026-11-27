import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/visit_verification_models.dart';
import 'visit_location_service.dart';
import 'visit_photo_service.dart';

/// MVVM ViewModel managing Sprint C verification modal state:
/// sequential GPS + Camera permissions, Work Mode selection, reverse geocoding,
/// and check-in API submission.
class VisitVerificationController extends ChangeNotifier {
  VisitVerificationController({
    required this.complaintId,
    required this.mode,
    VisitLocationService? locationService,
    VisitPhotoService? photoService,
    Future<Dio> Function()? dioProvider,
  }) : _locationService = locationService ?? VisitLocationService(),
       _photoService = photoService ?? VisitPhotoService(),
       _dioProvider = dioProvider ?? ApiConfig.getDio;

  final int complaintId;
  final VisitVerificationMode mode;
  final VisitLocationService _locationService;
  final VisitPhotoService _photoService;
  final Future<Dio> Function() _dioProvider;

  bool _disposed = false;
  void Function()? _cancelGpsStream;
  String? _lastGeocodeKey;

  String _supportType = 'On-Site';
  String get supportType => _supportType;

  VisitPolicy _policy = const VisitPolicy();
  VisitPolicy get policy => _policy;

  VisitLocationState _locationState = VisitLocationState.idle;
  VisitLocationState get locationState => _locationState;

  bool _isRefiningGps = false;
  bool get isRefiningGps => _isRefiningGps;

  VisitGpsFix? _gpsFix;
  VisitGpsFix? get gpsFix => _gpsFix;

  String _locationMessage = '';
  String get locationMessage => _locationMessage;

  VisitCameraState _cameraState = VisitCameraState.idle;
  VisitCameraState get cameraState => _cameraState;

  String? _photoBase64;
  String? get photoBase64 => _photoBase64;

  Uint8List? _photoPreviewBytes;
  Uint8List? get photoPreviewBytes => _photoPreviewBytes;

  String _cameraMessage = '';
  String get cameraMessage => _cameraMessage;

  bool _submitting = false;
  bool get submitting => _submitting;

  String? _submitError;
  String? get submitError => _submitError;

  bool get isOnSite => _supportType == 'On-Site';

  bool get hasPhoto => _photoBase64 != null && _photoBase64!.isNotEmpty;

  bool get hasGpsFix =>
      _locationState == VisitLocationState.locked && _gpsFix != null;

  bool get canConfirm => canSubmit;

  bool get canSubmit {
    if (_submitting || _cameraState == VisitCameraState.capturing) return false;
    if (!isOnSite) return true;
    if (!hasPhoto) return false;
    if (_policy.strictGpsRequired && !hasGpsFix) {
      return false;
    }
    return true;
  }

  /// Loads policy and begins GPS acquisition sequentially.
  Future<void> initialize() async {
    _policy = await _locationService.fetchVisitPolicy();
    if (_disposed) return;
    _safeNotify();
    await startLocationAcquisition();
  }

  void setSupportType(String nextType) {
    if (_supportType == nextType) return;
    _supportType = nextType;
    _submitError = null;
    if (nextType != 'On-Site') {
      _stopGps();
    } else if (_gpsFix == null && _locationState != VisitLocationState.acquiring) {
      startLocationAcquisition();
    }
    _safeNotify();
  }

  Future<void> startLocationAcquisition() async {
    if (_disposed || !isOnSite) return;
    _stopGps();
    _locationState = VisitLocationState.acquiring;
    _isRefiningGps = true;
    _locationMessage = '';
    _safeNotify();

    await _locationService.acquireBestPosition(
      isCancelled: () => _disposed || !isOnSite,
      onCancelHandle: (cancel) => _cancelGpsStream = cancel,
      onReading: (fix) {
        if (_disposed || !isOnSite) return;
        _gpsFix = fix.copyWith(address: _gpsFix?.address ?? '');
        _locationState = VisitLocationState.locked;
        _submitError = null;
        _safeNotify();
        _geocodeIfMoved(fix);
      },
      onFinal: (finalFix) {
        if (_disposed || !isOnSite) return;
        _gpsFix = finalFix.copyWith(address: _gpsFix?.address ?? '');
        _locationState = VisitLocationState.locked;
        _isRefiningGps = false;
        _submitError = null;
        _safeNotify();
        _geocodeIfMoved(finalFix);
      },
      onError: (state, msg) {
        if (_disposed || !isOnSite) return;
        _gpsFix = null;
        _locationState = state;
        _isRefiningGps = false;
        _locationMessage = msg;
        _safeNotify();
      },
    );
  }

  Future<void> _geocodeIfMoved(VisitGpsFix fix) async {
    final key = '${fix.lat.toStringAsFixed(4)},${fix.lng.toStringAsFixed(4)}';
    if (_lastGeocodeKey == key) return;
    _lastGeocodeKey = key;

    final resolved = await _locationService.reverseGeocode(fix.lat, fix.lng);
    if (_disposed || !isOnSite || _gpsFix == null) return;
    _gpsFix = _gpsFix!.copyWith(address: resolved);
    _safeNotify();
  }

  Future<void> openDeviceLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  Future<void> openAppPermissionSettings() async {
    await _locationService.openAppSettings();
  }

  Future<void> onAppResumed() => handleAppResumed();

  /// Auto-rechecks GPS when returning from Android Location / App Permissions Settings.
  Future<void> handleAppResumed() async {
    if (_disposed || !isOnSite) return;
    if (_locationState == VisitLocationState.serviceDisabled ||
        _locationState == VisitLocationState.permissionDenied ||
        _locationState == VisitLocationState.permissionDeniedForever ||
        _locationState == VisitLocationState.error) {
      await startLocationAcquisition();
    }
    if (_cameraState == VisitCameraState.permissionDenied ||
        _cameraState == VisitCameraState.permissionDeniedForever) {
      _cameraState = VisitCameraState.idle;
      _cameraMessage = '';
      _safeNotify();
    }
  }

  Future<void> capturePhoto({Future<Uint8List?> Function()? captureBytes}) =>
      captureCameraPhoto(captureBytes: captureBytes);

  Future<void> captureCameraPhoto({
    Future<Uint8List?> Function()? captureBytes,
  }) async {
    if (_disposed || _cameraState == VisitCameraState.capturing) return;
    _cameraState = VisitCameraState.capturing;
    _cameraMessage = '';
    _submitError = null;
    _safeNotify();

    final outcome = await _photoService.captureAndWatermark(
      lat: _gpsFix?.lat,
      lng: _gpsFix?.lng,
      captureBytes: captureBytes,
    );
    if (_disposed) return;

    if (outcome.state == VisitCameraState.captured) {
      _photoBase64 = outcome.base64DataUrl;
      _photoPreviewBytes = outcome.previewBytes;
      _cameraState = VisitCameraState.captured;
      _cameraMessage = '';
    } else if (outcome.state == VisitCameraState.idle) {
      _cameraState = _photoBase64 != null
          ? VisitCameraState.captured
          : VisitCameraState.idle;
    } else {
      _cameraState = outcome.state;
      _cameraMessage = outcome.message ?? 'Unable to open camera.';
    }
    _safeNotify();
  }

  Future<void> openCameraSettings() async {
    await _photoService.openAppSettings();
  }

  /// Validates requirements, submits check-in (when mode == checkin & On-Site),
  /// or returns verified payload for resolution/remote handoff.
  Future<VisitVerificationResult?> submit() async {
    if (_submitting) return null;

    if (isOnSite && (_photoBase64 == null || _photoBase64!.isEmpty)) {
      _submitError = 'Please capture a live camera photo before confirming.';
      _safeNotify();
      return null;
    }

    if (isOnSite &&
        _policy.strictGpsRequired &&
        (_locationState != VisitLocationState.locked || _gpsFix == null)) {
      _submitError =
          'GPS location is required for On-Site verification. Enable Location and retry.';
      _safeNotify();
      return null;
    }

    _submitError = null;
    _submitting = true;
    _safeNotify();

    try {
      final fix = _gpsFix;
      final addressText = (fix != null && fix.address.isNotEmpty)
          ? fix.address
          : fix?.coordinatesLabel;

      if (mode == VisitVerificationMode.checkin && isOnSite) {
        final dio = await _dioProvider();
        await dio.post(
          '/complaints/$complaintId/checkin',
          data: {
            'checkinPhoto': _photoBase64,
            'checkinLat': fix?.lat,
            'checkinLng': fix?.lng,
            'checkinAddress': addressText,
          },
        );
        return VisitVerificationResult(
          supportType: _supportType,
          photoBase64: _photoBase64,
          lat: fix?.lat,
          lng: fix?.lng,
          address: addressText,
          accuracyMeters: fix?.accuracyMeters,
          alreadySubmittedCheckin: true,
        );
      }

      return VisitVerificationResult(
        supportType: _supportType,
        photoBase64: isOnSite ? _photoBase64 : null,
        lat: isOnSite ? fix?.lat : null,
        lng: isOnSite ? fix?.lng : null,
        address: isOnSite ? addressText : null,
        accuracyMeters: isOnSite ? fix?.accuracyMeters : null,
        alreadySubmittedCheckin: false,
      );
    } on DioException catch (err) {
      final msg = err.response?.data is Map
          ? err.response?.data['message']?.toString()
          : null;
      _submitError = msg ?? 'Verification request failed. Please try again.';
      return null;
    } catch (_) {
      _submitError = 'Unexpected error during verification. Please retry.';
      return null;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }

  void clearSubmitError() {
    _submitError = null;
    _safeNotify();
  }

  void _stopGps() {
    _cancelGpsStream?.call();
    _cancelGpsStream = null;
    _isRefiningGps = false;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopGps();
    super.dispose();
  }
}

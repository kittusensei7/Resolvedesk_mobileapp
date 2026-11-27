import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../models/visit_verification_models.dart';

class CameraCaptureOutcome {
  const CameraCaptureOutcome._({
    required this.state,
    this.base64DataUrl,
    this.previewBytes,
    this.message,
  });

  factory CameraCaptureOutcome.captured({
    required String base64DataUrl,
    required Uint8List previewBytes,
  }) => CameraCaptureOutcome._(
    state: VisitCameraState.captured,
    base64DataUrl: base64DataUrl,
    previewBytes: previewBytes,
  );

  factory CameraCaptureOutcome.cancelled() =>
      const CameraCaptureOutcome._(state: VisitCameraState.idle);

  factory CameraCaptureOutcome.denied({
    required bool permanent,
    required String message,
  }) => CameraCaptureOutcome._(
    state: permanent
        ? VisitCameraState.permissionDeniedForever
        : VisitCameraState.permissionDenied,
    message: message,
  );

  factory CameraCaptureOutcome.error(String message) =>
      CameraCaptureOutcome._(state: VisitCameraState.error, message: message);

  final VisitCameraState state;
  final String? base64DataUrl;
  final Uint8List? previewBytes;
  final String? message;
}

/// Camera-only visit proof capture & watermarking service (gallery selection disabled).
/// Supports in-app camera capture (`captureBytes`) with `ImagePicker` fallback + lost-data check.
class VisitPhotoService {
  VisitPhotoService({
    ImagePicker? picker,
    Future<ph.PermissionStatus> Function()? checkCameraPermission,
    Future<ph.PermissionStatus> Function()? requestCameraPermission,
    Future<bool> Function()? openSettings,
  }) : _picker = picker ?? ImagePicker(),
       _checkCameraPermission =
           checkCameraPermission ?? (() => ph.Permission.camera.status),
       _requestCameraPermission =
           requestCameraPermission ?? (() => ph.Permission.camera.request()),
       _openSettings = openSettings ?? ph.openAppSettings;

  static const int maxWatermarkedDimension = 768;

  final ImagePicker _picker;
  final Future<ph.PermissionStatus> Function() _checkCameraPermission;
  final Future<ph.PermissionStatus> Function() _requestCameraPermission;
  final Future<bool> Function() _openSettings;

  Future<bool> openAppSettings() => _openSettings();

  /// Checks & requests runtime Camera permission, captures via `captureBytes` (in-app camera)
  /// or fallback rear `ImagePicker`, watermarks the image, and returns base64 + bytes.
  Future<CameraCaptureOutcome> captureAndWatermark({
    double? lat,
    double? lng,
    Future<Uint8List?> Function()? captureBytes,
  }) async {
    var status = await _checkCameraPermission();
    if (!status.isGranted && !status.isLimited) {
      status = await _requestCameraPermission();
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraCaptureOutcome.denied(
        permanent: true,
        message:
            'Camera permission is permanently denied. Open App Settings to allow Camera access.',
      );
    }
    if (!status.isGranted && !status.isLimited) {
      return CameraCaptureOutcome.denied(
        permanent: false,
        message:
            'Camera permission is required to capture site proof. Tap Open Camera to allow.',
      );
    }

    try {
      Uint8List? rawBytes;
      if (captureBytes != null) {
        rawBytes = await captureBytes();
      } else {
        final XFile? captured = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 82,
        );
        if (captured != null) {
          rawBytes = await captured.readAsBytes();
        } else {
          final lost = await _picker.retrieveLostData();
          if (!lost.isEmpty && lost.file != null) {
            rawBytes = await lost.file!.readAsBytes();
          }
        }
      }

      if (rawBytes == null || rawBytes.isEmpty) {
        return CameraCaptureOutcome.cancelled();
      }

      final watermarkedBytes = await burnVerificationWatermark(
        rawBytes,
        lat: lat,
        lng: lng,
      );

      final dataUrl = 'data:image/png;base64,${base64Encode(watermarkedBytes)}';
      return CameraCaptureOutcome.captured(
        base64DataUrl: dataUrl,
        previewBytes: watermarkedBytes,
      );
    } catch (err) {
      return CameraCaptureOutcome.error(
        'Failed to capture camera photo: $err',
      );
    }
  }

  /// Pure watermark formatter matching Web's "ResolveDesk Verified | ... | Lat: ..., Lng: ...".
  static String buildWatermarkText({double? lat, double? lng, DateTime? now}) {
    final dt = now ?? DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dd = dt.day.toString().padLeft(2, '0');
    final mon = months[dt.month - 1];
    final yyyy = dt.year;
    final hr12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'pm' : 'am';
    final loc = (lat != null && lng != null)
        ? 'Lat: $lat, Lng: $lng'
        : 'GPS: Acquired';
    return 'ResolveDesk Verified | $dd $mon $yyyy $hr12:$mm $ampm | $loc';
  }

  /// Renders scaled frame + dark corporate watermark footer using Flutter's `dart:ui` Canvas.
  static Future<Uint8List> burnVerificationWatermark(
    Uint8List sourceBytes, {
    double? lat,
    double? lng,
  }) async {
    final codec = await ui.instantiateImageCodec(sourceBytes);
    final frame = await codec.getNextFrame();
    final ui.Image srcImg = frame.image;

    int width = srcImg.width;
    int height = srcImg.height;
    if (width >= height && width > maxWatermarkedDimension) {
      height = ((height * maxWatermarkedDimension) / width).round().clamp(
        1,
        maxWatermarkedDimension,
      );
      width = maxWatermarkedDimension;
    } else if (height > maxWatermarkedDimension) {
      width = ((width * maxWatermarkedDimension) / height).round().clamp(
        1,
        maxWatermarkedDimension,
      );
      height = maxWatermarkedDimension;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    canvas.drawImageRect(
      srcImg,
      Rect.fromLTWH(0, 0, srcImg.width.toDouble(), srcImg.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );

    final double barHeight = (height * 0.055).clamp(28.0, 44.0);
    canvas.drawRect(
      Rect.fromLTWH(0, height - barHeight, width.toDouble(), barHeight),
      Paint()..color = const Color(0xC70F172A),
    );

    final textSpan = TextSpan(
      text: buildWatermarkText(lat: lat, lng: lng),
      style: TextStyle(
        color: Colors.white,
        fontSize: (barHeight * 0.40).clamp(10.0, 14.0),
        fontWeight: FontWeight.w600,
      ),
    );
    final painter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: (width - 20).toDouble().clamp(60.0, 2000.0));

    painter.paint(
      canvas,
      Offset(10, height - barHeight + (barHeight - painter.height) / 2),
    );

    final picture = recorder.endRecording();
    final ui.Image outputImg = await picture.toImage(width, height);
    final ByteData? byteData = await outputImg.toByteData(
      format: ui.ImageByteFormat.png,
    );

    srcImg.dispose();
    outputImg.dispose();

    if (byteData == null) {
      return sourceBytes;
    }
    return byteData.buffer.asUint8List();
  }
}

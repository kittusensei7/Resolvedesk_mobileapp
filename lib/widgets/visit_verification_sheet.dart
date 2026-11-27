import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/visit_verification_models.dart';
import '../services/visit_verification_controller.dart';
import 'in_app_camera_page.dart';

/// Executive-grade Modal Bottom Sheet for On-Site Visit Verification (Check-In & Resolution).
/// Uses native Fused GPS, sequential Android permission recovery prompts, and camera-only capture.
class VisitVerificationSheet extends StatefulWidget {
  const VisitVerificationSheet({
    super.key,
    required this.complaintId,
    required this.mode,
    required this.complaintSummary,
    this.category,
    this.issueType,
    this.description,
    this.controller,
  });

  final int complaintId;
  final VisitVerificationMode mode;
  final String complaintSummary;
  final String? category;
  final String? issueType;
  final String? description;
  final VisitVerificationController? controller;

  static Future<VisitVerificationResult?> show(
    BuildContext context, {
    required int complaintId,
    required VisitVerificationMode mode,
    required String complaintSummary,
    String? category,
    String? issueType,
    String? description,
    VisitVerificationController? controller,
  }) {
    return showModalBottomSheet<VisitVerificationResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => VisitVerificationSheet(
        complaintId: complaintId,
        mode: mode,
        complaintSummary: complaintSummary,
        category: category,
        issueType: issueType,
        description: description,
        controller: controller,
      ),
    );
  }

  @override
  State<VisitVerificationSheet> createState() => _VisitVerificationSheetState();
}

class _VisitVerificationSheetState extends State<VisitVerificationSheet>
    with WidgetsBindingObserver {
  late final VisitVerificationController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        VisitVerificationController(
          complaintId: widget.complaintId,
          mode: widget.mode,
        );
    _controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  String _photoHint() {
    final isCheckin = widget.mode == VisitVerificationMode.checkin;
    final combined =
        '${widget.category ?? ''} ${widget.issueType ?? ''} ${widget.description ?? ''}'
            .toLowerCase();
    if (combined.contains('install') ||
        RegExp(r'\b(installation|commissioning|mounting)\b').hasMatch(combined)) {
      return isCheckin
          ? 'Capture mounting spot / site before installation'
          : 'Capture installed device mounted on wall / gate';
    }
    if ((widget.category ?? '').toLowerCase().contains('hardware')) {
      return isCheckin
          ? 'Capture photo of Machine & Serial Number plate'
          : 'Capture repaired Machine & Serial plate';
    }
    if ((widget.category ?? '').toLowerCase().contains('software')) {
      return isCheckin
          ? 'Capture photo of PC Monitor / Error Screen at customer desk'
          : 'Capture working Software screen at customer desk';
    }
    return 'Capture machine or customer premises photo';
  }

  Future<void> _openPinInMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _captureFromInAppCamera() async {
    await _controller.capturePhoto(
      captureBytes: () => InAppCameraPage.capture(context, hint: _photoHint()),
    );
  }

  void _openFullPhotoPreview(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 24,
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleConfirm() async {
    HapticFeedback.mediumImpact();
    final result = await _controller.submit();
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCheckin = widget.mode == VisitVerificationMode.checkin;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                    decoration: const BoxDecoration(
                      color: Color(0xfff8fafc),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Color(0xffe2e8f0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCheckin
                                    ? 'Verify On-Site Check-In'
                                    : 'Capture Resolution Proof',
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff0f172a),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.complaintSummary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xff475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Semantics(
                          label: 'Close verification sheet',
                          button: true,
                          child: IconButton(
                            onPressed: _controller.submitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Color(0xff64748b)),
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isCheckin) ...[
                            const Text(
                              'Work Mode',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _WorkModeSelector(
                              supportType: _controller.supportType,
                              onChanged: _controller.setSupportType,
                            ),
                            const SizedBox(height: 14),
                          ],

                          if (isCheckin && _controller.supportType != 'On-Site')
                            _RemoteSupportCard(
                              supportType: _controller.supportType,
                              onSelect: _controller.setSupportType,
                            )
                          else ...[
                            _buildLocationCard(),
                            const SizedBox(height: 16),
                            _buildCameraCard(isCheckin),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Footer + Inline Error + Confirm Button
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                    decoration: const BoxDecoration(
                      color: Color(0xfff8fafc),
                      border: Border(
                        top: BorderSide(color: Color(0xffe2e8f0)),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_controller.submitError != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xfffef2f2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xfffecaca),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 18,
                                  color: Color(0xffb91c1c),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _controller.submitError!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xff991b1b),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                onPressed: _controller.submitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: FilledButton(
                                onPressed: _controller.canConfirm
                                    ? _handleConfirm
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xff0f172a),
                                  minimumSize: const Size(0, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _controller.submitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _confirmButtonLabel(isCheckin),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _confirmButtonLabel(bool isCheckin) {
    if (_controller.supportType != 'On-Site') {
      return 'Start ${_controller.supportType} Work';
    }
    if (_controller.locationState == VisitLocationState.acquiring &&
        !_controller.hasGpsFix) {
      return 'Waiting for GPS...';
    }
    if (_controller.policy.strictGpsRequired && !_controller.hasGpsFix) {
      return 'Turn On GPS First';
    }
    if (!_controller.hasPhoto) {
      return 'Capture Photo First';
    }
    return isCheckin ? 'Confirm Check-In' : 'Confirm Resolution';
  }

  Widget _buildCameraCard(bool isCheckin) {
    final label = isCheckin
        ? 'Arrival Photo (Machine / Serial Plate / Site)'
        : 'Resolution Photo (Repaired Machine)';

    final camState = _controller.cameraState;
    final isDenied =
        camState == VisitCameraState.permissionDenied ||
        camState == VisitCameraState.permissionDeniedForever ||
        camState == VisitCameraState.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xff334155),
          ),
        ),
        const SizedBox(height: 8),
        if (_controller.photoPreviewBytes != null)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 180, maxHeight: 300),
            decoration: BoxDecoration(
              color: const Color(0xff0f172a),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffcbd5e1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () => _openFullPhotoPreview(_controller.photoPreviewBytes!),
                  child: Image.memory(
                    _controller.photoPreviewBytes!,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FilledButton.icon(
                    onPressed: camState == VisitCameraState.capturing
                        ? null
                        : _captureFromInAppCamera,
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text('Retake'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xCC0F172A),
                      minimumSize: const Size(48, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xB30F172A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_out_map, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Tap to view',
                            style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: camState == VisitCameraState.capturing
                ? null
                : _captureFromInAppCamera,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 132),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: isDenied
                    ? const Color(0xfffef2f2)
                    : const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDenied
                      ? const Color(0xfffca5a5)
                      : const Color(0xffcbd5e1),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (camState == VisitCameraState.capturing)
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 32,
                      color: isDenied
                          ? const Color(0xffb91c1c)
                          : const Color(0xff334155),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    camState == VisitCameraState.capturing
                        ? 'Processing & Watermarking...'
                        : 'Open Camera / Capture Photo',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDenied
                          ? const Color(0xff991b1b)
                          : const Color(0xff0f172a),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _controller.cameraMessage.isNotEmpty
                        ? _controller.cameraMessage
                        : _photoHint(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDenied
                          ? const Color(0xffb91c1c)
                          : const Color(0xff64748b),
                    ),
                  ),
                  if (camState == VisitCameraState.permissionDeniedForever) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _controller.openCameraSettings,
                      icon: const Icon(Icons.settings_outlined, size: 16),
                      label: const Text('Open App Settings'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        foregroundColor: const Color(0xff991b1b),
                        side: const BorderSide(color: Color(0xfffca5a5)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationCard() {
    final locState = _controller.locationState;
    final fix = _controller.gpsFix;
    final isLocked = locState == VisitLocationState.locked && fix != null;
    final isIssue =
        locState == VisitLocationState.serviceDisabled ||
        locState == VisitLocationState.permissionDenied ||
        locState == VisitLocationState.permissionDeniedForever ||
        locState == VisitLocationState.error;
    final isApprox = isLocked && fix.isApproximate;

    final Color bgColor = isIssue
        ? const Color(0xfffef2f2)
        : isApprox
        ? const Color(0xfffffbeb)
        : const Color(0xfff8fafc);

    final Color borderColor = isIssue
        ? const Color(0xfffecaca)
        : isApprox
        ? const Color(0xfffde68a)
        : const Color(0xffe2e8f0);

    final Color iconColor = isIssue
        ? const Color(0xffb91c1c)
        : isApprox
        ? const Color(0xffb45309)
        : isLocked
        ? const Color(0xff0f766e)
        : const Color(0xff475569);

    String heading = 'Acquiring Precise GPS...';
    if (isLocked) {
      heading = _controller.isRefiningGps
          ? 'GPS Acquired (Refining Lock...)'
          : isApprox
          ? 'Approximate Location Detected'
          : 'GPS Location Verified';
    } else if (locState == VisitLocationState.serviceDisabled) {
      heading = 'Phone Location (GPS) is Off';
    } else if (locState == VisitLocationState.permissionDeniedForever) {
      heading = 'Location Blocked in App Settings';
    } else if (locState == VisitLocationState.permissionDenied) {
      heading = 'Location Permission Required';
    } else if (locState == VisitLocationState.error) {
      heading = 'GPS Signal Unavailable';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.location_on_outlined, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        heading,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isIssue
                              ? const Color(0xff991b1b)
                              : isApprox
                              ? const Color(0xff92400e)
                              : const Color(0xff0f172a),
                        ),
                      ),
                    ),
                    if (locState == VisitLocationState.acquiring)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton(
                        onPressed: _controller.startLocationAcquisition,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          isIssue ? 'Retry' : 'Refresh GPS',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                if (isLocked) ...[
                  const SizedBox(height: 4),
                  Text(
                    fix.address.isNotEmpty
                        ? fix.address
                        : fix.coordinatesLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff334155),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Accuracy: ±${fix.accuracyMeters}m • ${fix.lat}, ${fix.lng}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xff64748b),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _openPinInMaps(fix.lat, fix.lng),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Text(
                            'Verify Pin ↗',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff2563eb),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isApprox && !_controller.isRefiningGps) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Coarse location (±${fix.accuracyMeters}m). Enable Precise Location in Android settings and tap Refresh GPS.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xffb45309),
                      ),
                    ),
                  ],
                ],
                if (isIssue && _controller.locationMessage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _controller.locationMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xffb91c1c),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (locState == VisitLocationState.serviceDisabled)
                    OutlinedButton.icon(
                      onPressed: _controller.openDeviceLocationSettings,
                      icon: const Icon(Icons.gps_fixed, size: 16),
                      label: const Text('Turn On GPS'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        foregroundColor: const Color(0xff991b1b),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xfffecaca)),
                      ),
                    )
                  else if (locState == VisitLocationState.permissionDenied)
                    OutlinedButton.icon(
                      onPressed: _controller.startLocationAcquisition,
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('Allow Location'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        foregroundColor: const Color(0xff991b1b),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xfffecaca)),
                      ),
                    )
                  else if (locState ==
                      VisitLocationState.permissionDeniedForever)
                    OutlinedButton.icon(
                      onPressed: _controller.openAppPermissionSettings,
                      icon: const Icon(Icons.settings_outlined, size: 16),
                      label: const Text('Open App Settings'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        foregroundColor: const Color(0xff991b1b),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xfffecaca)),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkModeSelector extends StatelessWidget {
  const _WorkModeSelector({
    required this.supportType,
    required this.onChanged,
  });

  final String supportType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isOnSite = supportType == 'On-Site';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xfff1f5f9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'On-Site Visit',
              selected: isOnSite,
              onTap: () => onChanged('On-Site'),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentButton(
              label: 'Remote / In-Office',
              selected: !isOnSite,
              onTap: () => onChanged('Remote'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      elevation: selected ? 1 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xff0f172a)
                  : const Color(0xff64748b),
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoteSupportCard extends StatelessWidget {
  const _RemoteSupportCard({
    required this.supportType,
    required this.onSelect,
  });

  final String supportType;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xfff8fafc),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xffe2e8f0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioListTile<String>(
              value: 'Remote',
              groupValue: supportType,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Remote (AnyDesk / Call)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onChanged: (v) {
                if (v != null) onSelect(v);
              },
            ),
            RadioListTile<String>(
              value: 'In-Office',
              groupValue: supportType,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'In-Office (Workshop Repair)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onChanged: (v) {
                if (v != null) onSelect(v);
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'GPS location and site camera photos are not required for remote assistance or workshop repairs.',
              style: TextStyle(fontSize: 12, color: Color(0xff64748b)),
            ),
          ],
        ),
      ),
    );
  }
}

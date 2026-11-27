import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// In-app rear camera screen powered by `camera`.
/// Avoids leaving the Flutter Activity to external Android Camera apps,
/// preventing 1st-attempt Activity-result loss and low-memory reloads.
class InAppCameraPage extends StatefulWidget {
  const InAppCameraPage({
    super.key,
    required this.hint,
  });

  final String hint;

  /// Opens the in-app camera viewfinder and returns captured raw JPEG bytes (or null if cancelled).
  static Future<Uint8List?> capture(
    BuildContext context, {
    required String hint,
  }) {
    return Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => InAppCameraPage(hint: hint),
      ),
    );
  }

  @override
  State<InAppCameraPage> createState() => _InAppCameraPageState();
}

class _InAppCameraPageState extends State<InAppCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;
  FlashMode _flashMode = FlashMode.auto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cam.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _initializing = false;
            _error = 'No camera detected on this device.';
          });
        }
        return;
      }

      final rear = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        rear,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      await controller.setFlashMode(_flashMode).catchError((_) {});

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (err) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Unable to open camera preview: $err';
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) return;
    final next = switch (_flashMode) {
      FlashMode.auto => FlashMode.torch,
      FlashMode.torch => FlashMode.off,
      _ => FlashMode.auto,
    };
    try {
      await cam.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } catch (_) {}
  }

  Future<void> _takePicture() async {
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized || _capturing) return;

    HapticFeedback.mediumImpact();
    setState(() => _capturing = true);
    try {
      final XFile file = await cam.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) {
        Navigator.of(context).pop(bytes);
      }
    } catch (err) {
      if (mounted) {
        setState(() => _capturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed, please retry: $err')),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_initializing)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_outlined,
                        size: 48,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _initCamera,
                        child: const Text('Retry Camera'),
                      ),
                    ],
                  ),
                ),
              )
            else if (cam != null && cam.value.isInitialized)
              Center(child: CameraPreview(cam)),

            // Top overlay controls
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    label: 'Close camera',
                    button: true,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 24,
                      child: IconButton(
                        onPressed: _capturing
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Toggle camera flash',
                    button: true,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 24,
                      child: IconButton(
                        onPressed: _toggleFlash,
                        icon: Icon(
                          _flashMode == FlashMode.torch
                              ? Icons.flash_on
                              : _flashMode == FlashMode.off
                              ? Icons.flash_off
                              : Icons.flash_auto,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom shutter controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                color: Colors.black54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: 'Take verification photo',
                      button: true,
                      child: GestureDetector(
                        onTap: (_initializing || _error != null || _capturing)
                            ? null
                            : _takePicture,
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            color: _capturing
                                ? Colors.white54
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                          child: Center(
                            child: _capturing
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Container(
                                    width: 56,
                                    height: 56,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

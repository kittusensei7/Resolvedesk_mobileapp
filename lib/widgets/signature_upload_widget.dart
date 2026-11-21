import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class SignatureUploadWidget extends StatefulWidget {
  const SignatureUploadWidget({
    super.key,
    required this.signatureBase64,
    required this.onSignatureChanged,
    this.readOnly = false,
    this.label,
  });

  final String signatureBase64;
  final ValueChanged<String> onSignatureChanged;
  final bool readOnly;
  final String? label;

  @override
  State<SignatureUploadWidget> createState() => _SignatureUploadWidgetState();
}

class _SignatureUploadWidgetState extends State<SignatureUploadWidget> {
  final ImagePicker _picker = ImagePicker();
  bool _processing = false;

  Future<void> _pickImage(ImageSource source) async {
    if (widget.readOnly) return;
    try {
      setState(() => _processing = true);
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final dataUrl = 'data:image/png;base64,$base64String';
        widget.onSignatureChanged(dataUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _openDrawSignaturePad() async {
    if (widget.readOnly) return;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SignaturePadDialog(),
    );
    if (result != null && result.isNotEmpty) {
      widget.onSignatureChanged(result);
    }
  }

  void _showPickOptions() {
    if (widget.readOnly) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label ?? 'Customer Signature',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how you want to add the ${widget.label ?? 'signature'}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Option 1: Draw Signature on Screen
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xfff0fdf4),
                  child: Icon(Icons.gesture, color: Color(0xff16a34a)),
                ),
                title: const Text('Draw on Screen (Finger / Stylus)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Customer signs directly on phone screen'),
                onTap: () {
                  Navigator.pop(context);
                  _openDrawSignaturePad();
                },
              ),
              const Divider(height: 1),

              // Option 2: Camera Capture
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xffe8efff),
                  child: Icon(Icons.camera_alt, color: Color(0xff1e3a8a)),
                ),
                title: const Text('Take Photo / Capture (Camera)'),
                subtitle: const Text('Use mobile camera to photograph paper signature'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const Divider(height: 1),

              // Option 3: Choose File
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xffe8efff),
                  child: Icon(Icons.photo_library, color: Color(0xff1e3a8a)),
                ),
                title: const Text('Choose Photo / Gallery'),
                subtitle: const Text('Select existing signature image file'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(String sig) {
    try {
      if (sig.startsWith('data:image')) {
        final commaIndex = sig.indexOf(',');
        if (commaIndex != -1) {
          final bytes = base64Decode(sig.substring(commaIndex + 1));
          return Image.memory(
            bytes,
            height: 90,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
          );
        }
      } else if (sig.startsWith('http://') || sig.startsWith('https://')) {
        return Image.network(
          sig,
          height: 90,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
        );
      }
    } catch (_) {}
    return const Text('Invalid signature data format', style: TextStyle(color: Colors.red, fontSize: 12));
  }

  @override
  Widget build(BuildContext context) {
    final hasSig = widget.signatureBase64.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.label ?? 'Customer Signature (Draw / Upload)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff374151),
                ),
              ),
            ),
            if (hasSig && !widget.readOnly)
              TextButton.icon(
                onPressed: () => widget.onSignatureChanged(''),
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (hasSig) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff22c55e), width: 1.5),
            ),
            child: Column(
              children: [
                _buildImagePreview(widget.signatureBase64),
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xff16a34a), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Signature Attached & Verified',
                      style: TextStyle(color: Color(0xff16a34a), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!widget.readOnly) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _showPickOptions,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Change Signature'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ] else ...[
          InkWell(
            onTap: widget.readOnly ? null : _showPickOptions,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffcbd5e1), style: BorderStyle.solid),
              ),
              child: _processing
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: const [
                        Icon(Icons.gesture, size: 36, color: Color(0xff1e3a8a)),
                        SizedBox(height: 8),
                        Text(
                          'Tap to Draw Signature on Screen or Upload Photo',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff1e3a8a)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Customer signs with finger or stylus',
                          style: TextStyle(fontSize: 11, color: Color(0xff64748b)),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

// Interactive Drawing Pad Modal Dialog
class _SignaturePadDialog extends StatefulWidget {
  const _SignaturePadDialog();

  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<Offset?> _points = [];

  Future<void> _saveSignature() async {
    if (_points.isEmpty) return;
    try {
      final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      final double width = box?.size.width ?? 350;
      final double height = box?.size.height ?? 180;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

      // Draw solid white background
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = Colors.white);

      final paint = Paint()
        ..color = const Color(0xff0f172a)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3.5;

      final path = Path();
      for (int i = 0; i < _points.length; i++) {
        final p = _points[i];
        if (p == null) continue;
        if (i == 0 || _points[i - 1] == null) {
          path.moveTo(p.dx, p.dy);
        } else {
          final pPrev = _points[i - 1]!;
          final midX = (pPrev.dx + p.dx) / 2;
          final midY = (pPrev.dy + p.dy) / 2;
          path.quadraticBezierTo(pPrev.dx, pPrev.dy, midX, midY);
        }
      }
      canvas.drawPath(path, paint);

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final base64Str = base64Encode(byteData.buffer.asUint8List());
        if (mounted) Navigator.pop(context, 'data:image/png;base64,$base64Str');
      }
    } catch (_) {}
  }

  void _addPoint(Offset globalPosition) {
    final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final localPos = box.globalToLocal(globalPosition);
      if (localPos.dx >= 0 && localPos.dx <= box.size.width && localPos.dy >= 0 && localPos.dy <= box.size.height) {
        setState(() => _points.add(localPos));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gesture, color: Color(0xff16a34a)),
                    SizedBox(width: 8),
                    Text('Draw Signature on Screen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Customer please sign below inside the box using your finger or stylus:',
              style: TextStyle(fontSize: 11.5, color: Color(0xff64748b)),
            ),
            const SizedBox(height: 12),
            Container(
              key: _canvasKey,
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xff1e3a8a), width: 2),
              ),
              child: GestureDetector(
                onPanStart: (details) => _addPoint(details.globalPosition),
                onPanUpdate: (details) => _addPoint(details.globalPosition),
                onPanEnd: (_) => setState(() => _points.add(null)),
                child: CustomPaint(
                  painter: _SignaturePainter(_points),
                  size: Size.infinite,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _points.clear());
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Clear Pad'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _points.isNotEmpty
                      ? () {
                          HapticFeedback.mediumImpact();
                          _saveSignature();
                        }
                      : null,
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Save Signature'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff16a34a),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xff0f172a)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.5;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      if (p == null) continue;
      if (i == 0 || points[i - 1] == null) {
        path.moveTo(p.dx, p.dy);
      } else {
        final pPrev = points[i - 1]!;
        final midX = (pPrev.dx + p.dx) / 2;
        final midY = (pPrev.dy + p.dy) / 2;
        path.quadraticBezierTo(pPrev.dx, pPrev.dy, midX, midY);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

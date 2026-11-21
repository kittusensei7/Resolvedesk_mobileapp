import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../pages/create_installation_report_page.dart';
import '../services/pdf_report_service.dart';

class InstallationReportPreviewDialog extends StatelessWidget {
  const InstallationReportPreviewDialog({super.key, required this.report});

  final Map<String, dynamic> report;

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '';
    final str = value.toString().trim();
    try {
      final dt = DateTime.parse(str.contains('T') ? str : '${str}T00:00:00');
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      return '$day-$month-$year';
    } catch (_) {
      return str.split('T').first;
    }
  }

  Widget _buildSignatureWidget(dynamic value) {
    if (value == null) return const SizedBox(height: 55);
    final str = value.toString().trim();
    if (str.isEmpty) return const SizedBox(height: 55);

    try {
      if (str.startsWith('http://') || str.startsWith('https://')) {
        return Image.network(
          str,
          height: 55,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox(height: 55),
        );
      }

      String base64Str = str;
      if (base64Str.contains(',')) {
        base64Str = base64Str.split(',').last;
      }
      base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(base64Str);
      if (bytes.isNotEmpty) {
        return Image.memory(
          bytes,
          height: 55,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox(height: 55),
        );
      }
    } catch (_) {}
    return const SizedBox(height: 55);
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      color: const Color(0xfff8fafc),
      alignment: Alignment.center,
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff0f172a)),
      ),
    );
  }

  Widget _gridRow(String label, Widget contentWidget, {double minHeight = 0}) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffcbd5e1), width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 190,
            constraints: minHeight > 0 ? BoxConstraints(minHeight: minHeight) : const BoxConstraints(),
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xfff8fafc),
              border: Border(right: BorderSide(color: Color(0xffcbd5e1), width: 0.8)),
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff0f172a)),
            ),
          ),
          Expanded(
            child: Container(
              constraints: minHeight > 0 ? BoxConstraints(minHeight: minHeight) : const BoxConstraints(),
              padding: const EdgeInsets.all(10),
              child: contentWidget,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridTextRow(String label, String value, {double minHeight = 0}) {
    return _gridRow(
      label,
      Text(
        value.isEmpty ? '—' : value,
        style: const TextStyle(fontSize: 12, color: Color(0xff0f172a)),
      ),
      minHeight: minHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pre-cache A4 PDF bytes in the background so "Share WhatsApp" & "Print" render in <50ms
    PdfReportService.generateInstallationReportPdf(report).ignore();

    final customerAddress = report['customer_name_address']?.toString() ?? '';
    final companyFirstLine = customerAddress.split('\n').first.trim();
    final parsedContacts = PdfReportService.parseContacts(report['contact_person']?.toString());

    final productName = report['product_name']?.toString() ?? '';
    final installationCompleted = report['installation_completed']?.toString() ?? '';
    final installationDate = _formatDate(report['installation_date']);
    final suggestions = report['suggestions']?.toString() ?? '';
    final installerName = report['installer_name']?.toString() ?? '';
    final status = report['status']?.toString() ?? 'Completed';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xfff8fafc),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modern Top Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xffeff6ff),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.build_circle_outlined, color: Color(0xff1d4ed8), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Installation Report',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xff0f172a)),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xfff1f5f9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Official A4 Layout', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xff334155))),
                            ),
                            if (companyFirstLine.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 150),
                                child: Text(
                                  '• $companyFirstLine',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Color(0xff64748b), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xff64748b)),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xffe2e8f0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // A4 Paper Document Sheet (Modern Paper Card Elevation)
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xffcbd5e1), width: 1.0),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Color(0x120f172a), blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Paramount Logo Top Right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Image.asset(
                            'assets/images/paramount_logo.png',
                            height: 48,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Text(
                              'PARAMOUNT',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff1e3a8a)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Center Title
                      const Center(
                        child: Text(
                          'INSTALLATION REPORT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2-Column Form Grid Table matching Image 2
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xff94a3b8)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Column(
                          children: [
                            // Company Particulars
                            _sectionHeader('Company Particulars'),
                            const Divider(height: 1, color: Color(0xffcbd5e1)),
                            _gridTextRow('Company Name & Address', customerAddress, minHeight: 50),

                            // Contact Details
                            _gridRow(
                              'Contact Details',
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...parsedContacts.map((c) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Contact Person:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff0f172a))),
                                          Text(c['name']?.isNotEmpty == true ? c['name']! : '—', style: const TextStyle(fontSize: 12)),
                                          if (c['phone']?.isNotEmpty == true) ...[
                                            const SizedBox(height: 2),
                                            const Text('Telephone:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff0f172a))),
                                            Text(c['phone']!, style: const TextStyle(fontSize: 12)),
                                          ],
                                          if (c['email']?.isNotEmpty == true) ...[
                                            const SizedBox(height: 2),
                                            const Text('E-mail:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff0f172a))),
                                            Text(c['email']!, style: const TextStyle(fontSize: 12)),
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),

                            // Product Particulars
                            _sectionHeader('Product Particulars'),
                            const Divider(height: 1, color: Color(0xffcbd5e1)),
                            _gridTextRow('Product Name', productName),
                            _gridTextRow('INSTALLATION COMPLETED', installationCompleted, minHeight: 45),

                            // Installation Particulars
                            _sectionHeader('Installation Particulars'),
                            const Divider(height: 1, color: Color(0xffcbd5e1)),
                            _gridTextRow('Installation Date', installationDate),
                            _gridTextRow('Suggestions', suggestions, minHeight: 35),
                            _gridTextRow('Installer Name', installerName),
                            _gridRow(
                              "Installer's Signature",
                              const SizedBox(height: 45),
                            ),
                          ],
                        ),
                      ),

                      // Acknowledgment Clause Row
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Color(0xff94a3b8)),
                            right: BorderSide(color: Color(0xff94a3b8)),
                            bottom: BorderSide(color: Color(0xff94a3b8)),
                          ),
                        ),
                        child: const Text(
                          'This is to acknowledge that the above mentioned Hardware or Software are installed at our locations and the same are in working at our satisfaction.',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xff334155)),
                        ),
                      ),

                      // Customer Signature & Status Box
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Color(0xff94a3b8)),
                            right: BorderSide(color: Color(0xff94a3b8)),
                            bottom: BorderSide(color: Color(0xff94a3b8)),
                          ),
                        ),
                        child: Column(
                          children: [
                            _gridRow(
                              "Customer's Signature with Seal",
                              _buildSignatureWidget(report['customer_signature'] ?? report['customerSignature']),
                            ),
                            _gridRow(
                              'Status',
                              Text(
                                status.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff16a34a)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Company Footer
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Paramount Office Systems Pvt Ltd', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff1e3a8a))),
                                SizedBox(height: 2),
                                Text(
                                  '28-21-1/F5, First Floor,\nClassic Complex, Prakasaraopeta,\nDabagardens, Visakhapatnam - 530 020',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xff475569), height: 1.3),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 60, color: const Color(0xffcbd5e1)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Phone: 0891-2705220, 6665220', style: TextStyle(fontSize: 10.5, color: Color(0xff475569))),
                                Text('Mobile: 98851 90883, 98851 90884', style: TextStyle(fontSize: 10.5, color: Color(0xff475569))),
                                Text('email: info@paramountindia.co.in', style: TextStyle(fontSize: 10.5, color: Color(0xff475569))),
                                Text('web: www.paramountindia.co.in', style: TextStyle(fontSize: 10.5, color: Color(0xff475569))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),
            // Harmonized 2-Tier Mobile Action Bar (Never wraps or breaks)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Secondary Actions (50 / 50 Equal Split)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateInstallationReportPage(editingReport: report),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xff1e3a8a)),
                        label: const Text(
                          'Edit Report',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff1e3a8a),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xffcbd5e1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          PdfReportService.shareInstallationReportPdf(report);
                        },
                        icon: const Icon(Icons.share, size: 16, color: Color(0xff15803d)),
                        label: const Text(
                          'Share WhatsApp',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff15803d),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: const Color(0xfff0fdf4),
                          side: const BorderSide(color: Color(0xffbbf7d0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 2: 100% Full Width Primary Action
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      PdfReportService.printOrDownloadInstallationReportPdf(report);
                    },
                    icon: const Icon(Icons.print, size: 17),
                    label: const Text(
                      'Print / Download Official A4',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff1e3a8a),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                      elevation: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 220.ms).scale(begin: const Offset(0.97, 0.97), duration: 220.ms, curve: Curves.easeOutCubic),
    );
  }
}

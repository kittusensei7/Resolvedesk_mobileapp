import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../pages/create_service_report_page.dart';
import '../services/pdf_report_service.dart';

class ServiceReportPreviewDialog extends StatelessWidget {
  const ServiceReportPreviewDialog({super.key, required this.report});

  final Map<String, dynamic> report;

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '';
    final str = value.toString().trim();
    try {
      final dt = DateTime.parse(str.contains('T') ? str : '${str}T00:00:00');
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      return '$day/$month/$year';
    } catch (_) {
      return str.split('T').first;
    }
  }

  Widget _keyValueRow(String label, dynamic value, {double labelWidth = 145}) {
    final valStr = value?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(
            width: 16,
            child: Text(':', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(
              valStr,
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureImage(String? sig) {
    if (sig == null || sig.trim().isEmpty) {
      return const SizedBox(height: 38);
    }
    try {
      final cleanSig = sig.trim();
      if (cleanSig.startsWith('data:image')) {
        final commaIndex = cleanSig.indexOf(',');
        if (commaIndex != -1) {
          final bytes = base64Decode(cleanSig.substring(commaIndex + 1));
          return Image.memory(bytes, height: 42, fit: BoxFit.contain);
        }
      } else if (cleanSig.startsWith('http://') || cleanSig.startsWith('https://')) {
        return Image.network(cleanSig, height: 42, fit: BoxFit.contain);
      }
    } catch (_) {}
    return const SizedBox(height: 38);
  }

  @override
  Widget build(BuildContext context) {
    // Pre-cache A4 PDF bytes in the background so "Share WhatsApp" & "Print" render in <50ms
    PdfReportService.generateServiceReportPdf(report).ignore();

    final customerSig = report['customer_signature']?.toString() ??
        report['customerSignature']?.toString();
    final engineerSig = report['engineer_signature']?.toString() ??
        report['engineerSignature']?.toString();

    final engineerName = report['service_engineer_name']?.toString() ?? '';
    final reportDate = _formatDate(report['report_date'] ?? report['created_at']);

    final product = report['product']?.toString() ?? '';
    final model = report['model']?.toString() ?? '';
    final productText = model.isEmpty ? product : '$product (Model: $model)';

    final complaint = report['complaint']?.toString() ?? report['description'] ?? '';
    final calledDate = _formatDate(report['called_date']);
    final respondedDate = _formatDate(report['responded_date']);

    final problemFound = report['problem_found']?.toString() ?? '';
    final actionTaken = report['action_taken']?.toString() ?? '';
    final spares = report['spares_details']?.toString() ?? report['spare_name']?.toString() ?? '';
    final oldSeries = report['spare_old_series']?.toString() ?? '';
    final newSeries = report['spare_new_series']?.toString() ?? '';

    final callType = report['call_type']?.toString() ?? '';
    final solvedThrough = report['solved_through']?.toString() ?? report['solvedThrough']?.toString() ?? 'On-Site';
    final chargeAmount = report['charge_amount']?.toString() ?? '';

    final complaintNumber = report['complaint_number']?.toString() ?? report['complaintNumber']?.toString() ?? '';
    final remarks = report['customer_remark']?.toString() ?? report['suggestions']?.toString() ?? report['latest_remark']?.toString() ?? '';

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
            // Modern Top Header Bar with Accent Icon & Badges
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
                      child: const Icon(Icons.description_outlined, color: Color(0xff1d4ed8), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Service Call Report',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xff0f172a)),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xffe2e8f0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Official A4 Layout', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xff334155))),
                            ),
                            if (complaintNumber.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text('• $complaintNumber', style: const TextStyle(fontSize: 11, color: Color(0xff64748b), fontWeight: FontWeight.w500)),
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
                      // Official Paramount Logo on Top Right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Image.asset(
                            'assets/images/paramount_logo.png',
                            height: 48,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Text(
                              'PARAMOUNT',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff1e3a8a),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Center Title: SERVICE CALL REPORT
                      const Center(
                        child: Text(
                          'SERVICE CALL REPORT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            decoration: TextDecoration.underline,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Header Info Bar (Engineer Name, Complaint No & Date)
                      Container(
                        padding: const EdgeInsets.only(bottom: 6),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 12.5, color: Colors.black),
                                  children: [
                                    const TextSpan(text: 'Name of Service Engineer: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(text: engineerName),
                                  ],
                                ),
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12.5, color: Colors.black),
                                children: [
                                  const TextSpan(text: 'Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: reportDate),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Fields Stacked Layout matching Web
                      if (complaintNumber.isNotEmpty)
                        _keyValueRow('Complaint No.', complaintNumber, labelWidth: 120),
                      _keyValueRow('Customer Name', report['customer_name'], labelWidth: 120),
                      _keyValueRow('Address', report['address'], labelWidth: 120),
                      _keyValueRow('Product', productText, labelWidth: 120),
                      _keyValueRow('Complaint', complaint, labelWidth: 120),
                      _keyValueRow('Called Date', calledDate, labelWidth: 120),
                      _keyValueRow('Responded Date', respondedDate, labelWidth: 120),
                      _keyValueRow('Problems Found', problemFound, labelWidth: 120),
                      _keyValueRow('Action taken', actionTaken, labelWidth: 120),
                      _keyValueRow('Spares if any', spares, labelWidth: 120),
                      _keyValueRow('Old Series No', oldSeries, labelWidth: 120),
                      _keyValueRow('New Series No', newSeries, labelWidth: 120),
                      _keyValueRow(
                        'Call Type',
                        callType + (['Charge Based', 'AMC'].contains(callType) && chargeAmount.isNotEmpty ? '   (Amount: ₹ $chargeAmount)' : ''),
                        labelWidth: 120,
                      ),
                      _keyValueRow('Solved Through', solvedThrough, labelWidth: 120),

                      // Remarks
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Remarks:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.only(left: 14),
                              child: Text(
                                remarks.isEmpty ? 'Enter remarks if any...' : remarks,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: remarks.isEmpty ? Colors.grey : Colors.black87,
                                  fontStyle: remarks.isEmpty ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            children: [
                              _buildSignatureImage(engineerSig),
                              const SizedBox(
                                width: 160,
                                child: Divider(thickness: 1, color: Color(0xff94a3b8)),
                              ),
                              const SizedBox(height: 4),
                              const Text('Service Engineer Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          Column(
                            children: [
                              _buildSignatureImage(customerSig),
                              const SizedBox(
                                width: 160,
                                child: Divider(thickness: 1, color: Color(0xff94a3b8)),
                              ),
                              const SizedBox(height: 4),
                              const Text('Customer Signature & Seal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),
                      const Divider(height: 1, color: Color(0xffcbd5e1)),
                      const SizedBox(height: 10),

                      // Footer Company Particulars & Contacts
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Paramount Office Systems Pvt Ltd',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff1e3a8a)),
                                ),
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

                          // Right Column
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
                              builder: (_) => CreateServiceReportPage(existingReport: report),
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
                          PdfReportService.shareReportPdf(report);
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
                      PdfReportService.printOrDownloadReportPdf(report);
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

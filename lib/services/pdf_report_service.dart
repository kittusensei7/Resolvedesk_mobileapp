import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class _ServiceReportDensity {
  final double fontSize;
  final double labelFontSize;
  final double titleSize;
  final double logoHeight;
  final double headerBottomPadding;
  final double headerMarginBottom;
  final double rowPaddingBottom;
  final double labelWidth;
  final double signatureBoxHeight;
  final double footerFontSize;
  final double footerAddressFontSize;
  final double pageMarginH;
  final double pageMarginV;

  const _ServiceReportDensity({
    required this.fontSize,
    required this.labelFontSize,
    required this.titleSize,
    required this.logoHeight,
    required this.headerBottomPadding,
    required this.headerMarginBottom,
    required this.rowPaddingBottom,
    required this.labelWidth,
    required this.signatureBoxHeight,
    required this.footerFontSize,
    required this.footerAddressFontSize,
    required this.pageMarginH,
    required this.pageMarginV,
  });

  factory _ServiceReportDensity.compute({
    required int estimatedLines,
    required int textLen,
  }) {
    if (estimatedLines <= 18) {
      // Light report: comfortable padding, generous fonts
      return const _ServiceReportDensity(
        fontSize: 11.0,
        labelFontSize: 11.0,
        titleSize: 16.5,
        logoHeight: 46,
        headerBottomPadding: 6,
        headerMarginBottom: 12,
        rowPaddingBottom: 7.0,
        labelWidth: 140,
        signatureBoxHeight: 38,
        footerFontSize: 9.5,
        footerAddressFontSize: 8.8,
        pageMarginH: 28,
        pageMarginV: 22,
      );
    } else if (estimatedLines <= 26) {
      // Medium report
      return const _ServiceReportDensity(
        fontSize: 10.5,
        labelFontSize: 10.5,
        titleSize: 16.0,
        logoHeight: 44,
        headerBottomPadding: 5.5,
        headerMarginBottom: 10,
        rowPaddingBottom: 5.5,
        labelWidth: 135,
        signatureBoxHeight: 36,
        footerFontSize: 9.0,
        footerAddressFontSize: 8.5,
        pageMarginH: 26,
        pageMarginV: 20,
      );
    } else if (estimatedLines <= 36) {
      // Heavy report (like Avanti Feeds with detailed action taken & remarks)
      return const _ServiceReportDensity(
        fontSize: 10.0,
        labelFontSize: 10.0,
        titleSize: 15.0,
        logoHeight: 40,
        headerBottomPadding: 5,
        headerMarginBottom: 8,
        rowPaddingBottom: 4.2,
        labelWidth: 130,
        signatureBoxHeight: 34,
        footerFontSize: 8.8,
        footerAddressFontSize: 8.0,
        pageMarginH: 26,
        pageMarginV: 20,
      );
    } else {
      // Very heavy report (40+ lines)
      return const _ServiceReportDensity(
        fontSize: 9.0,
        labelFontSize: 9.0,
        titleSize: 14.0,
        logoHeight: 34,
        headerBottomPadding: 4,
        headerMarginBottom: 6,
        rowPaddingBottom: 2.8,
        labelWidth: 125,
        signatureBoxHeight: 28,
        footerFontSize: 8.0,
        footerAddressFontSize: 7.5,
        pageMarginH: 24,
        pageMarginV: 16,
      );
    }
  }
}

class PdfReportService {
  // Bounded In-Memory LRU Cache for Instant PDF Rendering (<50ms)
  static final Map<String, Uint8List> _pdfLruCache = {};
  static const int _maxCachedPdfs = 6;

  static void cachePdf(String key, Uint8List bytes) {
    if (_pdfLruCache.length >= _maxCachedPdfs) {
      _pdfLruCache.remove(_pdfLruCache.keys.first);
    }
    _pdfLruCache[key] = bytes;
  }

  static Uint8List? getCachedPdf(String key) => _pdfLruCache[key];

  static void clearPdfCache() => _pdfLruCache.clear();
  static String _formatDate(dynamic value) {
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

  static List<Map<String, String>> parseContacts(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      if (raw.trim().startsWith('[')) {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((item) {
          final map = item as Map<String, dynamic>;
          return {
            'name': map['name']?.toString() ?? '',
            'phone': map['phone']?.toString() ?? '',
            'email': map['email']?.toString() ?? '',
          };
        }).toList();
      }
    } catch (_) {}
    return [
      {'name': raw, 'phone': '', 'email': ''}
    ];
  }

  static Future<void> shareReportPdf(Map<String, dynamic> report) async {
    try {
      final pdfBytes = await generateServiceReportPdf(report);
      final customer = report['customer_name']?.toString() ?? 'Report';
      final cleanName = customer.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), '_');
      final fileName = 'Service_Report_${cleanName.isEmpty ? 'Report' : cleanName}.pdf';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '📄 Service Call Report for $customer - Paramount Office Systems',
        ),
      );
    } catch (e) {
      debugPrint("Error sharing PDF: $e");
    }
  }

  static Future<void> shareInstallationReportPdf(Map<String, dynamic> report) async {
    try {
      final pdfBytes = await generateInstallationReportPdf(report);
      final customer = report['customer_name_address']?.toString().split('\n').first ?? 'Report';
      final cleanName = customer.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), '_');
      final fileName = 'Installation_Report_${cleanName.isEmpty ? 'Report' : cleanName}.pdf';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '📄 Equipment Installation Report for $customer - Paramount Office Systems',
        ),
      );
    } catch (e) {
      debugPrint("Error sharing PDF: $e");
    }
  }

  static Future<Uint8List> generateServiceReportPdf(Map<String, dynamic> report, {bool forceRefresh = false}) async {
    final cacheKey = 'service_${report['id'] ?? report['complaint_number']}_${report['updated_at'] ?? report['created_at']}';
    if (!forceRefresh) {
      final cached = getCachedPdf(cacheKey);
      if (cached != null) return cached;
    }
    final pdf = pw.Document();

    // Load Paramount Logo from assets
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/paramount_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    // Load Customer Signature if present
    pw.MemoryImage? signatureImage;
    final sigStr = report['customer_signature']?.toString() ?? report['customerSignature']?.toString();
    if (sigStr != null && sigStr.trim().isNotEmpty) {
      try {
        final cleanSig = sigStr.trim();
        final commaIndex = cleanSig.indexOf(',');
        final bytes = commaIndex != -1
            ? base64Decode(cleanSig.substring(commaIndex + 1))
            : base64Decode(cleanSig);
        signatureImage = pw.MemoryImage(bytes);
      } catch (_) {}
    }

    // Load Service Engineer Signature if present
    pw.MemoryImage? engineerSignatureImage;
    final engSigStr = report['engineer_signature']?.toString() ?? report['engineerSignature']?.toString();
    if (engSigStr != null && engSigStr.trim().isNotEmpty) {
      try {
        final cleanSig = engSigStr.trim();
        final commaIndex = cleanSig.indexOf(',');
        final bytes = commaIndex != -1
            ? base64Decode(cleanSig.substring(commaIndex + 1))
            : base64Decode(cleanSig);
        engineerSignatureImage = pw.MemoryImage(bytes);
      } catch (_) {}
    }

    final engineerName = report['service_engineer_name']?.toString() ?? '';
    final reportDate = _formatDate(report['report_date'] ?? report['created_at']);

    final customerName = report['customer_name']?.toString() ?? '';
    final address = report['address']?.toString() ?? '';

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

    final remarks = report['customer_remark']?.toString() ?? report['suggestions']?.toString() ?? report['latest_remark']?.toString() ?? '';
    final complaintNumber = report['complaint_number']?.toString() ?? report['complaintNumber']?.toString() ?? '';

    // Estimate line counts to calculate realistic height
    int estimateLines(String text, [int charsPerLine = 48]) {
      if (text.isEmpty) return 1;
      final lines = text.split('\n');
      int count = 0;
      for (final l in lines) {
        count += max(1, (l.length / charsPerLine).ceil());
      }
      return count;
    }

    final totalLines = estimateLines(address) +
        estimateLines(complaint) +
        estimateLines(problemFound) +
        estimateLines(actionTaken) +
        estimateLines(remarks, 52) +
        11; // single line rows (Complaint No, Customer, Product, Called/Responded Date, Spares, Old/New Series, Call Type, Solved Through)

    final textLen = (customerName + address + productText + complaint + problemFound + actionTaken + spares + oldSeries + newSeries + callType + chargeAmount + solvedThrough + remarks).length;

    final density = _ServiceReportDensity.compute(estimatedLines: totalLines, textLen: textLen);

    final printableWidth = PdfPageFormat.a4.width - (density.pageMarginH * 2);
    final printableHeight = PdfPageFormat.a4.height - (density.pageMarginV * 2);

    final lineH = density.fontSize * 1.25;
    final headerH = density.logoHeight + 3 + density.titleSize + 4 + (density.headerMarginBottom * 2) + density.headerBottomPadding + 20;
    final sigsH = density.signatureBoxHeight + 4 + density.labelFontSize;
    final footerH = 1 + 6 + (density.footerAddressFontSize * 1.25 * 4) + 12;

    // Calculate pure text heights (without row padding)
    double rawTextH = 0;
    int rowCount = 0;
    void addRawRow(String val, [int charsPerLine = 48]) {
      final lines = estimateLines(val, charsPerLine);
      rawTextH += lines * lineH;
      rowCount++;
    }

    if (complaintNumber.isNotEmpty) addRawRow(complaintNumber);
    addRawRow(customerName);
    addRawRow(address);
    addRawRow(productText);
    addRawRow(complaint);
    rawTextH += lineH; // Called/Responded Date row
    rowCount++;
    addRawRow(problemFound);
    addRawRow(actionTaken);
    addRawRow(spares);
    addRawRow(oldSeries);
    addRawRow(newSeries);
    rawTextH += lineH; // Call Type row
    rowCount++;
    addRawRow(solvedThrough);

    final remLines = estimateLines(remarks, 52);
    final rawRemarksH = (remLines * lineH) + density.labelFontSize + 4;

    // Base content without variable spacings
    final baseContentH = headerH + rawTextH + rawRemarksH + sigsH + footerH;
    final freeSpace = max(0.0, printableHeight - baseContentH);

    // Distribute freeSpace smoothly across rows, remarks, and signatures:
    // 1) Balanced row padding for comfortable vertical rhythm
    final effectiveRowPadding = (freeSpace * 0.35 / max(1, rowCount)).clamp(4.5, 11.0);
    final remarksTopMargin = (freeSpace * 0.08).clamp(4.0, 14.0);
    final signatureGap = (freeSpace * 0.25).clamp(16.0, 52.0);

    // 2) Dynamic bottom spacer: absorbs all remaining free space, ensuring the company
    // footer is anchored right at the bottom of the A4 page without empty dead space!
    final usedVariableH = (effectiveRowPadding * rowCount) + remarksTopMargin + signatureGap;
    final bottomSpacerH = max(8.0, freeSpace - usedVariableH);

    pw.Widget keyValue(String label, String valStr) {
      return pw.Padding(
        padding: pw.EdgeInsets.only(bottom: effectiveRowPadding),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: density.labelWidth,
              child: pw.Text(
                label,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize),
              ),
            ),
            pw.SizedBox(
              width: 14,
              child: pw.Text(':', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize)),
            ),
            pw.Expanded(
              child: pw.Text(
                valStr,
                style: pw.TextStyle(fontSize: density.fontSize, lineSpacing: 1.18),
              ),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.symmetric(horizontal: density.pageMarginH, vertical: density.pageMarginV),
        build: (pw.Context context) {
          return pw.Container(
            width: printableWidth,
            height: printableHeight,
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.topCenter,
              child: pw.Container(
                width: printableWidth,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    // Paramount Logo on Top Right
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        if (logoImage != null)
                          pw.Image(logoImage, height: density.logoHeight, fit: pw.BoxFit.contain)
                        else
                          pw.Text(
                            'PARAMOUNT',
                            style: pw.TextStyle(
                              fontSize: density.titleSize + 2,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 3),

                    // Title: SERVICE CALL REPORT
                    pw.Center(
                      child: pw.Text(
                        'SERVICE CALL REPORT',
                        style: pw.TextStyle(
                          fontSize: density.titleSize,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.2,
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: density.headerMarginBottom),

                    // Header Row: Engineer, Complaint No & Date
                    pw.Container(
                      padding: pw.EdgeInsets.only(bottom: density.headerBottomPadding),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(width: 1.5, color: PdfColors.black)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Row(
                              children: [
                                pw.Text('Name of Service Engineer: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize)),
                                pw.Expanded(
                                  child: pw.Text(engineerName, style: pw.TextStyle(fontSize: density.fontSize)),
                                ),
                              ],
                            ),
                          ),
                          pw.Row(
                            children: [
                              pw.Text('Date: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize)),
                              pw.Text(reportDate, style: pw.TextStyle(fontSize: density.fontSize)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: density.headerMarginBottom),

                    // Key-Value Rows
                    if (complaintNumber.isNotEmpty) keyValue('Complaint No.', complaintNumber),
                    keyValue('Customer Name', customerName),
                    keyValue('Address', address),
                    keyValue('Product', productText),
                    keyValue('Complaint', complaint),

                    // Called Date / Responded Date Row
                    pw.Padding(
                      padding: pw.EdgeInsets.only(bottom: effectiveRowPadding),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: density.labelWidth,
                                  child: pw.Text('Called Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize)),
                                ),
                                pw.SizedBox(width: 14, child: pw.Text(':', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize))),
                                pw.Expanded(child: pw.Text(calledDate, style: pw.TextStyle(fontSize: density.fontSize))),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: density.labelWidth - 15,
                                  child: pw.Text('Responded Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize)),
                                ),
                                pw.SizedBox(width: 14, child: pw.Text(':', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize))),
                                pw.Expanded(child: pw.Text(respondedDate, style: pw.TextStyle(fontSize: density.fontSize))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    keyValue('Problems Found', problemFound),
                    keyValue('Action taken', actionTaken),
                    keyValue('Spares if any', spares),
                    keyValue('Old Series No', oldSeries),
                    keyValue('New Series No', newSeries),

                    // Call Type & Amount Row
                    pw.Padding(
                      padding: pw.EdgeInsets.only(bottom: effectiveRowPadding),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.SizedBox(
                            width: density.labelWidth,
                            child: pw.Text('Call Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize)),
                          ),
                          pw.SizedBox(width: 14, child: pw.Text(':', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize))),
                          pw.Text(callType, style: pw.TextStyle(fontSize: density.fontSize)),
                          if (['Charge Based', 'AMC'].contains(callType) && chargeAmount.isNotEmpty) ...[
                            pw.SizedBox(width: 24),
                            pw.Text('Amount: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize)),
                            pw.Text('Rs $chargeAmount', style: pw.TextStyle(fontSize: density.fontSize)),
                          ],
                        ],
                      ),
                    ),

                    keyValue('Solved Through', solvedThrough),

                    // Remarks Section
                    pw.Padding(
                      padding: pw.EdgeInsets.only(top: remarksTopMargin, bottom: effectiveRowPadding),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Remarks:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize)),
                          pw.SizedBox(height: 3),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 14),
                            child: pw.Text(
                              remarks.isEmpty ? 'Enter remarks if any...' : remarks,
                              style: pw.TextStyle(
                                fontSize: density.fontSize - 0.4,
                                lineSpacing: 1.15,
                                color: remarks.isEmpty ? PdfColors.grey600 : PdfColors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Signature margin: dynamically calculated to anchor signatures and footer naturally
                    pw.SizedBox(height: signatureGap),

                    // Signature Block
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Column(
                          children: [
                            pw.Container(
                              width: 175,
                              height: density.signatureBoxHeight,
                              alignment: pw.Alignment.bottomCenter,
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(width: 1, style: pw.BorderStyle.dashed)),
                              ),
                              child: engineerSignatureImage != null
                                  ? pw.Image(engineerSignatureImage, height: density.signatureBoxHeight - 2, fit: pw.BoxFit.contain)
                                  : null,
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Service Engineer Signature',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize),
                            ),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Container(
                              width: 175,
                              height: density.signatureBoxHeight,
                              alignment: pw.Alignment.bottomCenter,
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(width: 1, style: pw.BorderStyle.dashed)),
                              ),
                              child: signatureImage != null
                                  ? pw.Image(signatureImage, height: density.signatureBoxHeight - 2, fit: pw.BoxFit.contain)
                                  : null,
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Customer Signature & Seal',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: density.labelFontSize),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Dynamic spacer that guarantees the footer is anchored cleanly at the bottom edge of A4
                    pw.SizedBox(height: bottomSpacerH),
                    pw.Container(height: 1.0, color: PdfColors.grey400),
                    pw.SizedBox(height: 6),

                    // Company Footer Particulars (Anchored cleanly at the bottom)
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Paramount Office Systems Pvt Ltd',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: density.footerFontSize + 0.8,
                                  color: PdfColors.blue900,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '28-21-1/F5, First Floor,\nClassic Complex, Prakasaraopeta,\nDabagardens, Visakhapatnam - 530 020',
                                style: pw.TextStyle(fontSize: density.footerAddressFontSize, color: PdfColors.grey800, lineSpacing: 1.15),
                              ),
                            ],
                          ),
                        ),
                        pw.Container(width: 1, height: density.footerFontSize * 4.4, color: PdfColors.grey400),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Phone: 0891-2705220, 6665220', style: pw.TextStyle(fontSize: density.footerAddressFontSize, color: PdfColors.grey800)),
                              pw.Text('Mobile: 98851 90883, 98851 90884', style: pw.TextStyle(fontSize: density.footerAddressFontSize, color: PdfColors.grey800)),
                              pw.Text('email: info@paramountindia.co.in', style: pw.TextStyle(fontSize: density.footerAddressFontSize, color: PdfColors.grey800)),
                              pw.Text('web: www.paramountindia.co.in', style: pw.TextStyle(fontSize: density.footerAddressFontSize, color: PdfColors.grey800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    cachePdf(cacheKey, bytes);
    return bytes;
  }

  static Future<Uint8List> generateInstallationReportPdf(Map<String, dynamic> report, {bool forceRefresh = false}) async {
    final cacheKey = 'install_${report['id'] ?? report['installation_no'] ?? report['customer_name_address']}_${report['updated_at'] ?? report['created_at']}';
    if (!forceRefresh) {
      final cached = getCachedPdf(cacheKey);
      if (cached != null) return cached;
    }
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/paramount_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    pw.MemoryImage? customerSignatureImage;
    final sigStr = (report['customer_signature'] ?? report['customerSignature'])?.toString();
    if (sigStr != null && sigStr.trim().isNotEmpty) {
      try {
        String base64Str = sigStr.trim();
        if (base64Str.contains(',')) {
          base64Str = base64Str.split(',').last;
        }
        base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(base64Str);
        if (bytes.isNotEmpty) {
          customerSignatureImage = pw.MemoryImage(bytes);
        }
      } catch (_) {}
    }

    final customerAddress = report['customer_name_address']?.toString() ?? '';
    final parsedContacts = parseContacts(report['contact_person']?.toString());

    final productName = report['product_name']?.toString() ?? '';
    final installationCompleted = report['installation_completed']?.toString() ?? '';
    final installationDate = _formatDate(report['installation_date']);
    final suggestions = report['suggestions']?.toString() ?? '';
    final installerName = report['installer_name']?.toString() ?? '';
    final status = report['status']?.toString() ?? 'Completed';

    pw.TableRow sectionHeaderRow(String title) {
      return pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            alignment: pw.Alignment.center,
            child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
          ),
          pw.Container(color: PdfColors.grey200),
        ],
      );
    }

    pw.TableRow gridRow(String label, pw.Widget contentWidget) {
      return pw.TableRow(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            color: PdfColors.grey100,
            alignment: pw.Alignment.topLeft,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            alignment: pw.Alignment.topLeft,
            child: contentWidget,
          ),
        ],
      );
    }

    pw.TableRow gridTextRow(String label, String value, {double minHeight = 0}) {
      return gridRow(
        label,
        pw.Container(
          constraints: minHeight > 0 ? pw.BoxConstraints(minHeight: minHeight) : const pw.BoxConstraints(),
          child: pw.Text(value.isEmpty ? '—' : value, style: const pw.TextStyle(fontSize: 9.5)),
        ),
      );
    }

    const marginH = 26.0;
    const marginV = 20.0;
    final printableWidth = PdfPageFormat.a4.width - (marginH * 2);
    final printableHeight = PdfPageFormat.a4.height - (marginV * 2);

    // Calculate approximate table height to anchor footer at the bottom
    int contactLines = 0;
    for (final c in parsedContacts) {
      contactLines += 1;
      if (c['phone']?.isNotEmpty == true) contactLines += 1;
      if (c['email']?.isNotEmpty == true) contactLines += 1;
    }
    contactLines = max(2, contactLines);

    final approxTableH = 28 + max(36.0, (customerAddress.length / 45).ceil() * 12.0) +
        (contactLines * 16.0) +
        28 + 24 + max(36.0, (installationCompleted.length / 45).ceil() * 12.0) +
        28 + 24 + max(26.0, (suggestions.length / 45).ceil() * 12.0) + 24 + 36 +
        26 + 45 + 26;

    final approxContentH = 44 + 3 + 16 + 10 + approxTableH + 60;
    final dynamicInstallSpacerH = max(10.0, printableHeight - approxContentH);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: marginH, vertical: marginV),
        build: (pw.Context context) {
          return pw.Container(
            width: printableWidth,
            height: printableHeight,
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.topCenter,
              child: pw.Container(
                width: printableWidth,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    // Logo Top Right
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        if (logoImage != null)
                          pw.Image(logoImage, height: 44, fit: pw.BoxFit.contain)
                        else
                          pw.Text('PARAMOUNT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      ],
                    ),
                    pw.SizedBox(height: 3),

                    // Title
                    pw.Center(
                      child: pw.Text(
                        'INSTALLATION REPORT',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ),
                    pw.SizedBox(height: 10),

                    // Form Table 2-Column Grid Box matching Image 2 exactly
                    pw.Table(
                      columnWidths: {
                        0: const pw.FixedColumnWidth(170),
                        1: const pw.FlexColumnWidth(),
                      },
                      border: pw.TableBorder.all(color: PdfColors.grey500, width: 1),
                      children: [
                        // Company Particulars Header
                        sectionHeaderRow('Company Particulars'),
                        gridTextRow('Company Name & Address', customerAddress, minHeight: 36),

                        // Contact Details Row
                        gridRow(
                          'Contact Details',
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              ...parsedContacts.map((c) {
                                return pw.Padding(
                                  padding: const pw.EdgeInsets.only(bottom: 4),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('Contact Person:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                                      pw.Text(c['name']?.isNotEmpty == true ? c['name']! : '—', style: const pw.TextStyle(fontSize: 9.5)),
                                      if (c['phone']?.isNotEmpty == true) ...[
                                        pw.SizedBox(height: 1),
                                        pw.Text('Telephone:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                                        pw.Text(c['phone']!, style: const pw.TextStyle(fontSize: 9.5)),
                                      ],
                                      if (c['email']?.isNotEmpty == true) ...[
                                        pw.SizedBox(height: 1),
                                        pw.Text('E-mail:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                                        pw.Text(c['email']!, style: const pw.TextStyle(fontSize: 9.5)),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        // Product Particulars Header
                        sectionHeaderRow('Product Particulars'),
                        gridTextRow('Product Name', productName),
                        gridTextRow('INSTALLATION COMPLETED', installationCompleted, minHeight: 36),

                        // Installation Particulars Header
                        sectionHeaderRow('Installation Particulars'),
                        gridTextRow('Installation Date', installationDate),
                        gridTextRow('Suggestions', suggestions, minHeight: 26),
                        gridTextRow('Installer Name', installerName),
                        gridRow(
                          "Installer's Signature",
                          pw.SizedBox(height: 36),
                        ),
                      ],
                    ),

                    // Acknowledgment Clause Row
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(6),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(color: PdfColors.grey500, width: 1),
                          right: pw.BorderSide(color: PdfColors.grey500, width: 1),
                          bottom: pw.BorderSide(color: PdfColors.grey500, width: 1),
                        ),
                      ),
                      child: pw.Text(
                        'This is to acknowledge that the above mentioned Hardware or Software are installed at our locations and the same are in working at our satisfaction.',
                        style: pw.TextStyle(fontSize: 9.0, fontStyle: pw.FontStyle.italic),
                      ),
                    ),

                    // Customer Signature & Status Box
                    pw.Table(
                      columnWidths: {
                        0: const pw.FixedColumnWidth(170),
                        1: const pw.FlexColumnWidth(),
                      },
                      border: pw.TableBorder.all(color: PdfColors.grey500, width: 1),
                      children: [
                        gridRow(
                          "Customer's Signature with Seal",
                          customerSignatureImage != null
                              ? pw.Image(customerSignatureImage, height: 40, fit: pw.BoxFit.contain)
                              : pw.SizedBox(height: 40),
                        ),
                        gridRow(
                          'Status',
                          pw.Text(
                            status.toUpperCase(),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.green800),
                          ),
                        ),
                      ],
                    ),

                    // Spacer to anchor footer at the bottom of the page
                    pw.SizedBox(height: dynamicInstallSpacerH),

                    pw.Container(height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 6),

                    // Company Footer
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Paramount Office Systems Pvt Ltd', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColors.blue900)),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '28-21-1/F5, First Floor,\nClassic Complex, Prakasaraopeta,\nDabagardens, Visakhapatnam - 530 020',
                                style: const pw.TextStyle(fontSize: 8.0, color: PdfColors.grey800),
                              ),
                            ],
                          ),
                        ),
                        pw.Container(width: 1, height: 36, color: PdfColors.grey400),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Phone: 0891-2705220, 6665220', style: const pw.TextStyle(fontSize: 8.0, color: PdfColors.grey800)),
                              pw.Text('Mobile: 98851 90883, 98851 90884', style: const pw.TextStyle(fontSize: 8.0, color: PdfColors.grey800)),
                              pw.Text('email: info@paramountindia.co.in', style: const pw.TextStyle(fontSize: 8.0, color: PdfColors.grey800)),
                              pw.Text('web: www.paramountindia.co.in', style: const pw.TextStyle(fontSize: 8.0, color: PdfColors.grey800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    cachePdf(cacheKey, bytes);
    return bytes;
  }

  static Future<void> printOrDownloadReportPdf(Map<String, dynamic> report) async {
    final pdfBytes = await generateServiceReportPdf(report);
    final compNum = report['complaint_number'] ?? report['complaintNumber'] ?? report['id'] ?? 'Report';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Service_Call_Report_$compNum.pdf',
      format: PdfPageFormat.a4,
    );
  }

  static Future<void> printOrDownloadInstallationReportPdf(Map<String, dynamic> report) async {
    final pdfBytes = await generateInstallationReportPdf(report);
    final cust = report['customer_name_address']?.toString().split('\n').first.trim() ?? report['id'] ?? 'Report';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Installation_Report_$cust.pdf',
      format: PdfPageFormat.a4,
    );
  }
}

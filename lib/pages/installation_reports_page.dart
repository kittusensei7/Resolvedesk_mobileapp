import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/api_config.dart';
import '../services/permission_access.dart';
import '../services/pdf_report_service.dart';
import '../widgets/installation_report_preview_dialog.dart';
import '../widgets/paradesk_shimmer.dart';
import 'create_installation_report_page.dart';

class InstallationReportsPage extends StatefulWidget {
  const InstallationReportsPage({super.key});

  @override
  State<InstallationReportsPage> createState() => _InstallationReportsPageState();
}

class _InstallationReportsPageState extends State<InstallationReportsPage> {
  PermissionAccess? _access;
  List<dynamic> _reports = [];
  List<dynamic> _filteredReports = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await PermissionAccess.load();
      if (!mounted) return;
      setState(() => _access = access);
      final dio = await ApiConfig.getDio();
      final response = await dio.get('/installation-reports');
      if (mounted) {
        final list = List<dynamic>.from(response.data as List);
        setState(() {
          _reports = list;
          _filterReports(_searchQuery);
        });
      }
    } on DioException catch (error) {
      if (mounted) {
        final msg = error.response?.data is Map ? error.response?.data['message']?.toString() : 'Unable to load reports';
        setState(() => _error = msg ?? 'Unable to load installation reports.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load installation reports.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterReports(String query) {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _filteredReports = List.from(_reports);
    } else {
      final q = query.toLowerCase().trim();
      _filteredReports = _reports.where((raw) {
        final report = Map<String, dynamic>.from(raw as Map);
        final company = (report['customer_name_address'] ?? '').toString().toLowerCase();
        final contact = (report['contact_person'] ?? '').toString().toLowerCase();
        final product = (report['product_name'] ?? '').toString().toLowerCase();
        final installer = (report['installer_name'] ?? '').toString().toLowerCase();
        return company.contains(q) || contact.contains(q) || product.contains(q) || installer.contains(q);
      }).toList();
    }
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '—';
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

  void _showReportPreview(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => InstallationReportPreviewDialog(report: item),
    );
  }

  Future<void> _deleteReport(Map<String, dynamic> report) async {
    final reportId = report['id'];
    final companyName = report['customer_name_address']?.toString() ?? 'Report #$reportId';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xffef4444), size: 24),
            SizedBox(width: 8),
            Text('Delete Installation Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the installation report for "$companyName"? This action cannot be undone.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xff334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xff64748b), fontWeight: FontWeight.w600)),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffef4444),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final dio = await ApiConfig.getDio();
      await dio.delete('/installation-reports/$reportId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Installation Report deleted successfully.')),
        );
        _loadReports();
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data is Map ? e.response?.data['message']?.toString() : 'Failed to delete report';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg ?? 'Failed to delete report.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete report.')),
        );
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color border;
    Color text;

    switch (status.trim().toLowerCase()) {
      case 'completed':
        bg = const Color(0xffecfdf5);
        border = const Color(0xffa7f3d0);
        text = const Color(0xff059669);
        break;
      case 'in progress':
        bg = const Color(0xffeff6ff);
        border = const Color(0xffbfdbfe);
        text = const Color(0xff1d4ed8);
        break;
      default:
        bg = const Color(0xfffef3c7);
        border = const Color(0xfffde68a);
        text = const Color(0xffb45309);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      body: RefreshIndicator(
        color: const Color(0xff0284c7),
        backgroundColor: Colors.white,
        onRefresh: _loadReports,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Page Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Installation Reports',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: Color(0xff0f172a),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Reports for completed equipment installations',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xff64748b)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (_access?.can('installations', 'add') ?? false)
                  FilledButton.icon(
                    onPressed: () async {
                      final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateInstallationReportPage()),
                      );
                      if (saved == true) _loadReports();
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff1e3a8a),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ).animate().fadeIn(duration: 250.ms),
            const SizedBox(height: 16),

            // Executive Search Bar Filter
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xffe2e8f0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x060f172a),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _filterReports(val)),
                style: const TextStyle(fontSize: 13.5, color: Color(0xff0f172a)),
                decoration: InputDecoration(
                  hintText: 'Search company, contact, product, installer...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xff94a3b8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xff64748b)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xff64748b)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _filterReports(''));
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xff0284c7), width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Main Content Area: Loading Skeletons, Error, Empty, or Reports List
            if (_loading) ...[
              const ReportCardSkeleton(),
              const ReportCardSkeleton(),
              const ReportCardSkeleton(),
            ] else if (_error != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xfffef2f2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xfffecaca)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xffef4444), size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xffb91c1c), fontSize: 13.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadReports,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffef4444),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_filteredReports.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x060f172a),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xfff1f5f9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.build_circle_outlined, size: 28, color: Color(0xff64748b)),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No Installation Reports Found',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xff0f172a)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isNotEmpty ? 'Try adjusting your search criteria' : 'Reports will appear here once submitted',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xff64748b), fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    if (_searchQuery.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _searchController.clear();
                          setState(() => _filterReports(''));
                        },
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Clear Search & Show All'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: const BorderSide(color: Color(0xffcbd5e1)),
                        ),
                      )
                    else if (_access?.can('installations', 'add') ?? false)
                      FilledButton.icon(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          final saved = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateInstallationReportPage()),
                          );
                          if (saved == true) _loadReports();
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Create Installation Report'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff1e3a8a),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                  ],
                ),
              )
            else
              ..._filteredReports.map((raw) {
                final report = Map<String, dynamic>.from(raw as Map);
                final companyName = report['customer_name_address']?.toString() ?? '—';
                final parsedContacts = PdfReportService.parseContacts(report['contact_person']?.toString());
                final firstContact = parsedContacts.isNotEmpty ? parsedContacts.first : {'name': '—', 'phone': '', 'email': ''};

                final installer = report['installer_name']?.toString() ?? '—';
                final dateStr = _formatDate(report['installation_date']);
                final status = report['status']?.toString() ?? 'Completed';
                final productName = report['product_name']?.toString() ?? '—';

                return RepaintBoundary(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xffe2e8f0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x060f172a),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Company Name & Status Badge
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  companyName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                    color: Color(0xff0f172a),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(status),
                            ],
                          ),
                        ),

                      // Contact Person Details Slate Box
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xfff8fafc),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xfff1f5f9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 15, color: Color(0xff1e3a8a)),
                                const SizedBox(width: 6),
                                Text(
                                  firstContact['name']?.isNotEmpty == true ? firstContact['name']! : '—',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff1e3a8a)),
                                ),
                              ],
                            ),
                            if (firstContact['phone']?.isNotEmpty == true || firstContact['email']?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${firstContact['phone']?.isNotEmpty == true ? 'Ph: ${firstContact['phone']}' : ''}${firstContact['phone']?.isNotEmpty == true && firstContact['email']?.isNotEmpty == true ? '  •  ' : ''}${firstContact['email']?.isNotEmpty == true ? 'Email: ${firstContact['email']}' : ''}',
                                style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Info Grid Row: Product | Installer | Date
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xff64748b)),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: Color(0xff334155), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.engineering_outlined, size: 14, color: Color(0xff64748b)),
                                const SizedBox(width: 4),
                                Text(
                                  installer,
                                  style: const TextStyle(fontSize: 12, color: Color(0xff334155), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xff64748b)),
                                const SizedBox(width: 4),
                                Text(
                                  dateStr,
                                  style: const TextStyle(fontSize: 12, color: Color(0xff64748b), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xfff1f5f9)),

                      // Action Bar: Edit | Delete | View PDF
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                if (_access?.can('installations', 'edit') ?? false)
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final saved = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CreateInstallationReportPage(editingReport: report),
                                        ),
                                      );
                                      if (saved == true) _loadReports();
                                    },
                                    icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xff1d4ed8)),
                                    label: const Text('Edit', style: TextStyle(color: Color(0xff1d4ed8), fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      side: const BorderSide(color: Color(0xffbfdbfe)),
                                      backgroundColor: const Color(0xffeff6ff),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                if (_access?.can('installations', 'delete') ?? false)
                                  OutlinedButton.icon(
                                    onPressed: () => _deleteReport(report),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xffdc2626)),
                                    label: const Text('Delete', style: TextStyle(color: Color(0xffdc2626), fontSize: 12, fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      side: const BorderSide(color: Color(0xfffca5a5)),
                                      backgroundColor: const Color(0xfffef2f2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                              ],
                            ),
                            FilledButton.icon(
                              onPressed: () => _showReportPreview(report),
                              icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                              label: const Text('View A4 Report & PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xff1e3a8a),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.04, end: 0),
              );
              }),
          ],
        ),
      ),
    );
  }
}

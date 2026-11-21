import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../services/permission_access.dart';
import '../widgets/signature_upload_widget.dart';

class ComplaintDetailsPage extends StatefulWidget {
  const ComplaintDetailsPage({super.key, required this.complaintId});

  final int complaintId;

  @override
  State<ComplaintDetailsPage> createState() => _ComplaintDetailsPageState();
}

class _ComplaintDetailsPageState extends State<ComplaintDetailsPage> {
  bool _canEdit = false;
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _openGoogleMaps(String address) async {
    if (address.trim().isEmpty) return;
    final query = Uri.encodeComponent(address.trim());
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    final geoUrl = Uri.parse('geo:0,0?q=$query');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl);
      } else {
        await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  final _problemFoundController = TextEditingController();
  final _actionTakenController = TextEditingController();
  final _spareNameController = TextEditingController();
  final _spareOldSeriesController = TextEditingController();
  final _spareNewSeriesController = TextEditingController();
  final _chargeAmountController = TextEditingController();
  final _newRemarkController = TextEditingController();
  final _rescheduleReasonController = TextEditingController();

  DateTime? _selectedRescheduleDate;
  bool _savingReschedule = false;

  String _callType = 'Warranty';
  String _solvedThrough = 'On-Site';
  String _customerSignature = '';
  String _engineerSignature = '';
  bool _markResolved = false;

  @override
  void dispose() {
    _problemFoundController.dispose();
    _actionTakenController.dispose();
    _spareNameController.dispose();
    _spareOldSeriesController.dispose();
    _spareNewSeriesController.dispose();
    _chargeAmountController.dispose();
    _newRemarkController.dispose();
    _rescheduleReasonController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access=await PermissionAccess.load();
      if(!mounted) return;
      setState(()=>_canEdit=access.can('service_calls','edit') || access.can('complaints','edit'));
      final dio = await ApiConfig.getDio();
      final response = await dio.get('mobile/technician/complaints/${widget.complaintId}');
      final payload = Map<String, dynamic>.from(response.data as Map);
      final complaint = Map<String, dynamic>.from(payload['complaint'] as Map);

      _problemFoundController.text = complaint['problem_found']?.toString() ?? '';
      _actionTakenController.text = complaint['action_taken']?.toString() ?? '';
      _spareNameController.text = complaint['spare_name']?.toString() ?? '';
      _spareOldSeriesController.text = complaint['spare_old_series']?.toString() ?? '';
      _spareNewSeriesController.text = complaint['spare_new_series']?.toString() ?? '';
      _chargeAmountController.text = complaint['charge_amount']?.toString() ?? complaint['chargeAmount']?.toString() ?? '';
      _customerSignature = complaint['customer_signature']?.toString() ?? complaint['customerSignature']?.toString() ?? '';
      _engineerSignature = complaint['engineer_signature']?.toString() ?? complaint['engineerSignature']?.toString() ?? '';

      final rawRDate = complaint['reschedule_date']?.toString() ?? complaint['rescheduleDate']?.toString();
      if (rawRDate != null && rawRDate.isNotEmpty) {
        _selectedRescheduleDate = DateTime.tryParse(rawRDate)?.toLocal();
      } else {
        _selectedRescheduleDate = null;
      }
      _rescheduleReasonController.text = complaint['reschedule_reason']?.toString() ?? complaint['rescheduleReason']?.toString() ?? '';

      final callTypeVal = complaint['coverage_type']?.toString() ?? complaint['coverageType']?.toString() ?? complaint['call_type']?.toString() ?? complaint['callType']?.toString();
      if (callTypeVal != null && callTypeVal.isNotEmpty) {
        _callType = callTypeVal;
      } else if (complaint['amc_from'] != null || complaint['amc_to'] != null || complaint['amcFrom'] != null || complaint['amcTo'] != null) {
        _callType = 'AMC';
      }
      final solvedThroughVal = complaint['solved_through']?.toString() ?? complaint['solvedThrough']?.toString();
      if (solvedThroughVal != null && solvedThroughVal.isNotEmpty) {
        _solvedThrough = solvedThroughVal;
      }

      if (mounted) {
        setState(() => _data = payload);
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.response?.data is Map
              ? error.response?.data['message']?.toString()
              : 'Unable to load complaint details.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load complaint details.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitReschedule() async {
    HapticFeedback.mediumImpact();
    if (_selectedRescheduleDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reschedule date.')),
      );
      return;
    }

    setState(() => _savingReschedule = true);
    try {
      final dio = await ApiConfig.getDio();
      final formattedDate =
          "${_selectedRescheduleDate!.year.toString().padLeft(4, '0')}-${_selectedRescheduleDate!.month.toString().padLeft(2, '0')}-${_selectedRescheduleDate!.day.toString().padLeft(2, '0')}";

      await dio.post(
        'mobile/technician/complaints/${widget.complaintId}/reschedule',
        data: {
          'rescheduleDate': formattedDate,
          'rescheduleReason': _rescheduleReasonController.text.trim(),
        },
      );

      await _loadDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xff16a34a),
            content: Text('Complaint rescheduled successfully! Notification queued to support.'),
          ),
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        final msg = error.response?.data is Map
            ? error.response?.data['message']?.toString()
            : error.message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg ?? 'Failed to reschedule complaint.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingReschedule = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    HapticFeedback.mediumImpact();
    if (status == 'Resolved' &&
        (_problemFoundController.text.trim().isEmpty || _actionTakenController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Problem Found and Action Taken before marking call resolved.')),
      );
      return;
    }
    if (_callType == 'Charge Based' &&
        (double.tryParse(_chargeAmountController.text.trim()) == null ||
            double.parse(_chargeAmountController.text.trim()) <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Charge Amount for Charge Based call.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final dio = await ApiConfig.getDio();
      await dio.patch(
        '/complaints/${widget.complaintId}/status',
        data: {
          'status': status,
          'problemFound': _problemFoundController.text.trim(),
          'actionTaken': _actionTakenController.text.trim(),
          'spareName': _spareNameController.text.trim(),
          'spareOldSeries': _spareOldSeriesController.text.trim(),
          'spareNewSeries': _spareNewSeriesController.text.trim(),
          'callType': _callType,
          'solvedThrough': _solvedThrough,
          'chargeAmount': ['AMC', 'Charge Based'].contains(_callType) ? _chargeAmountController.text.trim() : null,
          'customerSignature': _customerSignature,
          'engineerSignature': _engineerSignature,
        },
      );
      await _loadDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complaint status updated to $status.')),
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        final msg = error.response?.data is Map ? error.response?.data['message']?.toString() : 'Update failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg ?? 'Update failed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatMins(dynamic val) {
    final mins = int.tryParse(val?.toString() ?? '') ?? 0;
    if (mins < 60) return '$mins min${mins == 1 ? '' : 's'}';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    if (rem == 0) return '$hrs hr${hrs == 1 ? '' : 's'}';
    return '$hrs hr${hrs == 1 ? '' : 's'} $rem min${rem == 1 ? '' : 's'}';
  }

  Future<void> _resumeCall() async {
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      final dio = await ApiConfig.getDio();
      await dio.post('mobile/technician/complaints/${widget.complaintId}/resume');
      await _loadDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xff0284c7),
            content: Text('Work resumed! Resolution timer unfrozen.'),
          ),
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        final msg = error.response?.data is Map ? error.response?.data['message']?.toString() : 'Resume failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg ?? 'Resume failed.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showHoldBottomSheet() {
    String selectedQuickReason = 'Client in meeting / requested later visit';
    final customReasonController = TextEditingController(text: selectedQuickReason);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '⏸️ Pause Call / Client Busy',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Freezes the resolution timer so customer wait time is not counted against working hours (10:00 AM – 6:30 PM).',
                    style: TextStyle(color: Color(0xff64748b), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Delay Reason:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Client in meeting / requested later visit',
                      'Client staff busy with other work',
                      'Premises / Machine not accessible',
                      'Waiting for client confirmation',
                      'Client requested revisit tomorrow',
                    ].map((reason) {
                      final isSelected = selectedQuickReason == reason;
                      return ChoiceChip(
                        label: Text(reason, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                        selected: isSelected,
                        selectedColor: const Color(0xff0284c7),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              selectedQuickReason = reason;
                              customReasonController.text = reason;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: customReasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Reason Details / Remarks',
                      hintText: 'Enter details client mentioned...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffd97706),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.pause),
                      label: const Text('Confirm Hold & Freeze Timer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        final reason = customReasonController.text.trim();
                        Navigator.pop(ctx);
                        setState(() => _saving = true);
                        try {
                          final dio = await ApiConfig.getDio();
                          await dio.post(
                            'mobile/technician/complaints/${widget.complaintId}/hold',
                            data: {'reason': reason.isNotEmpty ? reason : 'Customer busy / requested delay'},
                          );
                          await _loadDetails();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Color(0xffd97706),
                                content: Text('Complaint placed on hold. Timer frozen!'),
                              ),
                            );
                          }
                        } on DioException catch (error) {
                          if (mounted) {
                            final msg = error.response?.data is Map ? error.response?.data['message']?.toString() : 'Failed to hold call';
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg ?? 'Failed to hold call.')));
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addRemark() async {
    final text = _newRemarkController.text.trim();
    if (text.isEmpty) return;

    setState(() => _saving = true);
    try {
      final dio = await ApiConfig.getDio();
      await dio.post(
        '/complaints/${widget.complaintId}/remarks',
        data: {
          'remark': text,
          'markResolved': _markResolved,
          'problemFound': _problemFoundController.text.trim(),
          'actionTaken': _actionTakenController.text.trim(),
          'spareName': _spareNameController.text.trim(),
          'spareOldSeries': _spareOldSeriesController.text.trim(),
          'spareNewSeries': _spareNewSeriesController.text.trim(),
          'callType': _callType,
          'solvedThrough': _solvedThrough,
          'chargeAmount': _callType == 'Charge Based' ? _chargeAmountController.text.trim() : null,
          'customerSignature': _customerSignature,
          'engineerSignature': _engineerSignature,
        },
      );
      _newRemarkController.clear();
      _markResolved = false;
      await _loadDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remark submitted successfully.')),
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        final msg = error.response?.data is Map ? error.response?.data['message']?.toString() : 'Failed to add remark';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg ?? 'Failed to add remark.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _infoRow(String label, dynamic value, {IconData? icon}) {
    final text = value?.toString() ?? '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: const Color(0xff64748b)),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: Color(0xff64748b), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const Text(':', style: TextStyle(color: Color(0xff64748b), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.isEmpty ? '—' : text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff0f172a)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCoverageInfo(Map<String, dynamic>? c) {
    if (c == null) return '—';
    final cov = c['coverage_type']?.toString() ?? c['coverageType']?.toString() ?? c['call_type']?.toString() ?? 'Warranty';
    final amcFrom = c['amc_from']?.toString() ?? c['amcFrom']?.toString();
    final amcTo = c['amc_to']?.toString() ?? c['amcTo']?.toString();
    final amt = c['charge_amount']?.toString() ?? c['chargeAmount']?.toString();
    final warranty = c['warranty_upto']?.toString() ?? c['warrantyUpto']?.toString();

    if (cov == 'AMC' || amcFrom != null || amcTo != null) {
      final dates = (amcFrom != null || amcTo != null) ? ' (${amcFrom ?? '-'} to ${amcTo ?? '-'})' : '';
      final fee = (amt != null && amt.isNotEmpty) ? ' • ₹$amt' : '';
      return 'AMC$dates$fee';
    }
    if (cov == 'Charge Based') {
      final fee = (amt != null && amt.isNotEmpty) ? ' • ₹$amt' : '';
      return 'Charge Based$fee';
    }
    final wDate = (warranty != null && warranty.isNotEmpty) ? ' upto $warranty' : '';
    return 'Warranty$wDate';
  }

  @override
  Widget build(BuildContext context) {
    final complaint = _data?['complaint'] as Map<String, dynamic>?;
    final team = List<dynamic>.from(_data?['assignedTechnicians'] as List? ?? const []);
    final remarks = List<dynamic>.from(_data?['remarks'] as List? ?? const []);
    final statusHistory = List<dynamic>.from(_data?['statusHistory'] as List? ?? const []);
    final assignmentHistory = List<dynamic>.from(_data?['assignmentHistory'] as List? ?? const []);

    final isResolved = complaint?['status']?.toString().trim() == 'Resolved';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          complaint?['complaint_number']?.toString() ?? 'Complaint Workspace',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: Color(0xffef4444))),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDetails,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Executive Apple HIG Header Status Banner
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xff1e3a8a), Color(0xff0f172a)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xff1e3a8a).withValues(alpha: 0.28),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Hero(
                                    tag: 'complaint_number_${complaint?['id'] ?? widget.complaintId}',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Text(
                                        complaint?['complaint_number']?.toString() ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: Container(
                                      key: ValueKey(complaint?['status']),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isResolved
                                          ? const Color(0xffecfdf5)
                                          : complaint?['status'] == 'Ongoing'
                                              ? const Color(0xffeff6ff)
                                              : complaint?['status'] == 'Pending'
                                                  ? const Color(0xfffef3c7)
                                                  : Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isResolved
                                            ? const Color(0xffa7f3d0)
                                            : complaint?['status'] == 'Ongoing'
                                                ? const Color(0xffbfdbfe)
                                                : complaint?['status'] == 'Pending'
                                                    ? const Color(0xfffde68a)
                                                    : Colors.white.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (complaint?['status'] == 'Ongoing') ...[
                                          Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.only(right: 5),
                                            decoration: const BoxDecoration(
                                              color: Color(0xff0284c7),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                        Text(
                                          complaint?['status']?.toString() ?? '',
                                          style: TextStyle(
                                            color: isResolved
                                                ? const Color(0xff059669)
                                                : complaint?['status'] == 'Ongoing'
                                                    ? const Color(0xff1d4ed8)
                                                    : complaint?['status'] == 'Pending'
                                                        ? const Color(0xffb45309)
                                                        : Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${complaint?['company_name'] ?? '—'} • ${complaint?['customer_name'] ?? '—'}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              // 4-Step HIG Stepper
                              Container(
                                padding: const EdgeInsets.only(top: 10),
                                decoration: BoxDecoration(
                                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('1. Assigned', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                        Text(
                                          complaint?['status'] == 'Pending' ? '2. Pending Action' : '2. Accepted',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: complaint?['status'] == 'Pending' ? FontWeight.w900 : FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          complaint?['status'] == 'Ongoing'
                                              ? '3. Ongoing Repair'
                                              : complaint?['status'] == 'Rescheduled'
                                                  ? '3. Rescheduled'
                                                  : complaint?['status'] == 'On Hold'
                                                      ? '3. On Hold'
                                                      : '3. In Progress',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: complaint?['status'] == 'Ongoing' || complaint?['status'] == 'Rescheduled' || complaint?['status'] == 'On Hold'
                                                ? FontWeight.w900
                                                : FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '4. Resolved',
                                          style: TextStyle(
                                            color: isResolved ? Colors.white : Colors.white60,
                                            fontSize: 10,
                                            fontWeight: isResolved ? FontWeight.w900 : FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: SizedBox(
                                        height: 4,
                                        child: Row(
                                          children: [
                                            Expanded(child: Container(color: Colors.white)),
                                            const SizedBox(width: 2),
                                            Expanded(
                                              child: Container(
                                                color: complaint?['status'] != 'Assigned' ? Colors.white : Colors.white24,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Expanded(
                                              child: Container(
                                                color: isResolved || complaint?['status'] == 'Ongoing' || complaint?['status'] == 'Rescheduled' || complaint?['status'] == 'On Hold'
                                                    ? Colors.white
                                                    : Colors.white24,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Expanded(
                                              child: Container(
                                                color: isResolved ? Colors.white : Colors.white24,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Pending Action Guidance Banner
                      if (complaint?['status'] == 'Pending') ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xfff0f9ff),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xffbae6fd)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.hourglass_top_rounded, color: Color(0xff0284c7), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Service Call Pending Technician Start',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xff0369a1), fontSize: 13.5),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Technician has received this request. Tap "Mark Ongoing" upon arriving at customer premises.',
                                      style: TextStyle(color: Color(0xff334155), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // On Hold Banner
                      if (complaint?['status'] == 'On Hold')
                        Card(
                          elevation: 0,
                          color: const Color(0xfffffbeb),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xfffde68a)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.pause_circle, color: Color(0xffb45309), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Call On Hold (Resolution Timer Paused)',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xffb45309), fontSize: 14),
                                    ),
                                  ],
                                ),
                                if ((complaint?['pause_reason'] ?? complaint?['pauseReason']) != null &&
                                    (complaint?['pause_reason'] ?? complaint?['pauseReason']).toString().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Reason: ${complaint?['pause_reason'] ?? complaint?['pauseReason']}',
                                    style: const TextStyle(color: Color(0xff92400e), fontSize: 13),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                const Text(
                                  'Working hours timer (10:00 AM – 6:30 PM) is frozen during this hold. Tap "Resume Work" when client is available.',
                                  style: TextStyle(color: Color(0xff78350f), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Resolved Working Hours Breakdown Banner
                      if (isResolved)
                        Card(
                          elevation: 0,
                          color: const Color(0xfff0fdf4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xffbbf7d0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Color(0xff16a34a), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Complaint Resolved & Verified',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xff16a34a), fontSize: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (complaint?['working_resolution_minutes'] != null || complaint?['workingResolutionMinutes'] != null) ...[
                                  Text(
                                    '⏱️ Net Business Working Time: ${_formatMins(complaint?['working_resolution_minutes'] ?? complaint?['workingResolutionMinutes'])} (10:00 AM – 6:30 PM, Mon–Sat)',
                                    style: const TextStyle(color: Color(0xff15803d), fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                                if ((int.tryParse(complaint?['total_paused_minutes']?.toString() ?? complaint?['totalPausedMinutes']?.toString() ?? '') ?? 0) > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '⏸️ Client Delay Paused: ${_formatMins(complaint?['total_paused_minutes'] ?? complaint?['totalPausedMinutes'])}${(complaint?['pause_reason'] ?? complaint?['pauseReason']) != null ? ' ("${complaint?['pause_reason'] ?? complaint?['pauseReason']}")' : ''}',
                                    style: const TextStyle(color: Color(0xffb45309), fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                      if (complaint?['status'] == 'On Hold' || isResolved)
                        const SizedBox(height: 14),

                      // Quick Action Buttons
                      if (!isResolved)
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xffe2e8f0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    if (complaint?['status'] == 'On Hold')
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: !_canEdit || _saving ? null : _resumeCall,
                                          icon: const Icon(Icons.play_circle_fill),
                                          label: const Text('Resume Work'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xff0284c7),
                                          ),
                                        ),
                                      )
                                    else
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _saving || complaint?['status'] == 'Ongoing'
                                              ? null
                                              : () => _updateStatus('Ongoing'),
                                          icon: const Icon(Icons.play_arrow_outlined),
                                          label: const Text('Mark Ongoing'),
                                        ),
                                      ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: !_canEdit || _saving ? null : () => _updateStatus('Resolved'),
                                        icon: const Icon(Icons.check_circle),
                                        label: const Text('Mark Resolved'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xff16a34a),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (complaint?['status'] == 'Ongoing') ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: !_canEdit || _saving ? null : _showHoldBottomSheet,
                                      icon: const Icon(Icons.pause_circle_outline, color: Color(0xffb45309)),
                                      label: const Text('Pause Call (Client Busy / Freeze Timer)', style: TextStyle(color: Color(0xffb45309), fontWeight: FontWeight.w600)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xfffde68a)),
                                        backgroundColor: const Color(0xfffffbeb),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 14),

                      // Reschedule Service Call Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: complaint?['status'] == 'Rescheduled' ? const Color(0xfffed7aa) : const Color(0xffe2e8f0),
                            width: complaint?['status'] == 'Rescheduled' ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.event_repeat, color: Color(0xff1e3a8a), size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Reschedule Service Call',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xff0f172a),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (complaint?['status'] == 'Rescheduled')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xfffff7ed),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xffffedd5)),
                                      ),
                                      child: const Text(
                                        'Rescheduled',
                                        style: TextStyle(color: Color(0xffc2410c), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (complaint?['reschedule_date'] != null || complaint?['rescheduleDate'] != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xfffff7ed),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xffffedd5)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_month, size: 16, color: Color(0xff1e3a8a)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Proposed Visit: ${(complaint?['reschedule_date'] ?? complaint?['rescheduleDate']).toString().split('T').first}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff1e3a8a)),
                                          ),
                                        ],
                                      ),
                                      if ((complaint?['reschedule_reason'] ?? complaint?['rescheduleReason']) != null &&
                                          (complaint?['reschedule_reason'] ?? complaint?['rescheduleReason']).toString().trim().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Reason: ${(complaint?['reschedule_reason'] ?? complaint?['rescheduleReason']).toString()}',
                                          style: const TextStyle(fontSize: 12.5, color: Color(0xff7c2d12)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],

                              if (!isResolved) ...[
                                const Text(
                                  'Set Reschedule Date & Reason',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xff475569)),
                                ),
                                const SizedBox(height: 10),

                                // Date Picker & Reason Textbox
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Column 1: Date Picker
                                    Expanded(
                                      flex: 5,
                                      child: InkWell(
                                        onTap: () async {
                                          final now = DateTime.now();
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: _selectedRescheduleDate ?? now.add(const Duration(days: 1)),
                                            firstDate: now,
                                            lastDate: now.add(const Duration(days: 365)),
                                          );
                                          if (picked != null) {
                                            setState(() => _selectedRescheduleDate = picked);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xfff8fafc),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xffcbd5e1)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.calendar_today, size: 16, color: Color(0xff1e3a8a)),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  _selectedRescheduleDate != null
                                                      ? "${_selectedRescheduleDate!.day.toString().padLeft(2, '0')}-${_selectedRescheduleDate!.month.toString().padLeft(2, '0')}-${_selectedRescheduleDate!.year}"
                                                      : 'Select Date',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: _selectedRescheduleDate != null ? const Color(0xff0f172a) : const Color(0xff94a3b8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Column 2: Reason TextField
                                    Expanded(
                                      flex: 6,
                                      child: TextField(
                                        controller: _rescheduleReasonController,
                                        decoration: const InputDecoration(
                                          labelText: 'Reschedule Reason',
                                          hintText: 'Why rescheduled?',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Save Reschedule Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: FilledButton.icon(
                                    onPressed: !_canEdit || _savingReschedule ? null : _submitReschedule,
                                    icon: _savingReschedule
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.schedule_send, size: 18),
                                    label: Text(_savingReschedule ? 'Saving Reschedule...' : 'Save Reschedule'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xff1e3a8a),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Call Overview Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xffe2e8f0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Call Overview',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xff1e3a8a),
                                    ),
                              ),
                              const SizedBox(height: 14),
                              _infoRow('Company', complaint?['company_name'], icon: Icons.business),
                              _infoRow('Customer Name', complaint?['customer_name'], icon: Icons.person_outline),
                              _infoRow('Phone Number', complaint?['customer_phone'], icon: Icons.phone_outlined),
                              _infoRow('Email', complaint?['customer_email'], icon: Icons.email_outlined),
                              _infoRow('Address', complaint?['address'], icon: Icons.location_on_outlined),
                              _infoRow('Product & Model', '${complaint?['product'] ?? '—'} ${complaint?['model'] ?? ''}', icon: Icons.inventory_2_outlined),
                              _infoRow('Issue Type', complaint?['issue_type'], icon: Icons.report_problem_outlined),
                              _infoRow('Description', complaint?['description'], icon: Icons.notes),
                              _infoRow('Priority', complaint?['priority'] ?? 'Medium', icon: Icons.flag_outlined),
                              _infoRow('Coverage Info', _formatCoverageInfo(complaint), icon: Icons.verified_user_outlined),
                              const Divider(height: 20),

                              // One-Tap Contact & Navigation Action Bar
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: complaint?['customer_phone']?.toString().isNotEmpty == true
                                          ? () => _makePhoneCall(complaint!['customer_phone'].toString())
                                          : null,
                                      icon: const Icon(Icons.phone_forwarded, size: 16),
                                      label: const Text('Call Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xff16a34a),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: complaint?['address']?.toString().isNotEmpty == true
                                          ? () => _openGoogleMaps(complaint!['address'].toString())
                                          : null,
                                      icon: const Icon(Icons.near_me, size: 16, color: Color(0xff1e3a8a)),
                                      label: const Text('Navigate (Maps)', style: TextStyle(color: Color(0xff1e3a8a), fontWeight: FontWeight.bold, fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        side: const BorderSide(color: Color(0xffbfdbfe)),
                                        backgroundColor: const Color(0xffeff6ff),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Service Report Details Form Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xffe2e8f0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Service Report Details',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xff1e3a8a),
                                    ),
                              ),
                              const SizedBox(height: 14),

                              TextField(
                                controller: _problemFoundController,
                                enabled: !isResolved,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Problem Found',
                                  hintText: 'Enter problem identified...',
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextField(
                                controller: _actionTakenController,
                                enabled: !isResolved,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Action Taken',
                                  hintText: 'Enter details of action taken...',
                                ),
                              ),
                              const SizedBox(height: 12),

                               Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      key: ValueKey('callType_$_callType'),
                                      isExpanded: true,
                                      initialValue: _callType,
                                      decoration: const InputDecoration(labelText: 'Call Type'),
                                      items: const [
                                        DropdownMenuItem(value: 'Charge Based', child: Text('Charge Based')),
                                        DropdownMenuItem(value: 'AMC', child: Text('AMC')),
                                        DropdownMenuItem(value: 'Warranty', child: Text('Warranty')),
                                      ],
                                      onChanged: isResolved
                                          ? null
                                          : (val) => setState(() => _callType = val ?? 'Warranty'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      key: ValueKey('solvedThrough_$_solvedThrough'),
                                      isExpanded: true,
                                      initialValue: _solvedThrough,
                                      decoration: const InputDecoration(labelText: 'Solved Through'),
                                      items: const [
                                        DropdownMenuItem(value: 'On-Site', child: Text('On-Site')),
                                        DropdownMenuItem(value: 'Remote', child: Text('Remote')),
                                        DropdownMenuItem(value: 'In-Office', child: Text('In-Office')),
                                      ],
                                      onChanged: isResolved
                                          ? null
                                          : (val) => setState(() => _solvedThrough = val ?? 'On-Site'),
                                    ),
                                  ),
                                ],
                              ),

                              if (_callType == 'Charge Based' || _callType == 'AMC') ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _chargeAmountController,
                                  enabled: !isResolved,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: _callType == 'AMC' ? 'AMC Amount (₹)' : 'Charge Amount (₹) *',
                                    prefixText: '₹ ',
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),
                              TextField(
                                controller: _spareNameController,
                                enabled: !isResolved,
                                decoration: const InputDecoration(
                                  labelText: 'Spare Part Name (if replaced)',
                                  hintText: 'e.g. Motherboard, RAM',
                                ),
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _spareOldSeriesController,
                                      enabled: !isResolved,
                                      decoration: const InputDecoration(labelText: 'Old Series No'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _spareNewSeriesController,
                                      enabled: !isResolved,
                                      decoration: const InputDecoration(labelText: 'New Series No'),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 10),

                              // Customer Signature Upload Widget
                              const Text(
                                'Customer Signature & Seal',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff0f172a)),
                              ),
                              const SizedBox(height: 6),
                              SignatureUploadWidget(
                                signatureBase64: _customerSignature,
                                readOnly: isResolved,
                                onSignatureChanged: (sig) {
                                  setState(() => _customerSignature = sig);
                                },
                              ),

                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 10),

                              // Service Engineer Signature Upload Widget
                              const Text(
                                'Service Engineer Signature',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff1e3a8a)),
                              ),
                              const SizedBox(height: 6),
                              SignatureUploadWidget(
                                label: 'Service Engineer Signature (Draw / Upload)',
                                signatureBase64: _engineerSignature,
                                readOnly: isResolved,
                                onSignatureChanged: (sig) {
                                  setState(() => _engineerSignature = sig);
                                },
                              ),

                              const SizedBox(height: 16),
                              if (!isResolved)
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: FilledButton.icon(
                                    onPressed: !_canEdit || _saving ? null : () => _updateStatus(complaint?['status'] ?? 'Ongoing'),
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    label: Text(_saving ? 'Saving...' : 'Save Work Details & Signature'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Troubleshooting Timeline / Remarks Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xffe2e8f0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Troubleshooting Timeline',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xff1e3a8a),
                                    ),
                              ),
                              const SizedBox(height: 12),
                              if (remarks.isEmpty)
                                const Text('No timeline logs found.', style: TextStyle(color: Colors.grey, fontSize: 13))
                              else
                                ...remarks.map((r) {
                                  final item = Map<String, dynamic>.from(r as Map);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xfff8fafc),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xffe2e8f0)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item['username']?.toString() ?? 'User',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              Text(
                                                item['created_at'] != null
                                                    ? item['created_at'].toString().split('T').first
                                                    : '',
                                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item['remark']?.toString() ?? '',
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),

                              if (!isResolved) ...[
                                const Divider(height: 24),
                                const Text('Add Progress Remark', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _newRemarkController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter diagnostic/repair steps completed...',
                                  ),
                                ),
                                CheckboxListTile(
                                  value: _markResolved,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (val) => setState(() => _markResolved = val ?? false),
                                  title: const Text('Mark call resolved / completed', style: TextStyle(fontSize: 13)),
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: !_canEdit || _saving ? null : _addRemark,
                                    child: const Text('Submit Remark'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Assigned Technicians Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xffe2e8f0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assigned Technicians',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xff1e3a8a),
                                    ),
                              ),
                              const SizedBox(height: 10),
                              if (team.isEmpty)
                                const Text('No technician assignment found.', style: TextStyle(color: Colors.grey, fontSize: 13))
                              else
                                ...team.map((t) {
                                  final tech = Map<String, dynamic>.from(t as Map);
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xffe8efff),
                                      child: Icon(Icons.person, color: Color(0xff2457d6)),
                                    ),
                                    title: Text(tech['name']?.toString() ?? 'Technician', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(tech['assignment_type']?.toString() ?? 'Assigned'),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Assignment & Status History Card
                      if (statusHistory.isNotEmpty || assignmentHistory.isNotEmpty)
                        Builder(builder: (context) {
                          final List<Map<String, dynamic>> combined = [];

                          for (final a in assignmentHistory) {
                            final item = Map<String, dynamic>.from(a as Map);
                            final rawTime = item['assigned_at']?.toString();
                            DateTime dt = DateTime.now();
                            if (rawTime != null && rawTime.isNotEmpty) {
                              dt = DateTime.tryParse(rawTime)?.toLocal() ?? DateTime.now();
                            }
                            final isRemoved = item['status'] == 'REMOVED';
                            final isInitial = item['assignment_type'] == 'INITIAL';
                            final isAdded = item['assignment_type'] == 'ADDED';
                            final isReassigned = item['assignment_type'] == 'REASSIGNED';

                            final badge = isRemoved
                                ? 'Removed'
                                : (isInitial || (!isAdded && !isReassigned))
                                    ? 'Assigned'
                                    : isAdded
                                        ? 'Additional'
                                        : 'Reassigned';

                            final byUser = item['assigned_by_name']?.toString() ?? '';
                            final techName = item['technician_name']?.toString() ?? '';

                            final titleAction = isRemoved
                                ? 'Removed'
                                : isReassigned
                                    ? 'Reassigned to'
                                    : 'Assigned';
                            final title = '$titleAction $techName';

                            final day = dt.day.toString().padLeft(2, '0');
                            final month = dt.month.toString().padLeft(2, '0');
                            final year = dt.year;
                            final hour = dt.hour.toString().padLeft(2, '0');
                            final minute = dt.minute.toString().padLeft(2, '0');
                            final second = dt.second.toString().padLeft(2, '0');
                            final formatted = '$day/$month/$year, $hour:$minute:$second';

                            combined.add({
                              'id': 'assign-${item['id']}',
                              'badge': badge,
                              'title': title,
                              'subtitle': byUser.isNotEmpty ? 'by $byUser' : '',
                              'time': dt,
                              'formatted': formatted,
                              'badgeBg': isRemoved
                                  ? const Color(0xfffef2f2)
                                  : isReassigned
                                      ? const Color(0xfffffbeb)
                                      : const Color(0xffeff6ff),
                              'badgeColor': isRemoved
                                  ? const Color(0xffef4444)
                                  : isReassigned
                                      ? const Color(0xffb45309)
                                      : const Color(0xff1d4ed8),
                            });
                          }

                          for (final s in statusHistory) {
                            final item = Map<String, dynamic>.from(s as Map);
                            final rawTime = item['changed_time']?.toString();
                            DateTime dt = DateTime.now();
                            if (rawTime != null && rawTime.isNotEmpty) {
                              dt = DateTime.tryParse(rawTime)?.toLocal() ?? DateTime.now();
                            }
                            final newStatus = item['new_status']?.toString() ?? 'Pending';
                            final byUser = item['username']?.toString() ?? 'User';
                            final remarks = item['remarks']?.toString() ?? '';
                            final rescheduleDate = item['reschedule_date']?.toString();

                            final day = dt.day.toString().padLeft(2, '0');
                            final month = dt.month.toString().padLeft(2, '0');
                            final year = dt.year;
                            final hour = dt.hour.toString().padLeft(2, '0');
                            final minute = dt.minute.toString().padLeft(2, '0');
                            final second = dt.second.toString().padLeft(2, '0');
                            final formatted = '$day/$month/$year, $hour:$minute:$second';

                            String title = newStatus;
                            if (newStatus == 'Rescheduled') {
                              if (rescheduleDate != null && rescheduleDate.isNotEmpty) {
                                title = 'Rescheduled to ${rescheduleDate.split('T').first}';
                              } else {
                                title = 'Rescheduled';
                              }
                            }

                            combined.add({
                              'id': 'status-${item['id']}',
                              'badge': newStatus,
                              'title': title,
                              'subtitle': byUser.isNotEmpty ? 'by $byUser' : '',
                              'remarks': remarks,
                              'time': dt,
                              'formatted': formatted,
                              'badgeBg': newStatus == 'Resolved'
                                  ? const Color(0xfff0fdf4)
                                  : newStatus == 'Ongoing'
                                      ? const Color(0xfff0f9ff)
                                      : newStatus == 'Rescheduled'
                                          ? const Color(0xfffff7ed)
                                          : const Color(0xfff1f5f9),
                              'badgeColor': newStatus == 'Resolved'
                                  ? const Color(0xff15803d)
                                  : newStatus == 'Ongoing'
                                      ? const Color(0xff0369a1)
                                      : newStatus == 'Rescheduled'
                                          ? const Color(0xffc2410c)
                                          : const Color(0xff475569),
                            });
                          }

                          combined.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xffe2e8f0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status & Assignment History',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xff1e3a8a),
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...combined.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xfff8fafc),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xfff1f5f9)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: item['badgeBg'] as Color,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    item['badge'].toString(),
                                                    style: TextStyle(
                                                      color: item['badgeColor'] as Color,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    item['title'].toString(),
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  item['subtitle'].toString(),
                                                  style: const TextStyle(color: Color(0xff64748b), fontSize: 11.5),
                                                ),
                                                Text(
                                                  item['formatted'].toString(),
                                                  style: const TextStyle(color: Color(0xff3b82f6), fontSize: 11.5, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                            if (item['remarks'] != null && item['remarks'].toString().isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                item['remarks'].toString(),
                                                style: const TextStyle(color: Color(0xff334155), fontSize: 11.5, fontStyle: FontStyle.italic),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

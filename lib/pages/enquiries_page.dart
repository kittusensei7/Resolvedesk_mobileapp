import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../services/permission_access.dart';
import '../widgets/paradesk_shimmer.dart';

class EnquiriesPage extends StatefulWidget {
  const EnquiriesPage({super.key});

  @override
  State<EnquiriesPage> createState() => _EnquiriesPageState();
}

class _EnquiriesPageState extends State<EnquiriesPage> {
  PermissionAccess? _access;
  List<dynamic> _enquiries = [];
  bool _loading = true;
  String? _error;
  String _activeFilter = 'All'; // 'All', 'Dealer', 'User', 'In Progress', 'Closed'
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEnquiries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEnquiries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await PermissionAccess.load();
      if (!mounted) return;
      setState(() => _access = access);
      final dio = await ApiConfig.getDio();
      final response = await dio.get('/enquiries');
      if (mounted) {
        setState(() {
          _enquiries = List<dynamic>.from(response.data as List);
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data is Map ? e.response?.data['message']?.toString() : 'Failed to load enquiries';
        setState(() => _error = msg ?? 'Failed to load enquiries');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load enquiries');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _dealerCount => _enquiries.where((e) => (e['customer_type'] ?? '').toString().trim() == 'Dealer').length;
  int get _userCount => _enquiries.where((e) => (e['customer_type'] ?? '').toString().trim() == 'User').length;
  int get _inProgressCount => _enquiries.where((e) {
        final st = (e['status'] ?? '').toString().trim();
        return st == 'Assigned' || st == 'In Progress';
      }).length;
  int get _closedCount => _enquiries.where((e) {
        final st = (e['status'] ?? '').toString().trim();
        return st == 'Closed' || st == 'Closed - Won' || st == 'Sale Confirmed' || st == 'Resolved';
      }).length;

  List<dynamic> get _filteredEnquiries {
    return _enquiries.where((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final status = (map['status'] ?? 'New').toString().trim();
      final customerType = (map['customer_type'] ?? '').toString().trim();

      if (_activeFilter == 'Dealer' && customerType != 'Dealer') {
        return false;
      }
      if (_activeFilter == 'User' && customerType != 'User') {
        return false;
      }
      if (_activeFilter == 'In Progress' && (status != 'Assigned' && status != 'In Progress')) {
        return false;
      }
      if (_activeFilter == 'Closed' &&
          status != 'Closed' &&
          status != 'Closed - Won' &&
          status != 'Sale Confirmed' &&
          status != 'Resolved') {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final enqNo = (map['enquiry_number'] ?? '').toString().toLowerCase();
        final name = (map['contact_name'] ?? '').toString().toLowerCase();
        final phone = (map['phone'] ?? '').toString().toLowerCase();
        final company = (map['company_name'] ?? '').toString().toLowerCase();
        final details = (map['details'] ?? '').toString().toLowerCase();
        final custType = customerType.toLowerCase();

        return enqNo.contains(q) ||
            name.contains(q) ||
            phone.contains(q) ||
            company.contains(q) ||
            details.contains(q) ||
            custType.contains(q);
      }

      return true;
    }).toList();
  }

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

  String _formatDateTime(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '—';
    final str = value.toString().trim();
    try {
      final dt = DateTime.parse(str.contains('T') ? str : '${str}T00:00:00').toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = monthNames[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day $month $year, $hour:$minute $amPm';
    } catch (_) {
      return str.split('T').first;
    }
  }

  Widget _buildCustomerTypeBadge(String? type, {bool large = false}) {
    if (type == null || type.trim().isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 9 : 7, vertical: large ? 4 : 2),
        decoration: BoxDecoration(
          color: const Color(0xfff8fafc),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xffcbd5e1)),
        ),
        child: Text(
          'Legacy',
          style: TextStyle(
            fontSize: large ? 11 : 10,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            color: const Color(0xff64748b),
          ),
        ),
      );
    }

    final isDealer = type.trim() == 'Dealer';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 9 : 7, vertical: large ? 4 : 2.5),
      decoration: BoxDecoration(
        color: isDealer ? const Color(0xfffef3c7) : const Color(0xffeff6ff),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDealer ? const Color(0xfffde68a) : const Color(0xffbfdbfe),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDealer ? Icons.storefront_outlined : Icons.person_outline_rounded,
            size: large ? 13 : 11,
            color: isDealer ? const Color(0xff92400e) : const Color(0xff1e40af),
          ),
          const SizedBox(width: 4),
          Text(
            isDealer ? 'Dealer' : 'User',
            style: TextStyle(
              fontSize: large ? 11.5 : 10.5,
              fontWeight: FontWeight.bold,
              color: isDealer ? const Color(0xff92400e) : const Color(0xff1e40af),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, {bool large = false}) {
    final st = status.trim();
    final isWonOrClosed = st == 'Closed' || st == 'Closed - Won' || st == 'Sale Confirmed' || st == 'Resolved';
    final isInProgress = st == 'Assigned' || st == 'In Progress';
    final isPostponed = st == 'Postponed';

    Color bg;
    Color textColor;
    Color border;

    if (isWonOrClosed) {
      bg = const Color(0xffecfdf5);
      textColor = const Color(0xff059669);
      border = const Color(0xffa7f3d0);
    } else if (isInProgress) {
      bg = const Color(0xffeff6ff);
      textColor = const Color(0xff1d4ed8);
      border = const Color(0xffbfdbfe);
    } else if (isPostponed) {
      bg = const Color(0xfffef3c7);
      textColor = const Color(0xffb45309);
      border = const Color(0xfffde68a);
    } else {
      bg = const Color(0xfff1f5f9);
      textColor = const Color(0xff475569);
      border = const Color(0xffcbd5e1);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 10 : 8, vertical: large ? 4 : 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(large ? 10 : 8),
        border: Border.all(color: border),
      ),
      child: Text(
        st,
        style: TextStyle(
          fontSize: large ? 12 : 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  void _showEnquiryDetailsModal(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'New';
    final createdDateStr = _formatDateTime(item['created_at']);
    final phone = (item['phone'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet Header handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xffcbd5e1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['enquiry_number']?.toString() ?? 'Enquiry Details',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff0f172a)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Logged on $createdDateStr',
                          style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xff64748b)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _buildCustomerTypeBadge(item['customer_type']?.toString(), large: true),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status, large: true),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  children: [
                    // Customer & Contact Info Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xfff8fafc),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xffe2e8f0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xffe2e8f0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.person_rounded, color: Color(0xff475569), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['contact_name']?.toString() ?? 'Contact Person',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xff0f172a)),
                                    ),
                                    if (item['company_name'] != null && item['company_name'].toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        item['company_name'].toString(),
                                        style: const TextStyle(color: Color(0xff64748b), fontSize: 13),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: Color(0xffe2e8f0)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.phone_rounded, size: 16, color: Color(0xff059669)),
                                  const SizedBox(width: 6),
                                  Text(
                                    phone.isNotEmpty ? phone : 'No phone provided',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff0f172a)),
                                  ),
                                ],
                              ),
                              if (phone.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () => _makePhoneCall(phone),
                                  icon: const Icon(Icons.call_rounded, size: 15, color: Colors.white),
                                  label: const Text('Call', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xff059669),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Enquiry Details Box
                    const Text(
                      'Enquiry Details / Requirements:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff334155)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xfff8fafc),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xffe2e8f0)),
                      ),
                      child: Text(
                        item['details']?.toString() ?? '',
                        style: const TextStyle(fontSize: 13.5, color: Color(0xff1e293b), height: 1.45),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sales Assignment & Resolution (if available)
                    if (item['assigned_sales_name'] != null || item['remarks'] != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xffecfdf5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xffa7f3d0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item['assigned_sales_name'] != null) ...[
                              Row(
                                children: [
                                  const Icon(Icons.support_agent_rounded, size: 16, color: Color(0xff065f46)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Assigned Sales: ${item['assigned_sales_name']}',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xff065f46)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (item['remarks'] != null && item['remarks'].toString().trim().isNotEmpty) ...[
                              Text(
                                'Sales Remarks: "${item['remarks']}"',
                                style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: Color(0xff065f46)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNewEnquiryBottomSheet() {
    final formKey = GlobalKey<FormState>();
    final contactController = TextEditingController();
    final phoneController = TextEditingController();
    final companyController = TextEditingController();
    final detailsController = TextEditingController();
    String? selectedCustomerType = 'Dealer';
    bool submitting = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xffcbd5e1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Log Customer Enquiry',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: Color(0xff0f172a),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Record field or customer inquiry details (Directly synced to Admin & Support)',
                                  style: TextStyle(fontSize: 12, color: Color(0xff64748b)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xff64748b)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (modalError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xfffef2f2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xfffecaca)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xffdc2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  modalError!,
                                  style: const TextStyle(color: Color(0xffdc2626), fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Contact Person Name
                      TextFormField(
                        controller: contactController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 14, color: Color(0xff0f172a)),
                        decoration: InputDecoration(
                          labelText: 'Contact Person Name *',
                          labelStyle: const TextStyle(color: Color(0xff475569)),
                          hintText: 'e.g. Ramesh Kumar',
                          hintStyle: const TextStyle(color: Color(0xff94a3b8)),
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xff64748b)),
                          filled: true,
                          fillColor: const Color(0xfff8fafc),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffe2e8f0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffe2e8f0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xff0284c7), width: 1.5)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Contact person name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Phone Number
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: const TextStyle(fontSize: 14, color: Color(0xff0f172a)),
                        decoration: InputDecoration(
                          labelText: 'Phone Number *',
                          labelStyle: const TextStyle(color: Color(0xff475569)),
                          hintText: 'e.g. 9876543210 (10 digits)',
                          hintStyle: const TextStyle(color: Color(0xff94a3b8)),
                          prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xff64748b)),
                          filled: true,
                          fillColor: const Color(0xfff8fafc),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffe2e8f0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffe2e8f0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xff0284c7), width: 1.5)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Phone number is required';
                          final cleaned = val.trim().replaceAll(RegExp(r'\D'), '');
                          if (cleaned.length != 10) return 'Phone number must be exactly 10 digits';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Company Name
                      TextFormField(
                        controller: companyController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 14, color: Color(0xff0f172a)),
                        decoration: InputDecoration(
                          labelText: 'Company / Business Name (Optional)',
                          labelStyle: const TextStyle(color: Color(0xff475569)),
                          hintText: 'e.g. Paramount Office Systems',
                          hintStyle: const TextStyle(color: Color(0xff94a3b8)),
                          prefixIcon: const Icon(Icons.business_outlined, color: Color(0xff64748b)),
                          filled: true,
                          fillColor: const Color(0xfff8fafc),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffe2e8f0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffe2e8f0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xff0284c7), width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Customer Type Interactive Selection
                      FormField<String>(
                        initialValue: selectedCustomerType,
                        validator: (val) {
                          if (selectedCustomerType == null || selectedCustomerType!.isEmpty) {
                            return 'Please select Customer Type (Dealer or User)';
                          }
                          return null;
                        },
                        builder: (fieldState) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Text(
                                    'Customer Type ',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xff1e293b)),
                                  ),
                                  Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  SizedBox(width: 6),
                                  Text(
                                    '(Tap to choose)',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xff64748b)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Dealer Option Card
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          selectedCustomerType = 'Dealer';
                                          fieldState.didChange('Dealer');
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: selectedCustomerType == 'Dealer' ? const Color(0xfffef3c7) : const Color(0xfff8fafc),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: selectedCustomerType == 'Dealer' ? const Color(0xffb45309) : const Color(0xffcbd5e1),
                                            width: selectedCustomerType == 'Dealer' ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: selectedCustomerType == 'Dealer' ? const Color(0xfffde68a) : const Color(0xffe2e8f0),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.storefront_outlined,
                                                size: 18,
                                                color: selectedCustomerType == 'Dealer' ? const Color(0xff92400e) : const Color(0xff64748b),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Dealer',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13.5,
                                                      color: selectedCustomerType == 'Dealer' ? const Color(0xff92400e) : const Color(0xff1e293b),
                                                    ),
                                                  ),
                                                  const Text(
                                                    'Trade / Reseller',
                                                    style: TextStyle(fontSize: 10, color: Color(0xff64748b)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (selectedCustomerType == 'Dealer')
                                              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xffb45309)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // User Option Card
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          selectedCustomerType = 'User';
                                          fieldState.didChange('User');
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: selectedCustomerType == 'User' ? const Color(0xffeff6ff) : const Color(0xfff8fafc),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: selectedCustomerType == 'User' ? const Color(0xff1d4ed8) : const Color(0xffcbd5e1),
                                            width: selectedCustomerType == 'User' ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: selectedCustomerType == 'User' ? const Color(0xffbfdbfe) : const Color(0xffe2e8f0),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.person_outline_rounded,
                                                size: 18,
                                                color: selectedCustomerType == 'User' ? const Color(0xff1e40af) : const Color(0xff64748b),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'User',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13.5,
                                                      color: selectedCustomerType == 'User' ? const Color(0xff1e40af) : const Color(0xff1e293b),
                                                    ),
                                                  ),
                                                  const Text(
                                                    'End Customer',
                                                    style: TextStyle(fontSize: 10, color: Color(0xff64748b)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (selectedCustomerType == 'User')
                                              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xff1d4ed8)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (fieldState.hasError) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    fieldState.errorText!,
                                    style: const TextStyle(color: Color(0xffdc2626), fontSize: 11.5, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Enquiry Details
                      TextFormField(
                        controller: detailsController,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 14, color: Color(0xff0f172a)),
                        decoration: InputDecoration(
                          labelText: 'Enquiry Details / Requirements *',
                          labelStyle: const TextStyle(color: Color(0xff475569)),
                          hintText: 'Describe machine model, requirement, or notes...',
                          hintStyle: const TextStyle(color: Color(0xff94a3b8)),
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: const Color(0xfff8fafc),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffe2e8f0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffe2e8f0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xff0284c7), width: 1.5)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enquiry details are required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff1e3a8a),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;

                                  setModalState(() {
                                    submitting = true;
                                    modalError = null;
                                  });

                                  try {
                                    final dio = await ApiConfig.getDio();
                                    await dio.post('/enquiries', data: {
                                      'contact_name': contactController.text.trim(),
                                      'phone': phoneController.text.trim(),
                                      'company_name': companyController.text.trim(),
                                      'customer_type': selectedCustomerType,
                                      'details': detailsController.text.trim(),
                                    });

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Enquiry submitted successfully! Reflected to Admin & Support.'),
                                          backgroundColor: Color(0xff059669),
                                        ),
                                      );
                                      _loadEnquiries();
                                    }
                                  } on DioException catch (err) {
                                    setModalState(() {
                                      submitting = false;
                                      modalError = err.response?.data is Map
                                          ? err.response?.data['message']?.toString()
                                          : 'Failed to submit enquiry';
                                    });
                                  } catch (err) {
                                    setModalState(() {
                                      submitting = false;
                                      modalError = 'Failed to submit enquiry';
                                    });
                                  }
                                },
                          child: submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Submit Enquiry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, {IconData? icon, int? count}) {
    final selected = _activeFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _activeFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff1e3a8a) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xff1e3a8a) : const Color(0xffe2e8f0),
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? const Color(0x201e3a8a) : const Color(0x04000000),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : const Color(0xff64748b),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xff334155),
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.22) : const Color(0xfff1f5f9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : const Color(0xff475569),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEnquiries;

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      floatingActionButton: !(_access?.can('enquiries', 'add') ?? false)
          ? null
          : FloatingActionButton.extended(
              onPressed: _showNewEnquiryBottomSheet,
              backgroundColor: const Color(0xff1e3a8a),
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New Enquiry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      body: Column(
        children: [
          // Technician Header Summary Card
          Container(
            color: const Color(0xfff8fafc),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Title & Refresh
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Customer Enquiries',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: Color(0xff0f172a),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Record and monitor customer inquiries & leads',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xff64748b)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xff64748b)),
                      onPressed: _loadEnquiries,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Top Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xffe2e8f0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x060f172a),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xffeff6ff),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Color(0xff1e3a8a)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MY LOGGED ENQUIRIES',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: Color(0xff1e3a8a),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_enquiries.length} Enquiries Recorded',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff0f172a),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Dealer & User quick badges
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xfffde68a)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_outlined, size: 12, color: Color(0xff92400e)),
                                const SizedBox(width: 4),
                                Text(
                                  '$_dealerCount',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xff92400e)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xffbfdbfe)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xff1e40af)),
                                const SizedBox(width: 4),
                                Text(
                                  '$_userCount',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xff1e40af)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Search Input
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
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 13.5, color: Color(0xff0f172a)),
                    decoration: InputDecoration(
                      hintText: 'Search contact, phone, company, or type...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xff94a3b8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xff64748b)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xff64748b)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xff0284c7), width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'All', count: _enquiries.length),
                      const SizedBox(width: 8),
                      _buildFilterChip('Dealer', 'Dealer', icon: Icons.storefront_outlined, count: _dealerCount),
                      const SizedBox(width: 8),
                      _buildFilterChip('User', 'User', icon: Icons.person_outline_rounded, count: _userCount),
                      const SizedBox(width: 8),
                      _buildFilterChip('In Progress', 'In Progress', icon: Icons.pending_actions_rounded, count: _inProgressCount),
                      const SizedBox(width: 8),
                      _buildFilterChip('Closed', 'Closed', icon: Icons.check_circle_outline_rounded, count: _closedCount),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xffe2e8f0)),

          // Main List View
          Expanded(
            child: _loading
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    children: const [
                      EnquiryCardSkeleton(),
                      EnquiryCardSkeleton(),
                      EnquiryCardSkeleton(),
                    ],
                  )
                : _error != null
                    ? Center(
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xfffef2f2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xfffecaca)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 36, color: Color(0xffef4444)),
                              const SizedBox(height: 8),
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xffb91c1c), fontWeight: FontWeight.w500)),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _loadEnquiries,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xffef4444),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xfff1f5f9),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.search_off_rounded, size: 28, color: Color(0xff64748b)),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _activeFilter != 'All' ? 'No $_activeFilter enquiries found' : 'No enquiries found',
                                    style: const TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Tap "+ New Enquiry" to record customer inquiries.', style: TextStyle(color: Color(0xff64748b), fontSize: 13)),
                                  const SizedBox(height: 16),
                                  if (_activeFilter != 'All' || _searchQuery.isNotEmpty)
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _activeFilter = 'All';
                                          _searchQuery = '';
                                          _searchController.clear();
                                        });
                                      },
                                      icon: const Icon(Icons.close_rounded, size: 16),
                                      label: const Text('Reset Filter & Show All'),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        side: const BorderSide(color: Color(0xffcbd5e1)),
                                      ),
                                    )
                                  else if (_access?.can('enquiries', 'add') ?? false)
                                    FilledButton.icon(
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        _showNewEnquiryBottomSheet();
                                      },
                                      icon: const Icon(Icons.add_rounded, size: 16),
                                      label: const Text('Create New Enquiry'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xff1e3a8a),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xff0284c7),
                            backgroundColor: Colors.white,
                            onRefresh: _loadEnquiries,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = Map<String, dynamic>.from(filtered[index] as Map);
                                final status = item['status']?.toString() ?? 'New';
                                final phone = (item['phone'] ?? '').toString();
                                final dateStr = _formatDateTime(item['created_at']);

                                return RepaintBoundary(
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
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
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () => _showEnquiryDetailsModal(item),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Top Row: Enquiry Number & Badges
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  item['enquiry_number']?.toString() ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13.5,
                                                    letterSpacing: -0.2,
                                                    color: Color(0xff0f172a),
                                                  ),
                                                ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildCustomerTypeBadge(item['customer_type']?.toString()),
                                                  const SizedBox(width: 6),
                                                  _buildStatusBadge(status),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),

                                          // Contact Name & Company
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(7),
                                                margin: const EdgeInsets.only(top: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xfff1f5f9),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.person_rounded, size: 16, color: Color(0xff475569)),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item['contact_name']?.toString() ?? '',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 15,
                                                        color: Color(0xff0f172a),
                                                      ),
                                                    ),
                                                    if (item['company_name'] != null && item['company_name'].toString().trim().isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        item['company_name'].toString(),
                                                        style: const TextStyle(color: Color(0xff64748b), fontSize: 12.5),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              // Direct Phone Action
                                              if (phone.isNotEmpty)
                                                InkWell(
                                                  borderRadius: BorderRadius.circular(10),
                                                  onTap: () => _makePhoneCall(phone),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xffecfdf5),
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(color: const Color(0xffa7f3d0)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.call_rounded, size: 12, color: Color(0xff059669)),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          phone,
                                                          style: const TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xff059669),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),

                                          // Details preview box
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                            decoration: BoxDecoration(
                                              color: const Color(0xfff8fafc),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xfff1f5f9)),
                                            ),
                                            child: Text(
                                              item['details']?.toString() ?? '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12.5, color: Color(0xff334155), height: 1.35),
                                            ),
                                          ),
                                          const SizedBox(height: 10),

                                          // Footer: Time and Assigned Sales
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.access_time_rounded, size: 13, color: Color(0xff94a3b8)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    dateStr,
                                                    style: const TextStyle(fontSize: 11.5, color: Color(0xff94a3b8), fontWeight: FontWeight.w500),
                                                  ),
                                                ],
                                              ),
                                              if (item['assigned_sales_name'] != null)
                                                Row(
                                                  children: [
                                                    const Icon(Icons.support_agent_rounded, size: 14, color: Color(0xff059669)),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'Sales: ${item['assigned_sales_name']}',
                                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xff059669)),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(duration: 180.ms).slideY(begin: 0.04, end: 0),
                              );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

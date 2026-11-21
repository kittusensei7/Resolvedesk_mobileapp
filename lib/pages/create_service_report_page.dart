import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../widgets/signature_upload_widget.dart';

class CreateServiceReportPage extends StatefulWidget {
  const CreateServiceReportPage({super.key, this.prefillComplaint, this.existingReport});

  final Map<String, dynamic>? prefillComplaint;
  final Map<String, dynamic>? existingReport;

  @override
  State<CreateServiceReportPage> createState() => _CreateServiceReportPageState();
}

class _CreateServiceReportPageState extends State<CreateServiceReportPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _loadingComplaints = true;
  String? _error;

  List<dynamic> _completedComplaints = [];
  Map<String, dynamic>? _selectedComplaint;

  final _serviceEngineerController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _productController = TextEditingController();
  final _complaintController = TextEditingController();
  final _calledDateController = TextEditingController();
  final _respondedDateController = TextEditingController();
  final _problemFoundController = TextEditingController();
  final _actionTakenController = TextEditingController();
  final _sparesDetailsController = TextEditingController();
  final _spareNameController = TextEditingController();
  final _spareOldSeriesController = TextEditingController();
  final _spareNewSeriesController = TextEditingController();
  final _chargeAmountController = TextEditingController();
  final _remarksController = TextEditingController();

  String _callType = 'Warranty';
  String _solvedThrough = 'On-Site';
  String _customerSignature = '';
  String _engineerSignature = '';
  final String _reportDate = DateTime.now().toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    if (widget.existingReport != null) {
      _applyExistingReport(widget.existingReport!);
    } else {
      _loadCompletedComplaints();
    }
  }

  void _applyExistingReport(Map<String, dynamic> report) {
    setState(() {
      _serviceEngineerController.text = report['service_engineer_name']?.toString() ?? '';
      _customerNameController.text = report['customer_name']?.toString() ?? '';
      _addressController.text = report['address']?.toString() ?? '';
      _productController.text = report['product']?.toString() ?? '';
      _complaintController.text = report['complaint']?.toString() ?? '';
      _calledDateController.text = report['called_date']?.toString().split('T').first ?? '';
      _respondedDateController.text = report['responded_date']?.toString().split('T').first ?? '';
      _problemFoundController.text = report['problem_found']?.toString() ?? '';
      _actionTakenController.text = report['action_taken']?.toString() ?? '';
      _sparesDetailsController.text = report['spares_details']?.toString() ?? '';
      _spareNameController.text = report['spare_name']?.toString() ?? '';
      _spareOldSeriesController.text = report['spare_old_series']?.toString() ?? '';
      _spareNewSeriesController.text = report['spare_new_series']?.toString() ?? '';
      _chargeAmountController.text = report['charge_amount']?.toString() ?? '';
      _remarksController.text = report['customer_remark']?.toString() ?? report['suggestions']?.toString() ?? '';
      _customerSignature = report['customer_signature']?.toString() ?? report['customerSignature']?.toString() ?? '';
      _engineerSignature = report['engineer_signature']?.toString() ?? report['engineerSignature']?.toString() ?? '';

      final callTypeVal = report['call_type']?.toString();
      if (callTypeVal != null && callTypeVal.isNotEmpty) {
        _callType = callTypeVal;
      }
      final solvedThroughVal = report['solved_through']?.toString() ?? report['solvedThrough']?.toString();
      if (solvedThroughVal != null && solvedThroughVal.isNotEmpty) {
        _solvedThrough = solvedThroughVal;
      }
      _loadingComplaints = false;
    });
  }

  @override
  void dispose() {
    _serviceEngineerController.dispose();
    _customerNameController.dispose();
    _addressController.dispose();
    _productController.dispose();
    _complaintController.dispose();
    _calledDateController.dispose();
    _respondedDateController.dispose();
    _problemFoundController.dispose();
    _actionTakenController.dispose();
    _sparesDetailsController.dispose();
    _spareNameController.dispose();
    _spareOldSeriesController.dispose();
    _spareNewSeriesController.dispose();
    _chargeAmountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadCompletedComplaints() async {
    try {
      final dio = await ApiConfig.getDio();
      final response = await dio.get('/service-call-reports/completed-complaints');
      final list = List<dynamic>.from(response.data as List);
      final seenIds = <int>{};
      final uniqueList = list.where((item) {
        if (item is Map && item['id'] != null) {
          final id = int.tryParse(item['id'].toString());
          if (id != null) {
            if (seenIds.contains(id)) return false;
            seenIds.add(id);
          }
        }
        return true;
      }).toList();
      setState(() {
        _completedComplaints = uniqueList;
        _loadingComplaints = false;
      });

      if (widget.prefillComplaint != null) {
        _applyComplaint(widget.prefillComplaint!);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingComplaints = false);
    }
  }

  void _applyComplaint(Map<String, dynamic> comp) {
    setState(() {
      _selectedComplaint = comp;
      _customerNameController.text = comp['customer_name']?.toString() ?? '';
      _addressController.text = comp['address']?.toString() ?? '';
      
      final product = comp['product']?.toString() ?? '';
      final model = comp['model']?.toString() ?? '';
      _productController.text = model.isEmpty ? product : '$product / $model';

      final category = comp['category']?.toString() ?? '';
      final desc = comp['description']?.toString() ?? '';
      _complaintController.text = category.isEmpty ? desc : '$category — $desc';

      if (comp['called_date'] != null) {
        _calledDateController.text = comp['called_date'].toString().split('T').first;
      }
      if (comp['responded_date'] != null) {
        _respondedDateController.text = comp['responded_date'].toString().split('T').first;
      } else {
        _respondedDateController.text = _reportDate;
      }

      _problemFoundController.text = comp['problem_found']?.toString() ?? '';
      _actionTakenController.text = comp['action_taken']?.toString() ?? '';
      _spareNameController.text = comp['spare_name']?.toString() ?? '';
      _spareOldSeriesController.text = comp['spare_old_series']?.toString() ?? '';
      _chargeAmountController.text = comp['charge_amount']?.toString() ?? comp['chargeAmount']?.toString() ?? '';
      _serviceEngineerController.text = comp['service_engineer_name']?.toString() ?? '';
      _customerSignature = comp['customer_signature']?.toString() ?? comp['customerSignature']?.toString() ?? '';
      _engineerSignature = comp['engineer_signature']?.toString() ?? comp['engineerSignature']?.toString() ?? '';

      final callTypeVal = comp['coverage_type']?.toString() ?? comp['coverageType']?.toString() ?? comp['call_type']?.toString() ?? comp['callType']?.toString();
      if (callTypeVal != null && callTypeVal.isNotEmpty) {
        _callType = callTypeVal;
      } else if (comp['amc_from'] != null || comp['amc_to'] != null || comp['amcFrom'] != null || comp['amcTo'] != null) {
        _callType = 'AMC';
      }
      final solvedThroughVal = comp['solved_through']?.toString() ?? comp['solvedThrough']?.toString();
      if (solvedThroughVal != null && solvedThroughVal.isNotEmpty) {
        _solvedThrough = solvedThroughVal;
      }

      String spares = '';
      if (comp['spare_name'] != null || comp['spare_old_series'] != null) {
        spares = '${comp['spare_name'] ?? ''} (Old: ${comp['spare_old_series'] ?? '—'} | New: ${comp['spare_new_series'] ?? '—'})';
      }
      _sparesDetailsController.text = spares;
    });
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    final isEditing = widget.existingReport != null;

    if (!isEditing && _selectedComplaint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a completed complaint reference.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = await ApiConfig.getDio();
      final payload = {
        'complaintId': isEditing ? widget.existingReport!['complaint_id'] : _selectedComplaint!['id'],
        'serviceEngineerName': _serviceEngineerController.text.trim(),
        'reportDate': _reportDate,
        'customerName': _customerNameController.text.trim(),
        'address': _addressController.text.trim(),
        'product': _productController.text.trim(),
        'complaint': _complaintController.text.trim(),
        'calledDate': _calledDateController.text.trim(),
        'respondedDate': _respondedDateController.text.trim(),
        'problemFound': _problemFoundController.text.trim(),
        'actionTaken': _actionTakenController.text.trim(),
        'sparesDetails': _sparesDetailsController.text.trim(),
        'spareName': _spareNameController.text.trim(),
        'spareOldSeries': _spareOldSeriesController.text.trim(),
        'spareNewSeries': _spareNewSeriesController.text.trim(),
        'callType': _callType,
        'solvedThrough': _solvedThrough,
        'suggestions': '',
        'customerRemark': _remarksController.text.trim(),
        'customerSignature': _customerSignature,
        'engineerSignature': _engineerSignature,
        'chargeAmount': ['AMC', 'Charge Based'].contains(_callType) ? _chargeAmountController.text.trim() : null,
      };

      if (isEditing) {
        await dio.put('/service-call-reports/${widget.existingReport!['id']}', data: payload);
      } else {
        await dio.post('/service-call-reports', data: payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? 'Service Call Report updated successfully.' : 'Service Call Report saved successfully.')),
      );
      Navigator.pop(context, true);
    } on DioException catch (error) {
      if (mounted) {
        final msg = error.response?.data is Map ? error.response?.data['message']?.toString() : 'Failed to save report';
        setState(() => _error = msg ?? 'Failed to save report.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingReport != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Service Call Report' : 'Service Call Report', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: _loadingComplaints
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Page Title Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xffe0e7ff),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isEditing ? 'EDIT MODE' : 'SERVICE REPORT WORKSHEET',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xff3730a3)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEditing ? 'Update service details, remarks, or customer signature' : 'Create Service Call Report',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff0f172a)),
                  ),
                  const SizedBox(height: 16),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xfffef2f2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xfffca5a5)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Color(0xffb91c1c), fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Complaint Reference Search Card (Only for creation)
                  if (!isEditing)
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
                            const Text(
                              'Select Completed Complaint Reference *',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff1e3a8a)),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Search by Customer/Company name, Complaint no, or Product.',
                              style: TextStyle(fontSize: 11, color: Color(0xff64748b)),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: _selectedComplaint?['id'] as int?,
                              decoration: const InputDecoration(
                                hintText: 'Type to search company name, complaint no, product...',
                              ),
                              items: _completedComplaints.map((c) {
                                final item = Map<String, dynamic>.from(c as Map);
                                final id = item['id'] as int;
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(
                                    '${item['complaint_number'] ?? '#$id'} — ${item['customer_name']}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }).toList(),
                              onChanged: (selectedId) {
                                if (selectedId != null) {
                                  final found = _completedComplaints.firstWhere(
                                    (c) => c['id'] == selectedId,
                                    orElse: () => null,
                                  );
                                  if (found != null) {
                                    _applyComplaint(Map<String, dynamic>.from(found as Map));
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!isEditing) const SizedBox(height: 16),

                  // General & Customer Details Card
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
                          const Text(
                            'General & Customer Details',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff0f172a)),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _serviceEngineerController,
                                  decoration: const InputDecoration(
                                    labelText: 'Name of Service Engineer',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _reportDate,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Report Date',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _customerNameController,
                            decoration: const InputDecoration(
                              labelText: 'Customer Name *',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _addressController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _productController,
                            decoration: const InputDecoration(
                              labelText: 'Product',
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _complaintController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Complaint details (Hardware/Software category + Description)',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Service & Action Details Card
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
                          const Text(
                            'Service & Action Details',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff0f172a)),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _calledDateController,
                                  decoration: const InputDecoration(
                                    labelText: 'Called Date',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _respondedDateController,
                                  decoration: const InputDecoration(
                                    labelText: 'Responded Date',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _problemFoundController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Problems Found',
                              hintText: 'Enter problems identified',
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _actionTakenController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Action Taken',
                              hintText: 'Enter actions taken',
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _spareNameController,
                            decoration: const InputDecoration(
                              labelText: 'Spare Part Name (if replaced)',
                              hintText: 'e.g. Motherboard, RAM, etc.',
                            ),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _spareOldSeriesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Old Series No',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _spareNewSeriesController,
                                  decoration: const InputDecoration(
                                    labelText: 'New Series No',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  key: ValueKey('callType_$_callType'),
                                  initialValue: _callType,
                                  decoration: const InputDecoration(
                                    labelText: 'Call Type',
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Warranty', child: Text('Warranty')),
                                    DropdownMenuItem(value: 'AMC', child: Text('AMC')),
                                    DropdownMenuItem(value: 'Charge Based', child: Text('Charge Based')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _callType = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  key: ValueKey('solvedThrough_$_solvedThrough'),
                                  initialValue: _solvedThrough,
                                  decoration: const InputDecoration(
                                    labelText: 'Solved Through',
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'On-Site', child: Text('On-Site')),
                                    DropdownMenuItem(value: 'Remote', child: Text('Remote')),
                                    DropdownMenuItem(value: 'In-Office', child: Text('In-Office')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _solvedThrough = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_callType == 'Charge Based' || _callType == 'AMC') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _chargeAmountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _callType == 'AMC' ? 'AMC Amount (₹)' : 'Charge Amount (₹) *',
                              ),
                              validator: (v) => _callType == 'Charge Based' && (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ],
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _remarksController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Remarks / Customer Feedback',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer Signature Card
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
                          const Text(
                            'Customer Signature & Seal',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff0f172a)),
                          ),
                          const SizedBox(height: 8),
                          SignatureUploadWidget(
                            signatureBase64: _customerSignature,
                            onSignatureChanged: (sig) {
                              setState(() => _customerSignature = sig);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Service Engineer Signature Card
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
                          const Text(
                            'Service Engineer Signature',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff1e3a8a)),
                          ),
                          const SizedBox(height: 8),
                          SignatureUploadWidget(
                            label: 'Service Engineer Signature (Draw / Upload)',
                            signatureBase64: _engineerSignature,
                            onSignatureChanged: (sig) {
                              setState(() => _engineerSignature = sig);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  FilledButton(
                    onPressed: _loading ? null : _submitReport,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            isEditing ? 'Update Service Call Report' : 'Save Service Call Report',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

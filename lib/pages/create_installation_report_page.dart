import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/pdf_report_service.dart';
import '../widgets/signature_upload_widget.dart';

class ContactItem {
  ContactItem({this.name = '', this.phone = '', this.email = ''});

  String name;
  String phone;
  String email;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'email': email};
}

class CreateInstallationReportPage extends StatefulWidget {
  const CreateInstallationReportPage({super.key, this.prefillComplaint, this.editingReport});

  final Map<String, dynamic>? prefillComplaint;
  final Map<String, dynamic>? editingReport;

  @override
  State<CreateInstallationReportPage> createState() => _CreateInstallationReportPageState();
}

class _CreateInstallationReportPageState extends State<CreateInstallationReportPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  final _customerController = TextEditingController();
  final List<ContactItem> _contacts = [ContactItem()];
  final _productController = TextEditingController();
  final _completedController = TextEditingController();
  final _installerController = TextEditingController();
  final _suggestionsController = TextEditingController();

  String _status = 'Pending';
  String _installationDate = DateTime.now().toIso8601String().split('T').first;
  String _customerSignature = '';

  @override
  void initState() {
    super.initState();
    if (widget.editingReport != null) {
      final rep = widget.editingReport!;
      _customerController.text = rep['customer_name_address']?.toString() ?? '';
      _productController.text = rep['product_name']?.toString() ?? '';
      _completedController.text = rep['installation_completed']?.toString() ?? '';
      _installerController.text = rep['installer_name']?.toString() ?? '';
      _suggestionsController.text = rep['suggestions']?.toString() ?? '';
      _status = rep['status']?.toString() ?? 'Pending';
      if (rep['installation_date'] != null && rep['installation_date'].toString().isNotEmpty) {
        _installationDate = rep['installation_date'].toString().split('T').first;
      }
      _customerSignature = rep['customer_signature']?.toString() ?? rep['customerSignature']?.toString() ?? '';

      final parsedContacts = PdfReportService.parseContacts(rep['contact_person']?.toString());
      if (parsedContacts.isNotEmpty) {
        _contacts.clear();
        for (final c in parsedContacts) {
          _contacts.add(ContactItem(
            name: c['name'] ?? '',
            phone: c['phone'] ?? '',
            email: c['email'] ?? '',
          ));
        }
      }
    } else if (widget.prefillComplaint != null) {
      final comp = widget.prefillComplaint!;
      _customerController.text = '${comp['customer_name'] ?? ''}\n${comp['address'] ?? ''}'.trim();
      _contacts[0].phone = comp['customer_phone']?.toString() ?? '';
      _contacts[0].email = comp['customer_email']?.toString() ?? '';
      final p = comp['product']?.toString() ?? '';
      final m = comp['model']?.toString() ?? '';
      _productController.text = m.isEmpty ? p : '$p / $m';
      _completedController.text = comp['description']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _customerController.dispose();
    _productController.dispose();
    _completedController.dispose();
    _installerController.dispose();
    _suggestionsController.dispose();
    super.dispose();
  }

  void _addContact() {
    setState(() {
      _contacts.add(ContactItem());
    });
  }

  void _removeContact(int index) {
    if (_contacts.length > 1) {
      setState(() {
        _contacts.removeAt(index);
      });
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    for (int i = 0; i < _contacts.length; i++) {
      final phone = _contacts[i].phone.trim();
      if (phone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(phone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact Person #${i + 1} phone number must be exactly 10 digits.')),
        );
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = await ApiConfig.getDio();
      final contactsFormatted = _contacts.map((c) => c.toJson()).toList();

      final payload = {
        'customer_name_address': _customerController.text.trim(),
        'contact_person': contactsFormatted,
        'product_name': _productController.text.trim(),
        'installation_completed': _completedController.text.trim(),
        'installer_name': _installerController.text.trim(),
        'suggestions': _suggestionsController.text.trim(),
        'status': _status,
        'installation_date': _installationDate,
        'customer_signature': _customerSignature,
      };

      if (widget.editingReport != null) {
        final id = widget.editingReport!['id'];
        await dio.put(
          '/installation-reports/$id',
          data: payload,
        );
      } else {
        await dio.post(
          '/installation-reports',
          data: payload,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.editingReport != null ? 'Installation Report updated successfully.' : 'Installation Report saved successfully.'),
          backgroundColor: const Color(0xff059669),
        ),
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
    final isEditing = widget.editingReport != null;
    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Installation Report' : 'Installation Report',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xff0f172a)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff0f172a),
        elevation: 0.5,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
          children: [
            // Page Title Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xffe0e7ff),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'FORM AREA',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xff3730a3)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isEditing ? 'Edit Installation Report' : 'New Installation Report',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: Color(0xff0f172a),
              ),
            ),
            const SizedBox(height: 16),

            // Card 1: Company Particulars
            Container(
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
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Company Particulars',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xff1e3a8a),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _customerController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14, color: Color(0xff0f172a)),
                    decoration: const InputDecoration(
                      labelText: 'Company Name & Address *',
                      labelStyle: TextStyle(color: Color(0xff475569)),
                      hintText: 'Enter full company name and address...',
                      hintStyle: TextStyle(color: Color(0xff94a3b8)),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Company Name & Address is required' : null,
                  ),
                  const SizedBox(height: 18),

                  // Dynamic Contacts List
                  const Text(
                    'Contact Persons',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff334155)),
                  ),
                  const SizedBox(height: 10),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _contacts.length,
                    separatorBuilder: (_, _) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xfff1f5f9)),
                    ),
                    itemBuilder: (context, idx) {
                      final contact = _contacts[idx];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Contact Name ${idx + 1}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff64748b)),
                              ),
                              if (_contacts.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 18),
                                  onPressed: () => _removeContact(idx),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: contact.name,
                            onChanged: (val) => contact.name = val,
                            style: const TextStyle(fontSize: 14, color: Color(0xff0f172a)),
                            decoration: const InputDecoration(
                              labelText: 'Contact Name',
                              labelStyle: TextStyle(color: Color(0xff475569)),
                              hintText: 'Enter contact person name',
                              hintStyle: TextStyle(color: Color(0xff94a3b8)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: contact.phone,
                                  maxLength: 10,
                                  keyboardType: TextInputType.phone,
                                  onChanged: (val) => contact.phone = val,
                                  style: const TextStyle(fontSize: 14, color: Color(0xff0f172a)),
                                  decoration: const InputDecoration(
                                    labelText: 'Phone (10 Digits)',
                                    labelStyle: TextStyle(color: Color(0xff475569)),
                                    hintText: '10 digits',
                                    hintStyle: TextStyle(color: Color(0xff94a3b8)),
                                    counterText: '',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  initialValue: contact.email,
                                  keyboardType: TextInputType.emailAddress,
                                  onChanged: (val) => contact.email = val,
                                  style: const TextStyle(fontSize: 14, color: Color(0xff0f172a)),
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    labelStyle: TextStyle(color: Color(0xff475569)),
                                    hintText: 'Optional email',
                                    hintStyle: TextStyle(color: Color(0xff94a3b8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addContact,
                    icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xff1e3a8a)),
                    label: const Text('+ Add Another Contact', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xff1e3a8a))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xffcbd5e1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Card 2: Product Particulars
            Container(
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
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Particulars',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xff1e3a8a),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _productController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14, color: Color(0xff0f172a)),
                    decoration: const InputDecoration(
                      labelText: 'Product Name (Hardware/Software, Model, Qty, Serial Numbers) *',
                      labelStyle: TextStyle(color: Color(0xff475569)),
                      hintText: 'Enter product details, model numbers, serial numbers...',
                      hintStyle: TextStyle(color: Color(0xff94a3b8)),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Product Particulars are required' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _completedController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14, color: Color(0xff0f172a)),
                    decoration: const InputDecoration(
                      labelText: 'Installation Completed (Details of tasks done, configuration etc.)',
                      labelStyle: TextStyle(color: Color(0xff475569)),
                      hintText: 'Describe installation activities completed...',
                      hintStyle: TextStyle(color: Color(0xff94a3b8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Card 3: Installation Particulars
            Container(
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
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Installation Particulars',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xff1e3a8a),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Installation Date',
                            labelStyle: TextStyle(color: Color(0xff475569)),
                            prefixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xff64748b)),
                          ),
                          child: Text(_installationDate, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            labelStyle: TextStyle(color: Color(0xff475569)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                            DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                          ],
                          onChanged: (val) => setState(() => _status = val ?? 'Pending'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _installerController,
                    style: const TextStyle(fontSize: 14, color: Color(0xff0f172a)),
                    decoration: const InputDecoration(
                      labelText: 'Installer Name',
                      labelStyle: TextStyle(color: Color(0xff475569)),
                      hintText: 'Service technician / engineer name',
                      hintStyle: TextStyle(color: Color(0xff94a3b8)),
                      prefixIcon: Icon(Icons.engineering_outlined, color: Color(0xff64748b)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _suggestionsController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14, color: Color(0xff0f172a)),
                    decoration: const InputDecoration(
                      labelText: 'Suggestions / Customer Feedback',
                      labelStyle: TextStyle(color: Color(0xff475569)),
                      hintText: 'Enter customer feedback or recommendations...',
                      hintStyle: TextStyle(color: Color(0xff94a3b8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Card 4: Customer Signature
            Container(
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
              padding: const EdgeInsets.all(18),
              child: SignatureUploadWidget(
                label: "Customer Signature with Seal",
                signatureBase64: _customerSignature,
                onSignatureChanged: (sig) => setState(() => _customerSignature = sig),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfffef2f2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xfffecaca)),
                ),
                child: Text(_error!, style: const TextStyle(color: Color(0xffdc2626), fontSize: 13)),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _loading ? null : _submitReport,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 20),
                label: Text(
                  _loading ? 'Saving Report...' : 'Save Installation Report',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff1e3a8a),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

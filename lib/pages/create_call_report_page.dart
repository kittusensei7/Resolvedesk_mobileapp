import 'package:flutter/material.dart';

import '../models/call_report.dart';
import '../services/call_reports_service.dart';
import '../widgets/permission_guard.dart';

class CreateCallReportPage extends StatefulWidget {
  const CreateCallReportPage({
    super.key,
    this.editingReport,
    this.followUpFrom,
  });
  final CallReport? editingReport, followUpFrom;

  @override
  State<CreateCallReportPage> createState() => _CreateCallReportPageState();
}

class _CreateCallReportPageState extends State<CreateCallReportPage>
    with PermissionAware<CreateCallReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = const CallReportsService();
  final _fields = <String, TextEditingController>{};
  late DateTime _callDate;
  DateTime? _rescheduleDate;
  String _callType = 'Telephone', _prospect = 'No', _leadStatus = '';
  bool _saving = false;
  String? _error;

  @override
  String get permissionFeature => 'call_reports';
  String get _writeAction => widget.editingReport == null ? 'add' : 'edit';
  bool get _sameSession =>
      permissionSessionGeneration == permissions.generation;
  bool get _canWrite =>
      mounted &&
      _sameSession &&
      permissions.can(permissionFeature) &&
      permissions.can(permissionFeature, _writeAction);

  @override
  void initState() {
    super.initState();
    final report = widget.editingReport ?? widget.followUpFrom;
    final editing = widget.editingReport != null;
    final values = {
      'organizationName': report?.organizationName ?? '',
      'customerName': report?.customerName ?? '',
      'address': report?.address ?? '',
      'city': report?.city ?? '',
      'mobileNumber': report?.mobileNumber ?? '',
      'email': report?.email ?? '',
      'product': report?.product ?? '',
      'remarks': editing ? report?.remarks ?? '' : '',
    };
    for (final entry in values.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value);
    }
    _callDate = editing ? report?.callDate ?? DateTime.now() : DateTime.now();
    _callType = editing && report!.callType.isNotEmpty
        ? report.callType
        : 'Telephone';
    _rescheduleDate = editing ? report?.rescheduleDate : null;
    _prospect = report?.prospect == 'Yes' ? 'Yes' : 'No';
    _leadStatus = report?.leadStatus ?? '';
    bindPermissions();
    permissions.ensureFresh();
  }

  @override
  void clearProtectedData() {
    // A permission refresh must not erase a local draft. Another account must.
    if (!_sameSession) {
      for (final controller in _fields.values) {
        controller.clear();
      }
      _rescheduleDate = null;
      _error = null;
    }
  }

  @override
  Future<void> reloadProtectedData() => permissions.ensureFresh();

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  CallReportInput _input() => CallReportInput(
    callDate: _callDate,
    callType: _callType,
    organizationName: _fields['organizationName']!.text,
    customerName: _fields['customerName']!.text,
    address: _fields['address']!.text,
    city: _fields['city']!.text,
    mobileNumber: _fields['mobileNumber']!.text,
    email: _fields['email']!.text,
    product: _fields['product']!.text,
    remarks: _fields['remarks']!.text,
    rescheduleDate: _rescheduleDate,
    prospect: _prospect,
    leadStatus: _leadStatus,
  );

  Future<void> _save() async {
    if (_saving || _formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    final input = _input();
    final validation = input.validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (!await requirePermission(_writeAction) || !_canWrite) return;
      await _service.save(
        input,
        id: widget.editingReport?.id,
        allowed: () => _canWrite,
      );
      if (!mounted || !_sameSession || !permissions.can(permissionFeature)) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.editingReport == null
                ? 'Call report saved.'
                : 'Call report updated.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted && _sameSession) {
        setState(
          () => _error = CallReportsService.errorMessage(
            error,
            'Unable to confirm the save. Check the list before submitting again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate({bool reschedule = false}) async {
    if (!_canWrite || _saving) return;
    final today = DateUtils.dateOnly(DateTime.now());
    final current = reschedule ? _rescheduleDate ?? today : _callDate;
    final first = reschedule ? today : DateTime(1900);
    final last = DateTime(2100, 12, 31);
    final initial = current.isBefore(first)
        ? first
        : current.isAfter(last)
        ? last
        : current;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: reschedule ? 'Reschedule date' : 'Call date',
    );
    if (picked == null || !_canWrite || _saving) return;
    setState(() {
      if (reschedule) {
        _rescheduleDate = picked;
      } else {
        _callDate = picked;
      }
    });
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _field(
    String key,
    String label, {
    int lines = 1,
    int? maxLength,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _fields[key],
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 4,
          maxLength: maxLength,
          keyboardType:
              keyboard ??
              (lines > 1 ? TextInputType.multiline : TextInputType.text),
          textCapitalization: keyboard == null
              ? TextCapitalization.sentences
              : TextCapitalization.none,
          enabled: _canWrite && !_saving,
          validator: validator,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            counterText: '',
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
      ],
    ),
  );

  Widget _select(
    String label,
    String value,
    List<String> choices,
    ValueChanged<String?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: {...choices, value}
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(
                    v.isEmpty ? 'None' : v,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _canWrite && !_saving ? onChanged : null,
        ),
      ],
    ),
  );

  Widget _dateField(String label, DateTime? date, {bool reschedule = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: _canWrite && !_saving
                        ? () => _pickDate(reschedule: reschedule)
                        : null,
                    icon: const Icon(Icons.calendar_today_outlined, size: 20),
                    label: Text(
                      date == null ? 'Choose date' : callReportDateLabel(date),
                    ),
                  ),
                ),
                if (reschedule && date != null)
                  IconButton(
                    tooltip: 'Clear reschedule date',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: _canWrite && !_saving
                        ? () => setState(() => _rescheduleDate = null)
                        : null,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: Text(
        widget.editingReport != null
            ? 'Edit call report'
            : widget.followUpFrom != null
            ? 'Log another call'
            : 'New call report',
      ),
    ),
    body: PermissionGate(
      feature: permissionFeature,
      sessionGeneration: permissionSessionGeneration,
      writeAction: _writeAction,
      child: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _heading('Customer details'),
            _field(
              'organizationName',
              'Organization *',
              maxLength: 250,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter an organization name.'
                  : null,
            ),
            _field('customerName', 'Contact person', maxLength: 250),
            _field('address', 'Address', lines: 2, maxLength: 500),
            _field('city', 'City', maxLength: 100),
            _field(
              'mobileNumber',
              'Mobile number',
              maxLength: 10,
              keyboard: TextInputType.phone,
              validator: (v) =>
                  v != null && v.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(v)
                  ? 'Enter exactly 10 digits.'
                  : null,
            ),
            _field(
              'email',
              'Email',
              maxLength: 150,
              keyboard: TextInputType.emailAddress,
              validator: (v) =>
                  v != null &&
                      v.isNotEmpty &&
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
                  ? 'Enter a valid email address.'
                  : null,
            ),
            _heading('Call details'),
            _dateField('Call date *', _callDate),
            _select('Call type *', _callType, callReportTypes, (v) {
              if (v != null) setState(() => _callType = v);
            }),
            _select('Prospect?', _prospect, const ['No', 'Yes'], (v) {
              if (v != null) {
                setState(() {
                  _prospect = v;
                  if (v == 'No') _leadStatus = '';
                });
              }
            }),
            if (_prospect == 'Yes')
              _select('Lead status', _leadStatus, callReportLeadStatuses, (v) {
                if (v != null) setState(() => _leadStatus = v);
              }),
            _field(
              'product',
              'Product / Requirement',
              lines: 2,
              maxLength: 250,
            ),
            _dateField('Reschedule date', _rescheduleDate, reschedule: true),
            _heading('Discussion notes'),
            _field('remarks', 'Notes & feedback', lines: 4),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: _sameSession && permissions.can(permissionFeature)
        ? SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _canWrite && !_saving ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Saving…' : 'Save call report'),
              ),
            ),
          )
        : null,
  );
}

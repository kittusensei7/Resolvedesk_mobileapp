import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/call_report.dart';
import '../pages/create_call_report_page.dart';
import '../services/call_reports_service.dart';
import 'permission_guard.dart';

class CallReportDetailsSheet extends StatefulWidget {
  const CallReportDetailsSheet({super.key, required this.reportId});
  final int reportId;

  @override
  State<CallReportDetailsSheet> createState() => _CallReportDetailsSheetState();
}

class _CallReportDetailsSheetState extends State<CallReportDetailsSheet>
    with PermissionAware<CallReportDetailsSheet> {
  final _service = const CallReportsService();
  CallReport? _report;
  List<CallReport> _history = [];
  bool _loading = true, _deleting = false, _openingForm = false;
  String? _error, _historyError;
  int _requestVersion = 0;

  @override
  String get permissionFeature => 'call_reports';
  bool get _sameSession =>
      permissionSessionGeneration == permissions.generation;
  bool _can(String action) =>
      mounted &&
      _sameSession &&
      permissions.can(permissionFeature) &&
      permissions.can(permissionFeature, action);

  @override
  void initState() {
    super.initState();
    bindPermissions();
    _load();
  }

  @override
  void clearProtectedData() {
    _report = null;
    _history = [];
    _error = null;
    _historyError = null;
  }

  @override
  Future<void> reloadProtectedData() => _load();

  Future<void> _load() async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _error = null;
      _historyError = null;
      _report = null;
      _history = [];
    });
    PermissionRead? read;
    bool current() =>
        read != null &&
        version == _requestVersion &&
        currentPermissionRead(read);
    try {
      read = await beginPermissionRead();
      if (!current()) return;
      final report = await _service.get(
        widget.reportId,
        cancelToken: read!.token,
        allowed: current,
      );
      if (!current()) return;
      setState(() {
        _report = report;
        _history = [];
      });
      if (report.organizationName.trim().isEmpty) return;
      try {
        final history = await _service.history(
          report,
          cancelToken: read.token,
          allowed: current,
        );
        history.sort((a, b) {
          final order = a.sortDate.compareTo(b.sortDate);
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
        if (current()) setState(() => _history = history);
      } catch (error) {
        if (error is DioException && CancelToken.isCancel(error)) return;
        if (current()) {
          setState(
            () => _historyError = CallReportsService.errorMessage(
              error,
              'Unable to load follow-up history.',
            ),
          );
        }
      }
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) return;
      if (current()) {
        setState(
          () => _error = CallReportsService.errorMessage(
            error,
            'Unable to load this call report.',
          ),
        );
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openForm({required bool edit}) async {
    final report = _report;
    if (report == null || _deleting || _openingForm) return;
    _openingForm = true;
    try {
      if (!await requirePermission(edit ? 'edit' : 'add') ||
          !mounted ||
          !_can(edit ? 'edit' : 'add')) {
        return;
      }
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CreateCallReportPage(
            editingReport: edit ? report : null,
            followUpFrom: edit ? null : report,
          ),
        ),
      );
      if (changed == true && mounted && _sameSession) {
        Navigator.of(context).pop(true);
      }
    } finally {
      _openingForm = false;
    }
  }

  Future<void> _delete() async {
    final report = _report;
    if (report == null || _deleting || _openingForm) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      if (!await requirePermission('delete') || !mounted || !_can('delete')) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Delete call report?'),
          content: SizedBox(
            width: double.maxFinite,
            child: PermissionGate(
              feature: permissionFeature,
              sessionGeneration: permissionSessionGeneration,
              child: Text(
                'Delete the call recorded on ${callReportDateLabel(report.callDate)} for ${report.organizationName}?',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      // Confirmation may stay open while permissions or the signed-in account change.
      if (!await requirePermission('delete') || !_can('delete')) return;
      await _service.delete(report.id, allowed: () => _can('delete'));
      if (!mounted || !_sameSession) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Call report deleted.')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted && _sameSession) {
        setState(
          () => _error = CallReportsService.errorMessage(
            error,
            'Unable to confirm deletion. Refresh the list before trying again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: const Color(0xff64748b)),
        ),
        const SizedBox(height: 4),
        SelectableText(value.isEmpty ? '—' : value),
      ],
    ),
  );

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _historyTile(CallReport report) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xffe2e8f0)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${callReportDateLabel(report.callDate)} · ${report.callType}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text('Follow-up #${report.visitCount}'),
        if (report.customerName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(report.customerName),
          ),
        if (report.product.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(report.product),
          ),
        if (report.remarks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText(report.remarks),
          ),
        if (report.prospect == 'Yes')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              report.leadStatus.isEmpty
                  ? 'Prospect: Yes'
                  : 'Prospect: ${report.leadStatus}',
            ),
          ),
        if (report.rescheduleDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Rescheduled: ${callReportDateLabel(report.rescheduleDate)}',
            ),
          ),
      ],
    ),
  );

  List<Widget> _details(CallReport report) => [
    _heading('Customer details'),
    _field('Organization', report.organizationName),
    _field('Contact person', report.customerName),
    _field('Address', report.address),
    _field('City', report.city),
    _field('Mobile', report.mobileNumber),
    _field('Email', report.email),
    _heading('Call details'),
    _field('Call date', callReportDateLabel(report.callDate)),
    _field('Call type', report.callType),
    _field('Product / Requirement', report.product),
    _field('Follow-up number', '#${report.visitCount}'),
    _field('Recorded by', report.salesPersonName),
    _field('Prospect', report.prospect.isEmpty ? 'No' : report.prospect),
    if (report.prospect == 'Yes') _field('Lead status', report.leadStatus),
    _field('Reschedule date', callReportDateLabel(report.rescheduleDate)),
    _field('Discussion notes & feedback', report.remarks),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_can('add'))
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _deleting ? null : () => _openForm(edit: false),
            icon: const Icon(Icons.add_call),
            label: const Text('Log another call'),
          ),
        if (_can('edit'))
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _deleting ? null : () => _openForm(edit: true),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        if (_can('delete'))
          TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _deleting ? null : _delete,
            icon: const Icon(Icons.delete_outline),
            label: Text(_deleting ? 'Deleting…' : 'Delete'),
          ),
      ],
    ),
    const SizedBox(height: 20),
    const Divider(),
    _heading('Follow-up history'),
    if (_historyError != null) ...[
      Text(_historyError!),
      TextButton(
        onPressed: _deleting ? null : _load,
        child: const Text('Retry history'),
      ),
    ] else if (_history.isEmpty)
      const Text('No follow-up history found.')
    else
      ..._history.map(_historyTile),
  ];

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .94,
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Call report',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _deleting
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: PermissionGate(
              feature: permissionFeature,
              sessionGeneration: permissionSessionGeneration,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      children: [
                        if (_error != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _deleting ? null : _load,
                            child: const Text('Refresh details'),
                          ),
                        ],
                        if (_report != null) ..._details(_report!),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

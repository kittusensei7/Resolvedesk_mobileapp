import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/call_report.dart';
import '../services/call_reports_service.dart';
import '../widgets/call_report_details_sheet.dart';
import '../widgets/permission_guard.dart';
import 'create_call_report_page.dart';

class CallReportsPage extends StatefulWidget {
  const CallReportsPage({super.key});

  @override
  State<CallReportsPage> createState() => _CallReportsPageState();
}

class _CallReportsPageState extends State<CallReportsPage>
    with PermissionAware<CallReportsPage> {
  final _service = const CallReportsService();
  final _search = TextEditingController();
  Timer? _debounce;
  PermissionRead? _activeRead;
  int _requestVersion = 0;
  DateTime? _fromDate, _toDate;
  List<CallReportGroup> _groups = [];
  bool _loading = true, _opening = false;
  String? _error;

  @override
  String get permissionFeature => 'call_reports';
  bool get _sameSession =>
      permissionSessionGeneration == permissions.generation;

  @override
  void initState() {
    super.initState();
    bindPermissions();
    _load();
  }

  @override
  void clearProtectedData() {
    _groups = [];
    _error = null;
  }

  @override
  Future<void> reloadProtectedData() => _load();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _activeRead?.token.cancel('Search changed');
    _requestVersion++;
    setState(() {
      _loading = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    _debounce?.cancel();
    final version = ++_requestVersion;
    final search = _search.text;
    final from = _fromDate, to = _toDate;
    setState(() {
      _loading = true;
      _error = null;
    });
    PermissionRead? read;
    bool current() =>
        read != null &&
        version == _requestVersion &&
        currentPermissionRead(read);
    try {
      read = await beginPermissionRead();
      if (!current()) return;
      _activeRead = read;
      final reports = await _service.list(
        cancelToken: read!.token,
        allowed: current,
        search: search,
        fromDate: from,
        toDate: to,
      );
      if (current()) {
        setState(() => _groups = CallReportGroup.fromReports(reports));
      }
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) return;
      if (current()) {
        setState(
          () => _error = CallReportsService.errorMessage(
            error,
            'Unable to load call reports. Pull down or retry.',
          ),
        );
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickFilter(bool from) async {
    if (!await requirePermission() || !mounted) return;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          (from ? _fromDate : _toDate) ?? DateUtils.dateOnly(DateTime.now()),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: from ? 'Calls from' : 'Calls until',
    );
    if (picked == null ||
        !mounted ||
        !_sameSession ||
        !permissions.can(permissionFeature)) {
      return;
    }
    final start = from ? picked : _fromDate;
    final end = from ? _toDate : picked;
    if (start != null && end != null && start.isAfter(end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('From date must be on or before To date.'),
        ),
      );
      return;
    }
    setState(() {
      _fromDate = start;
      _toDate = end;
    });
    _activeRead?.token.cancel('Date filter changed');
    await _load();
  }

  Future<void> _create() async {
    if (_opening) return;
    _opening = true;
    try {
      if (!await requirePermission('add') ||
          !mounted ||
          !permissions.can(permissionFeature)) {
        return;
      }
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CreateCallReportPage()),
      );
      if (changed == true && mounted && _sameSession) await _load();
    } finally {
      _opening = false;
    }
  }

  Future<void> _details(CallReport report) async {
    if (_opening) return;
    _opening = true;
    try {
      if (!await requirePermission() || !mounted) return;
      final changed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        builder: (_) => CallReportDetailsSheet(reportId: report.id),
      );
      if (changed == true && mounted && _sameSession) await _load();
    } finally {
      _opening = false;
    }
  }

  Widget _filters() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _search,
          onChanged: _searchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            hintText: 'Search organization, contact, product…',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _search.clear();
                      _searchChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => _pickFilter(true),
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(
                _fromDate == null
                    ? 'From date'
                    : 'From ${callReportDateLabel(_fromDate)}',
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => _pickFilter(false),
              child: Text(
                _toDate == null
                    ? 'To date'
                    : 'To ${callReportDateLabel(_toDate)}',
              ),
            ),
            if (_fromDate != null || _toDate != null)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () {
                  setState(() {
                    _fromDate = null;
                    _toDate = null;
                  });
                  _load();
                },
                child: const Text('Clear dates'),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _resultBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.phone_in_talk_outlined, size: 32),
            const SizedBox(height: 12),
            Text(
              _search.text.isNotEmpty || _fromDate != null || _toDate != null
                  ? 'No call reports match these filters.'
                  : 'No call reports yet.',
              textAlign: TextAlign.center,
            ),
            if (permissions.can(permissionFeature, 'add')) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _create,
                child: const Text('Log a call'),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            '${_groups.length} organizations · latest call shown',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final group in _groups) _reportTile(group),
      ],
    );
  }

  Widget _reportTile(CallReportGroup group) {
    final report = group.latest;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xffe2e8f0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _details(report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      report.organizationName.isEmpty
                          ? 'Call report #${report.id}'
                          : report.organizationName,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Color(0xff64748b)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${callReportDateLabel(report.callDate)} · ${report.callType}',
              ),
              if (report.customerName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(report.customerName),
              ],
              if (report.product.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  report.product,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                '${group.count} follow-up record${group.count == 1 ? '' : 's'} in results',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (report.rescheduleDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Next follow-up: ${callReportDateLabel(report.rescheduleDate)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('Call Reports'),
      actions: [
        if (_sameSession && permissions.can(permissionFeature, 'add'))
          IconButton(
            tooltip: 'New call report',
            onPressed: _create,
            icon: const Icon(Icons.add),
          ),
      ],
    ),
    body: PermissionGate(
      feature: permissionFeature,
      sessionGeneration: permissionSessionGeneration,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 24),
          children: [_filters(), _resultBody()],
        ),
      ),
    ),
  );
}

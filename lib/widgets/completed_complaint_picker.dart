import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/permission_controller.dart';
import 'permission_guard.dart';

class CompletedComplaintPicker extends StatefulWidget {
  const CompletedComplaintPicker({
    super.key,
    required this.complaints,
    this.selectedId,
  });
  final List<Map<String, dynamic>> complaints;
  final int? selectedId;

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required List<Map<String, dynamic>> complaints,
    required int sessionGeneration,
    int? selectedId,
  }) => showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .9,
      child: PermissionGate(
        feature: 'service_calls',
        sessionGeneration: sessionGeneration,
        child: CompletedComplaintPicker(
          complaints: complaints,
          selectedId: selectedId,
        ),
      ),
    ),
  );

  @override
  State<CompletedComplaintPicker> createState() =>
      _CompletedComplaintPickerState();
}

class _CompletedComplaintPickerState extends State<CompletedComplaintPicker> {
  final _search = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSelect = context.watch<PermissionController>().can(
      'service_calls',
      'add',
    );
    if (!canSelect) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Creating service reports is no longer enabled. Close this picker to return to your draft.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final matches = widget.complaints
        .where(
          (row) => [
            row['complaint_number'],
            row['customer_name'],
            row['product'],
            row['model'],
          ].join(' ').toLowerCase().contains(_query),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Completed complaints',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close picker',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Company, complaint number or product',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (text) =>
                  setState(() => _query = text.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _query.isEmpty
                            ? 'No completed complaints are available for a new report.'
                            : 'No complaints match your search.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: matches.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 12, endIndent: 12),
                    itemBuilder: (_, index) {
                      final row = matches[index];
                      final selected = row['id'] == widget.selectedId;
                      return ListTile(
                        selected: selected,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        title: Text(
                          row['complaint_number']?.toString() ??
                              '#${row['id']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${row['customer_name'] ?? ''}\n${row['product'] ?? ''}',
                            style: const TextStyle(height: 1.5),
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xff2457d6),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, row),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

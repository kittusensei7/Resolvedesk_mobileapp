const callReportTypes = [
  'Telephone',
  'Cold Call',
  'Reference Call',
  'Inbound Call',
];
const callReportLeadStatuses = ['', 'Hot Lead', 'Warm Lead', 'Cold Lead'];

DateTime? callReportDate(Object? value) {
  final text = value?.toString().split('T').first ?? '';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
  final date = DateTime.tryParse(text);
  return date != null && callReportDateValue(date) == text ? date : null;
}

String callReportDateValue(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String callReportDateLabel(DateTime? date) => date == null
    ? '—'
    : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class CallReport {
  const CallReport({
    required this.id,
    required this.organizationName,
    required this.callType,
    required this.customerName,
    required this.address,
    required this.city,
    required this.mobileNumber,
    required this.email,
    required this.product,
    required this.remarks,
    required this.prospect,
    required this.leadStatus,
    required this.visitCount,
    required this.salesPersonName,
    this.userId,
    this.callDate,
    this.rescheduleDate,
    this.createdAt,
  });

  factory CallReport.fromJson(Map<String, dynamic> json) {
    String value(String key) => json[key]?.toString() ?? '';
    final id = int.tryParse(value('id'));
    if (id == null || id <= 0) {
      throw const FormatException('Invalid call report');
    }
    return CallReport(
      id: id,
      userId: int.tryParse(value('user_id')),
      organizationName: value('organization_name'),
      callType: value('call_type'),
      customerName: value('customer_name'),
      address: value('address'),
      city: value('city'),
      mobileNumber: value('mobile_number'),
      email: value('email'),
      product: value('product'),
      remarks: value('remarks'),
      prospect: value('prospect'),
      leadStatus: value('lead_status'),
      visitCount: int.tryParse(value('visit_count')) ?? 1,
      salesPersonName: value('sales_person_name'),
      callDate: callReportDate(json['call_date']),
      rescheduleDate: callReportDate(json['reschedule_date']),
      createdAt: DateTime.tryParse(value('created_at')),
    );
  }

  final int id, visitCount;
  final int? userId;
  final String organizationName, callType, customerName, address, city;
  final String mobileNumber, email, product, remarks, prospect, leadStatus;
  final String salesPersonName;
  final DateTime? callDate, rescheduleDate, createdAt;
  DateTime get sortDate => callDate ?? createdAt ?? DateTime(1970);
}

class CallReportGroup {
  CallReportGroup(this.latest, this.count);
  CallReport latest;
  int count;

  static List<CallReportGroup> fromReports(List<CallReport> reports) {
    final groups = <String, CallReportGroup>{};
    for (final report in reports) {
      final name = report.organizationName.trim().toLowerCase();
      final key = name.isEmpty ? 'id_${report.id}' : name;
      final group = groups[key];
      if (group == null) {
        groups[key] = CallReportGroup(report, 1);
      } else {
        group.count++;
        final order = report.sortDate.compareTo(group.latest.sortDate);
        if (order > 0 || (order == 0 && report.id > group.latest.id)) {
          group.latest = report;
        }
      }
    }
    return groups.values.toList()..sort((a, b) {
      final order = b.latest.sortDate.compareTo(a.latest.sortDate);
      return order == 0 ? b.latest.id.compareTo(a.latest.id) : order;
    });
  }
}

class CallReportInput {
  const CallReportInput({
    required this.callDate,
    required this.callType,
    required this.organizationName,
    required this.customerName,
    required this.address,
    required this.city,
    required this.mobileNumber,
    required this.email,
    required this.product,
    required this.remarks,
    required this.prospect,
    required this.leadStatus,
    this.rescheduleDate,
  });

  final DateTime callDate;
  final DateTime? rescheduleDate;
  final String callType, organizationName, customerName, address, city;
  final String mobileNumber, email, product, remarks, prospect, leadStatus;

  String? validate() {
    if (organizationName.trim().isEmpty) return 'Enter an organization name.';
    if (!callReportTypes.contains(callType)) return 'Select a call type.';
    if (mobileNumber.isNotEmpty &&
        !RegExp(r'^\d{10}$').hasMatch(mobileNumber)) {
      return 'Mobile number must be exactly 10 digits.';
    }
    if (email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    final today = callReportDate(callReportDateValue(DateTime.now()))!;
    if (rescheduleDate != null && rescheduleDate!.isBefore(today)) {
      return 'Reschedule date must be today or later.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'callDate': callReportDateValue(callDate),
    'callType': callType,
    'organizationName': organizationName.trim(),
    'customerName': customerName.trim(),
    'address': address.trim(),
    'city': city.trim(),
    'mobileNumber': mobileNumber.trim(),
    'email': email.trim(),
    'product': product.trim(),
    'remarks': remarks.trim(),
    'rescheduleDate': rescheduleDate == null
        ? null
        : callReportDateValue(rescheduleDate!),
    'prospect': prospect,
    'leadStatus': prospect == 'Yes' ? leadStatus : '',
  };
}

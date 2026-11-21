/// Presentation values only. Keep the existing report field precedence and text.
class ServiceReportContent {
  ServiceReportContent(this.report);
  final Map<String, dynamic> report;

  String value(String key) => report[key]?.toString() ?? '';
  String get engineer => value('service_engineer_name');
  String get number =>
      (report['complaint_number'] ?? report['complaintNumber'] ?? '')
          .toString();
  String get date => formatDate(report['report_date'] ?? report['created_at']);
  String get customer => value('customer_name');
  String get address => value('address');
  String get product => value('model').isEmpty
      ? value('product')
      : '${value('product')} (Model: ${value('model')})';
  String get complaint =>
      (report['complaint'] ?? report['description'] ?? '').toString();
  String get calledDate => formatDate(report['called_date']);
  String get respondedDate => formatDate(report['responded_date']);
  String get problem => value('problem_found');
  String get action => value('action_taken');
  String get spares =>
      (report['spares_details'] ?? report['spare_name'] ?? '').toString();
  String get oldSeries => value('spare_old_series');
  String get newSeries => value('spare_new_series');
  String get callType => value('call_type');
  String get amount => value('charge_amount');
  String get solvedThrough =>
      (report['solved_through'] ?? report['solvedThrough'] ?? 'On-Site')
          .toString();
  String get remarks =>
      (report['customer_remark'] ??
              report['suggestions'] ??
              report['latest_remark'] ??
              '')
          .toString();
  String get customerSignature =>
      (report['customer_signature'] ?? report['customerSignature'] ?? '')
          .toString();
  String get engineerSignature =>
      (report['engineer_signature'] ?? report['engineerSignature'] ?? '')
          .toString();
  String get coverage =>
      callType +
      (['Charge Based', 'AMC'].contains(callType) && amount.isNotEmpty
          ? ' (Amount: \u20b9 $amount)'
          : '');

  static String formatDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return '';
    final date = DateTime.tryParse(text);
    if (date == null) return text.split('T').first;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

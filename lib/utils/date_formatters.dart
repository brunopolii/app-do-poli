import 'package:intl/intl.dart';

String capitalizeFirst(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

String formatMonthYearPtBr(DateTime date) =>
    capitalizeFirst(DateFormat('MMMM yyyy', 'pt_BR').format(date));

String formatShortMonthPtBr(DateTime date) =>
    capitalizeFirst(DateFormat('MMM', 'pt_BR').format(date));

String formatFullDatePtBr(DateTime date) {
  final formatted = DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(date);
  final month = DateFormat('MMMM', 'pt_BR').format(date);
  return capitalizeFirst(formatted.replaceFirst(month, capitalizeFirst(month)));
}
